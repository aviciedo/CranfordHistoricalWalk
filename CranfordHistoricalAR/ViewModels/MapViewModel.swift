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

    static func == (lhs: StopMarkerModel, rhs: StopMarkerModel) -> Bool {
        lhs.id == rhs.id && lhs.order == rhs.order && lhs.name == rhs.name && lhs.state == rhs.state && lhs.information == rhs.information
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

        static func == (lhs: Kind, rhs: Kind) -> Bool {
            switch (lhs, rhs) {
            case (.fitAll, .fitAll): return true
            case let (.follow(a, ba), .follow(b, bb)): return a.latitude == b.latitude && a.longitude == b.longitude && ba == bb
            case let (.fitUserAndDestination(a1, a2), .fitUserAndDestination(b1, b2)):
                return a1.latitude == b1.latitude && a1.longitude == b1.longitude && a2.latitude == b2.latitude && a2.longitude == b2.longitude
            default: return false
            }
        }
    }

    var id: Int
    var kind: Kind
    var animated: Bool
}

/// Map-specific presentation state (camera mode, selection). Tour truth stays in `TourViewModel`.
@MainActor
@Observable
final class MapViewModel {
    enum CameraMode: Equatable { case overview, follow, free }

    private(set) var cameraMode: CameraMode = .overview
    private(set) var cameraRequest: MapCameraRequest?
    private(set) var selectedStopID: String?
    private(set) var viewedStopID: String?
    /// Last settled zoom level reported by the map; `nil` until the first idle callback.
    private(set) var zoom: Float?
    private var requestCounter = 0
    private var lastFollowedCoordinate: GeoCoordinate?

    /// Zoom at which the home map switches from plain dots to numbered dots.
    static let numberedDotZoom: Float = 16

    /// Marker style for an overview map of many stops (home screen).
    var overviewMarkerStyle: StopMarkerStyle {
        (zoom ?? 0) >= MapViewModel.numberedDotZoom ? .numberedDot : .dot
    }

    func markers(for tour: TourViewModel) -> [StopMarkerModel] {
        tour.stops.map { stop in
            let state: StopMarkerModel.State
            if tour.activities[stop.id].visitedAt != nil || tour.isCompleted(stop) {
                state = .visited
            } else if stop.id == tour.currentStop?.id {
                state = .current
            } else {
                state = .upcoming
            }
            return StopMarkerModel(id: stop.id, coordinate: stop.clLocationCoordinate, order: stop.order, name: stop.name,
                                   state: state, information: stop.markerInformation)
        }
    }

    func userPuck(for tour: TourViewModel) -> UserPuckModel? {
        guard let sample = tour.userLocation else { return nil }
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

    func showUserAndDestination(tour: TourViewModel) {
        viewedStopID = nil
        guard let user = tour.userLocation, let stop = tour.currentStop else { return requestOverview() }
        cameraMode = .free
        push(.fitUserAndDestination(user.clLocationCoordinate, stop.clLocationCoordinate), animated: true)
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
        if zoom != newZoom { zoom = newZoom }
    }

    private func push(_ kind: MapCameraRequest.Kind, animated: Bool) {
        requestCounter += 1
        cameraRequest = MapCameraRequest(id: requestCounter, kind: kind, animated: animated)
    }
}
