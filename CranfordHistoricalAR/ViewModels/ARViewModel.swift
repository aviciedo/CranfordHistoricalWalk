import ARKit
import AVFoundation
import Foundation
import Observation
import RealityKit
import TourCore

/// Presentation state for the AR screen. Consumes `TourViewModel` (the single source of truth for
/// location and tour progress) and drives `GeoAnchorManager`. Stage 4: camera, arrows, HUD.
@MainActor
@Observable
final class ARViewModel {
    enum CameraPermission: Equatable { case notDetermined, authorized, denied, restricted }

    enum Availability: Equatable {
        case ready
        case unsupportedDevice
        case cameraDenied
        case cameraRestricted
        case awaitingCameraPermission
    }

    private(set) var cameraPermission: CameraPermission
    private(set) var availability: Availability
    /// Presents the readable 2D sheet for the sign (tap on the AR sign or "Read").
    var isShowingSignDetails = false
    let geoAnchors: GeoAnchorManager
    let tour: TourViewModel
    /// Supplies sign artwork; `nil` means no images (Stage 6 injects the real loader).
    var imageProvider: ((HistoricalStop) -> UIImage?)?

    @ObservationIgnored private weak var arView: ARView?
    @ObservationIgnored private var observationTask: Task<Void, Never>?
    @ObservationIgnored private var isSessionRunning = false

    init(tour: TourViewModel, provider: any GeoSpatialProvider) {
        self.tour = tour
        self.geoAnchors = GeoAnchorManager(provider: provider)
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        cameraPermission = ARViewModel.permission(from: status)
        availability = ARViewModel.availability(permission: cameraPermission)
    }

    // MARK: Derived HUD values

    var localizationState: ARLocalizationState { geoAnchors.localizationState }
    var statusMessage: String? { geoAnchors.localizationState.userMessage }
    var destinationName: String? { tour.currentStop?.name }
    var distanceText: String { tour.remainingDistanceText }
    var timeText: String { tour.remainingTimeText }

    /// Relative bearing (−180…180) from the device heading to the next waypoint, for the 2D indicator.
    var relativeBearingToWaypoint: Double? {
        guard let heading = tour.displayHeading, let bearing = tour.bearingToNextWaypoint else { return nil }
        return GeoMath.relativeBearing(heading: heading, bearing: bearing)
    }

    /// True when the 3D arrows cannot be trusted and the 2D indicator should lead (spec §7 fallback).
    var shouldShowFallbackIndicator: Bool {
        !geoAnchors.localizationState.isUsable || !tour.hasReliableHeading
    }

    // MARK: Permissions

    func requestCameraAccessIfNeeded() async {
        guard cameraPermission == .notDetermined else { return }
        availability = .awaitingCameraPermission
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        cameraPermission = granted ? .authorized : .denied
        availability = ARViewModel.availability(permission: cameraPermission)
        if granted, let arView { runSession(on: arView) }
    }

    private static func permission(from status: AVAuthorizationStatus) -> CameraPermission {
        switch status {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }

    private static func availability(permission: CameraPermission) -> Availability {
        guard ARWorldTrackingConfiguration.isSupported else { return .unsupportedDevice }
        switch permission {
        case .authorized: return .ready
        case .denied: return .cameraDenied
        case .restricted: return .cameraRestricted
        case .notDetermined: return .awaitingCameraPermission
        }
    }

    // MARK: AR view lifecycle

    func arViewDidLoad(_ arView: ARView) {
        self.arView = arView
        if cameraPermission == .authorized { runSession(on: arView) }
        startObservingTour()
    }

    func arViewWillUnload() {
        observationTask?.cancel()
        observationTask = nil
        isSessionRunning = false
        geoAnchors.sessionDidStop()
        geoAnchors.anchors.detach()
        arView = nil
    }

    private func runSession(on arView: ARView) {
        guard availability == .ready, !isSessionRunning else { return }
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = geoAnchors.preferredWorldAlignment
        configuration.planeDetection = []
        configuration.environmentTexturing = .none
        configuration.isLightEstimationEnabled = true
        configuration.isAutoFocusEnabled = true
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isSessionRunning = true
        geoAnchors.sessionDidStart(arView.session, arView: arView)
        pushTourStateToAnchors()
    }

    /// Mirrors the tour's location and destination into the anchor manager whenever they change.
    private func startObservingTour() {
        observationTask?.cancel()
        observationTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    withObservationTracking {
                        self.pushTourStateToAnchors()
                    } onChange: {
                        continuation.resume()
                    }
                }
                // Coalesce bursts of changes into at most ~20 updates/s.
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func pushTourStateToAnchors() {
        // Reads tracked properties: userLocation, heading, currentStop, routeProgress, presentedSignStopID.
        geoAnchors.locationDidUpdate(tour.userLocation, heading: tour.heading)
        if let signStop = tour.presentedSignStop {
            let scale = arView?.traitCollection.displayScale ?? 2
            geoAnchors.presentSign(for: signStop, image: imageProvider?(signStop), displayScale: scale)
        } else {
            geoAnchors.dismissSign()
        }
        guard let stop = tour.currentStop, let user = tour.userLocation else {
            geoAnchors.setNavigationTarget(nil)
            return
        }
        let waypoint = tour.nextWaypointCoordinate ?? stop.coordinate
        geoAnchors.setNavigationTarget(GeoAnchorManager.NavigationTarget(
            waypoint: waypoint,
            destination: stop.coordinate,
            bearingToWaypoint: GeoMath.bearing(from: user.coordinate, to: waypoint),
            distanceToDestination: GeoMath.distance(from: user.coordinate, to: stop.coordinate),
            arrivalRadius: stop.arrivalRadius
        ))
    }

    // MARK: Session delegate forwarding

    func frameDidUpdate(cameraTransform: simd_float4x4, trackingState: ARCamera.TrackingState, timestamp: TimeInterval) {
        geoAnchors.frameDidUpdate(cameraTransform: cameraTransform, trackingState: trackingState, timestamp: timestamp)
    }

    func trackingStateDidChange(_ state: ARCamera.TrackingState) {
        geoAnchors.trackingStateDidChange(state)
    }

    func sessionWasInterrupted() { geoAnchors.sessionWasInterrupted() }

    func sessionInterruptionEnded() {
        geoAnchors.sessionInterruptionEnded()
        // Relocalization after an interruption is unreliable outdoors; restart cleanly.
        if let arView { isSessionRunning = false; runSession(on: arView) }
    }

    func sessionDidFail(message: String, code: ARError.Code?) {
        isSessionRunning = false
        if code == .cameraUnauthorized {
            cameraPermission = .denied
            availability = .cameraDenied
        }
        geoAnchors.sessionDidFail(message)
    }

    func retrySession() {
        guard let arView else { return }
        isSessionRunning = false
        geoAnchors.sessionDidStop()
        runSession(on: arView)
    }

    // MARK: Sign interactions (spec §8, §9)

    func didTap(entity: Entity?, at point: CGPoint) {
        guard let entity, geoAnchors.isSignEntity(entity), tour.isSignPresented else { return }
        isShowingSignDetails = true
    }

    func closeSign() {
        isShowingSignDetails = false
        tour.closeSign()
    }

    func showSign() {
        tour.openSignManually()
    }

    var canShowSignManually: Bool {
        guard let state = tour.proximityState else { return false }
        return state == .signDismissed || state == .nearby || (state == .approaching && tour.isWithinArrivalRadius)
    }
}
