import CoreLocation
import Foundation
import Observation
import TourCore

/// Marker appearance derived from tour state. Pure data so the map view only renders.
struct StopMarkerModel: Identifiable, Equatable {
    enum State: Equatable { case upcoming, current, visited }

    var id: String
    var coordinate: CLLocationCoordinate2D
    var order: Int
    var name: String
    var state: State
    var information: String? = nil
    var isIllustrated: Bool = true
    /// Highlight is a walking state, independent of selection or a historical visit.
    var isWalkingDestination: Bool = false

    static func == (lhs: StopMarkerModel, rhs: StopMarkerModel) -> Bool {
        lhs.id == rhs.id && lhs.order == rhs.order && lhs.name == rhs.name && lhs.state == rhs.state && lhs.information == rhs.information && lhs.isIllustrated == rhs.isIllustrated && lhs.isWalkingDestination == rhs.isWalkingDestination
            && lhs.coordinate.latitude == rhs.coordinate.latitude && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

/// How stop markers are drawn. The tour map uses labeled pins; the home map uses plain dots,
/// switching to numbered dots once the user zooms in.
enum StopMarkerStyle: Equatable {
    case labeledPin
    case dot
    case numberedDot

    /// Dot styles handle taps through SwiftUI selection instead of the SDK's info window.
    var usesCustomCallout: Bool { self != .labeledPin }
}

struct UserPuckModel: Equatable {
    var coordinate: CLLocationCoordinate2D
    var accuracyMeters: Double
    /// Degrees; `nil` hides the heading cone.
    var heading: Double?
    var isSimulated: Bool

    static func == (lhs: UserPuckModel, rhs: UserPuckModel) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.accuracyMeters == rhs.accuracyMeters && lhs.heading == rhs.heading && lhs.isSimulated == rhs.isSimulated
    }
}

/// A one-shot camera instruction. The map applies it when `id` changes.
struct MapCameraRequest: Equatable {
    enum Kind: Equatable {
        case fitAll
        case follow(CLLocationCoordinate2D, bearing: Double?)
        case fitUserAndDestination(CLLocationCoordinate2D, CLLocationCoordinate2D)
        case fitWalkingLeg([GeoCoordinate])
        case zoomTo(Float)

        static func == (lhs: Kind, rhs: Kind) -> Bool {
            switch (lhs, rhs) {
            case (.fitAll, .fitAll): return true
            case let (.follow(a, ba), .follow(b, bb)): return a.latitude == b.latitude && a.longitude == b.longitude && ba == bb
            case let (.fitUserAndDestination(a1, a2), .fitUserAndDestination(b1, b2)):
                return a1.latitude == b1.latitude && a1.longitude == b1.longitude && a2.latitude == b2.latitude && a2.longitude == b2.longitude
            case let (.fitWalkingLeg(a), .fitWalkingLeg(b)): return a == b
            case let (.zoomTo(a), .zoomTo(b)): return a == b
            default: return false
            }
        }
    }

    var id: Int
    var kind: Kind
    var animated: Bool
}

/// Shared Web Mercator zoom steps, including conversion for the Apple geographic fallback.
enum MapZoomPolicy {
    static let minimum: Float = 3
    static let maximum: Float = 20
    static let initial: Float = 15.2

    static func clamped(_ value: Float) -> Float {
        value.isFinite ? min(maximum, max(minimum, value)) : initial
    }

    static func level(metersPerPoint: Double, latitude: Double) -> Float {
        let latitudeScale = cos(latitude * Double.pi / 180)
        guard metersPerPoint.isFinite, metersPerPoint > 0, latitudeScale.isFinite,
              latitudeScale > 0 else { return initial }
        let value = Float(log2(156543.03392 * latitudeScale / metersPerPoint))
        return value.isFinite ? value : initial
    }
}

/// Map-specific presentation state (camera mode, selection). Tour truth stays in `TourViewModel`.
@MainActor
@Observable
final class MapViewModel {
    enum CameraMode: Equatable { case overview, navigation, follow, free }

    private(set) var cameraMode: CameraMode = .overview
    private(set) var cameraRequest: MapCameraRequest?
    private(set) var selectedStopID: String?
    private(set) var viewedStopID: String?
    /// Latest requested or settled zoom; nil before the first camera report or zoom tap.
    private(set) var zoom: Float?
    private var requestCounter = 0
    private var lastFollowedCoordinate: GeoCoordinate?
    private var lastFramedCoordinate: GeoCoordinate?
    private var framedDestinationID: String?
    private var departureStopID: String?
    private var framedWalkSessionID: UUID?

    /// Zoom at which the home map switches from plain dots to numbered dots.
    static let numberedDotZoom: Float = 16

    var canZoomIn: Bool { (zoom ?? MapZoomPolicy.initial) < MapZoomPolicy.maximum }
    var canZoomOut: Bool { (zoom ?? MapZoomPolicy.initial) > MapZoomPolicy.minimum }

    /// Store the requested level immediately so rapid taps accumulate before camera idle.
    /// No stop selection, walking progress or GPS permissions are changed.
    func requestZoom(by step: Float) {
        guard step.isFinite, step != 0 else { return }
        let target = MapZoomPolicy.clamped((zoom ?? MapZoomPolicy.initial) + step)
        guard target != zoom else { return }
        zoom = target
        userDidMoveCamera()
        push(.zoomTo(target), animated: true)
    }

    /// Marker style for an overview map of many stops (home screen).
    var overviewMarkerStyle: StopMarkerStyle {
        (zoom ?? 0) >= MapViewModel.numberedDotZoom ? .numberedDot : .dot
    }

    func markers(for tour: TourViewModel, emphasizesDestinationOnly: Bool = false) -> [StopMarkerModel] {
        let illustratedID = tour.phase == .complete ? nil : (tour.currentStop?.id ?? tour.stops.first?.id)
        return tour.stops.map { stop in
            let state: StopMarkerModel.State
            if tour.activities[stop.id].visitedAt != nil || tour.isCompleted(stop) {
                state = .visited
            } else if stop.id == tour.currentStop?.id {
                state = .current
            } else {
                state = .upcoming
            }
            return StopMarkerModel(id: stop.id, coordinate: stop.clLocationCoordinate, order: stop.order, name: stop.name,
                                   state: state, information: stop.markerInformation,
                                   isIllustrated: !emphasizesDestinationOnly || stop.id == illustratedID,
                                   isWalkingDestination: tour.isWalkingActive && stop.id == tour.currentStop?.id)
        }
    }

    func userPuck(for tour: TourViewModel) -> UserPuckModel? {
        guard let sample = tour.userLocation, sample.coordinate.isValid,
              sample.horizontalAccuracy.isFinite, sample.horizontalAccuracy >= 0 else { return nil }
        return UserPuckModel(
            coordinate: sample.clLocationCoordinate,
            accuracyMeters: max(sample.horizontalAccuracy, 0),
            heading: tour.displayHeading,
            isSimulated: sample.isSimulated
        )
    }

    // MARK: Camera

    /// Centers a browsed stop without changing the tour's current destination.
    func show(stop: HistoricalStop) {
        viewedStopID = stop.id
        cameraMode = .free
        push(.follow(stop.clLocationCoordinate, bearing: nil), animated: true)
    }

    func requestOverview(animated: Bool = true) {
        viewedStopID = nil
        cameraMode = .overview
        push(.fitAll, animated: animated)
    }

    func requestFollow(tour: TourViewModel) {
        viewedStopID = nil
        cameraMode = .follow
        lastFollowedCoordinate = nil
        followIfNeeded(tour: tour, force: true)
    }

    /// Called from the view whenever the user location changes; moves the camera only in follow
    /// mode and only after a meaningful move, so the map stays calm.
    func followIfNeeded(tour: TourViewModel, force: Bool = false) {
        guard cameraMode == .follow, let location = tour.userLocation else { return }
        if !force, let last = lastFollowedCoordinate, GeoMath.distance(from: last, to: location.coordinate) < 4 { return }
        lastFollowedCoordinate = location.coordinate
        push(.follow(location.clLocationCoordinate, bearing: nil), animated: true)
    }

    /// Resume automatic framing of the active leg, including the place just left.
    /// A location fix is not required to focus the destination while GPS warms up.
    func showUserAndDestination(tour: TourViewModel) {
        viewedStopID = nil
        guard tour.phase != .complete, let destination = tour.currentStop ?? tour.stops.first else {
            framedDestinationID = nil
            departureStopID = nil
            return requestOverview()
        }
        if framedWalkSessionID != tour.walkSessionID {
            framedDestinationID = nil
            departureStopID = nil
            framedWalkSessionID = tour.walkSessionID
        }
        if destination.id != framedDestinationID {
            departureStopID = tour.phase == .inProgress ? (framedDestinationID ?? tour.previousStop?.id) : nil
            framedDestinationID = destination.id
        }
        cameraMode = .navigation
        lastFramedCoordinate = tour.userLocation?.coordinate
        var coordinates = [destination.coordinate]
        if let departure = departureStopID.flatMap(tour.stop(withID:)) {
            coordinates.append(departure.coordinate)
        }
        if let puck = userPuck(for: tour) { coordinates.append(GeoCoordinate(latitude: puck.coordinate.latitude, longitude: puck.coordinate.longitude)) }
        coordinates += walkingRouteCoordinates(for: tour)
        push(.fitWalkingLeg(coordinates), animated: true)
    }

    /// Bounds fits are tied to the viewport. Walking instructions and distance text can
    /// shrink the map without changing GPS or route, so issue a new fit for the new bounds.
    /// A user-controlled camera must remain untouched.
    func mapViewportDidChange() {
        let camera: MapViewportRefit.Camera
        switch cameraMode {
        case .overview: camera = .overview
        case .navigation: camera = .navigation
        case .follow: camera = .follow
        case .free: camera = .free
        }
        let fit: MapViewportRefit.Fit? = cameraRequest.map { request in
            switch request.kind {
            case .fitAll, .fitUserAndDestination, .fitWalkingLeg: return .bounds
            case .follow, .zoomTo: return .positioned
            }
        }
        guard MapViewportRefit.shouldReissue(camera: camera, fit: fit, hasRequest: cameraRequest != nil),
              let request = cameraRequest else { return }
        push(request.kind, animated: false)
    }

    /// Keep the dot independent from the camera. Reframe only after meaningful walking;
    /// manual pan/zoom suspends camera tracking until the route/recenter control is tapped.
    func updateWalkingFrame(tour: TourViewModel, routeChanged: Bool = false) {
        if cameraMode == .follow { followIfNeeded(tour: tour); return }
        guard cameraMode == .navigation else { return }
        if !routeChanged, let last = lastFramedCoordinate, let location = tour.userLocation,
           GeoMath.distance(from: last, to: location.coordinate) < 15 { return }
        showUserAndDestination(tour: tour)
    }

    /// Never render a straight-line estimate or an old destination's route as a walking path.
    func walkingRouteCoordinates(for tour: TourViewModel) -> [GeoCoordinate] {
        guard tour.isWalkingActive, let route = tour.currentRoute,
              route.source != .straightLineEstimate, let destination = tour.currentStop,
              GeoMath.distance(from: route.destination, to: destination.coordinate) < 1,
              route.routeCoordinates.count >= 2,
              route.routeCoordinates.allSatisfy({ $0.isValid }) else { return [] }
        guard let progress = tour.routeProgress,
              progress.snappedCoordinate.isValid, progress.distanceFromRoute.isFinite,
              (0...35).contains(progress.distanceFromRoute),
              route.routeCoordinates.indices.contains(progress.segmentIndex),
              route.routeCoordinates.indices.contains(progress.segmentIndex + 1) else {
            return route.routeCoordinates
        }
        // Trim only provider geometry behind the route projection. Keep the blue dot at
        // actual GPS; never draw a made-up connector across a street or building.
        var remaining = [progress.snappedCoordinate]
        for coordinate in route.routeCoordinates.dropFirst(progress.segmentIndex + 1) {
            if let last = remaining.last, GeoMath.distance(from: last, to: coordinate) < 0.1 { continue }
            remaining.append(coordinate)
        }
        return remaining.count >= 2 ? remaining : []
    }

    func walkedTrailCoordinates(for tour: TourViewModel) -> [[GeoCoordinate]] {
        tour.walkedTrailSegments.filter { $0.count >= 2 && $0.allSatisfy(\.isValid) }
    }

    /// The user dragged/zoomed; stop fighting them.
    func userDidMoveCamera() {
        if cameraMode != .free { cameraMode = .free }
    }

    func select(stopID: String?) {
        selectedStopID = stopID
        if let stopID { viewedStopID = stopID }
    }

    func clearViewedStop() { viewedStopID = nil }

    /// Toggle semantics for dot markers: tapping the selected stop again deselects it.
    func toggleSelection(stopID: String) {
        selectedStopID = selectedStopID == stopID ? nil : stopID
    }

    func cameraDidSettle(zoom newZoom: Float) {
        guard newZoom.isFinite else { return }
        if zoom != newZoom { zoom = newZoom }
    }

    private func push(_ kind: MapCameraRequest.Kind, animated: Bool) {
        requestCounter += 1
        cameraRequest = MapCameraRequest(id: requestCounter, kind: kind, animated: animated)
    }
}
