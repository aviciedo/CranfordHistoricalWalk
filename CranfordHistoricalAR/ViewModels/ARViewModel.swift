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
    let imageLoader: any ImageLoader
    let narrationPlayer: NarrationPlayer
    private(set) var activationMessage: String?
    private(set) var isShowingWalkingOrientation = true
    @ObservationIgnored private var walkingOrientation = ARWalkingGuidance.OrientationState()

    @ObservationIgnored private weak var arView: ARView?
    @ObservationIgnored private var observationTask: Task<Void, Never>?
    @ObservationIgnored private var imageTask: Task<Void, Never>?
    @ObservationIgnored private var imageRequestedForStopID: String?
    @ObservationIgnored private var isSessionRunning = false
    @ObservationIgnored private var plaqueSearchStartedAt: Date?
    @ObservationIgnored private var observedStopID: String?
    /// True when world tracking accepted a non-empty `PlaqueAnchors` group. Simulator / missing
    /// assets stay false and the geo sign is used.
    private(set) var imageTrackingAvailable = false
    private(set) var placementMode: SignPlacementMode = .hidden
    /// Restrained HUD line while looking for the mill plate.
    private(set) var plaqueHint: String?

    init(tour: TourViewModel, provider: any GeoSpatialProvider, imageLoader: any ImageLoader, narrationPlayer: NarrationPlayer) {
        self.tour = tour
        self.geoAnchors = GeoAnchorManager(provider: provider)
        self.imageLoader = imageLoader
        self.narrationPlayer = narrationPlayer
        // Compute into locals first: @Observable turns stored properties into accessors on self,
        // which may not be read before all stored properties are initialized.
        let permission = ARViewModel.permission(from: AVCaptureDevice.authorizationStatus(for: .video))
        cameraPermission = permission
        availability = ARViewModel.availability(permission: permission)
    }

    // MARK: Derived HUD values

    var localizationState: ARLocalizationState { geoAnchors.localizationState }
    var statusMessage: String? {
        if placementMode == .plaqueAnchored, geoAnchors.isTrackingReady { return nil }
        if localizationState.isUsable, geoAnchors.provider.backend == .coreLocation {
            return nil // The compact walking footer carries the accuracy notice.
        }
        return geoAnchors.userFacingNotice
    }
    var destinationName: String? { tour.currentStop?.name }
    var distanceText: String { tour.hasPlaqueConfirmedArrival ? "At plaque" : tour.remainingDistanceText }
    var timeText: String { tour.hasPlaqueConfirmedArrival ? "Arrived" : tour.remainingTimeText }

    /// Uses the actual camera facing, including when the phone is turned away from the walk.
    /// GPS course describes movement, so it must not be used as the camera's heading.
    var relativeBearingToWaypoint: Double? {
        geoAnchors.navigationBearing
    }

    var isGuidanceApproximate: Bool { geoAnchors.provider.backend == .coreLocation || tour.isRouteAnEstimate }

    var walkingCue: ARWalkingGuidance.RouteCue? {
        guard let route = tour.currentRoute, let progress = tour.routeProgress else { return nil }
        return ARWalkingGuidance.routeCue(route: route, progress: progress)
    }

    var orientationStreet: String {
        guard let route = tour.currentRoute, let progress = tour.routeProgress else { return guidanceDetail }
        if let street = ARWalkingGuidance.currentStreetLabel(route: route, progress: progress) { return street }
        if let street = walkingCue?.streetName { return "Toward \(street)" }
        return guidanceDetail
    }

    var isMarkerAvailable: Bool {
        tour.isSignPresented && (placementMode == .plaqueAnchored || placementMode == .geoFallback)
    }

    var guidanceDetail: String {
        if isMarkerAvailable { return "Look for the stop marker · Tap to discover" }
        if tour.currentRoute == nil { return "Finding your walking route" }
        if tour.isRouteAnEstimate { return "Approximate direction · Use the map for streets" }
        return tour.currentInstruction ?? "Follow the walking route"
    }

    var visitConfirmation: String {
        #if DEVELOPER_MENU
        if !tour.isVisitRecordingEnabled { return "Test visit · Not saved" }
        #endif
        return tour.activeVisitEvidence == .simulation ? "Practice visit · Not saved" : "Visit recorded on this iPhone"
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
        geoAnchors.onNeedsFallback = { [weak self] reason in
            self?.fallbackToCoreLocation(reason: reason)
        }
        if cameraPermission == .authorized { runSession(on: arView) }
        startObservingTour()
    }

    func arViewWillUnload() {
        observationTask?.cancel()
        observationTask = nil
        imageTask?.cancel()
        imageTask = nil
        isSessionRunning = false
        plaqueSearchStartedAt = nil
        imageTrackingAvailable = false
        placementMode = .hidden
        plaqueHint = nil
        geoAnchors.sessionDidStop()
        geoAnchors.anchors.detach()
        arView = nil
    }

    private func runSession(on arView: ARView) {
        guard availability == .ready, !isSessionRunning else { return }
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = geoAnchors.preferredWorldAlignment
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .none
        configuration.isLightEstimationEnabled = true
        configuration.isAutoFocusEnabled = true
        imageTrackingAvailable = PlaqueAnchorController.applyDetectionImages(to: configuration)
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isSessionRunning = true
        isShowingWalkingOrientation = true
        walkingOrientation = ARWalkingGuidance.OrientationState()
        geoAnchors.sessionDidStart(arView.session, arView: arView)
        pushTourStateToAnchors()
    }

    /// Mirrors the tour's location and destination into the anchor manager whenever they change.
    private func startObservingTour() {
        observationTask?.cancel()
        observationTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                // AsyncStream ends when the task is cancelled, even if the tour never
                // changes again. Do not retain the view model across that suspension.
                let changes = AsyncStream<Void> { [weak self] continuation in
                    guard let self else {
                        continuation.finish()
                        return
                    }
                    withObservationTracking {
                        self.pushTourStateToAnchors()
                    } onChange: {
                        continuation.yield(())
                        continuation.finish()
                    }
                }
                for await _ in changes { break }
                guard !Task.isCancelled, self != nil else { return }
                // Coalesce bursts of changes into at most ~20 updates/s.
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func pushTourStateToAnchors() {
        // Reads tracked properties: userLocation, heading, currentStop, routeProgress, presentedSignStopID.
        if observedStopID != tour.currentStop?.id {
            observedStopID = tour.currentStop?.id
            activationMessage = nil
            isShowingSignDetails = false
            plaqueSearchStartedAt = nil
            isShowingWalkingOrientation = true
            walkingOrientation = ARWalkingGuidance.OrientationState()
        }
        geoAnchors.hasActivatedStop = tour.isCurrentStopVisited
        geoAnchors.locationDidUpdate(tour.userLocation, heading: tour.heading)
        applySignPlacement()
        if tour.presentedSignStop == nil {
            imageRequestedForStopID = nil
        } else if let signStop = tour.presentedSignStop, imageLoader.cachedImage(for: signStop) == nil, signStop.hasAnyImage {
            loadSignImage(for: signStop)
        }
        guard !tour.hasPlaqueConfirmedArrival, !tour.isRouteAnEstimate,
              tour.currentRoute != nil, let stop = tour.currentStop, let user = tour.userLocation else {
            geoAnchors.setNavigationTarget(nil)
            return
        }
        imageLoader.prefetch([stop])
        let waypoint = tour.nextWaypointCoordinate ?? stop.coordinate
        geoAnchors.setNavigationTarget(GeoAnchorManager.NavigationTarget(
            destination: stop.coordinate,
            bearingToWaypoint: GeoMath.bearing(from: user.coordinate, to: waypoint),
            turnCue: isShowingWalkingOrientation ? nil : walkingCue
        ))
    }

    private var displayScale: CGFloat { arView?.traitCollection.displayScale ?? 2 }

    /// The sign goes up immediately with text; artwork is swapped in when it arrives (spec §10, §21).
    private func loadSignImage(for stop: HistoricalStop) {
        guard imageRequestedForStopID != stop.id else { return }
        imageRequestedForStopID = stop.id
        imageTask?.cancel()
        imageTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard await self.imageLoader.image(for: stop) != nil else { return }
            guard !Task.isCancelled, self.tour.presentedSignStopID == stop.id else { return }
            self.applySignPlacement()
        }
    }

    // MARK: Plaque image tracking (placement only)

    private func applySignPlacement() {
        if tour.currentStop?.hasPlaqueReference == true, tour.isSignPresented {
            // Start the search when arrival requests a marker, including after a long
            // stationary approach. A hidden/closed marker gets a fresh search next time.
            if plaqueSearchStartedAt == nil { plaqueSearchStartedAt = Date() }
        } else {
            plaqueSearchStartedAt = nil
        }

        let input = SignPlacementInput(
            proximity: tour.proximityState,
            isSignRequested: tour.isSignPresented,
            hasManuallyDismissed: tour.proximityMachine?.hasManuallyDismissed ?? false,
            stopHasPlaqueReference: tour.currentStop?.hasPlaqueReference ?? tour.presentedSignStop?.hasPlaqueReference ?? false,
            imageTrackingAvailable: imageTrackingAvailable,
            plaqueDetected: geoAnchors.plaqueAnchors.trackedImageName != nil
                && geoAnchors.plaqueAnchors.trackedImageName == expectedPlaqueImageName,
            searchElapsed: plaqueSearchStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        )
        let mode = SignPlacementPolicy.mode(input)
        placementMode = mode
        geoAnchors.placementMode = mode
        plaqueHint = SignPlacementPolicy.plaqueHint(
            mode: mode,
            stopHasPlaqueReference: input.stopHasPlaqueReference,
            proximity: input.proximity
        )
        if mode == .plaqueAnchored, !tour.isCurrentStopVisited {
            plaqueHint = "Plaque found — tap the marker above it"
        }

        guard let signStop = tour.presentedSignStop else {
            geoAnchors.dismissSign()
            return
        }
        let image = tour.isCurrentStopVisited ? imageLoader.cachedImage(for: signStop) : nil
        switch mode {
        case .hidden, .searchingForPlaque:
            geoAnchors.dismissSign()
        case .plaqueAnchored:
            geoAnchors.presentSign(for: signStop, image: image, displayScale: displayScale,
                                   appearance: tour.isCurrentStopVisited ? .plaqueCard : .visitMarker,
                                   anchorToPlaque: true)
        case .geoFallback:
            geoAnchors.presentSign(for: signStop, image: image, displayScale: displayScale,
                                   appearance: tour.isCurrentStopVisited ? .geoPost : .visitMarker)
        }
    }

    private var expectedPlaqueImageName: String? {
        (tour.presentedSignStop ?? tour.currentStop)?.plaque?.referenceImageName
    }

    func imageAnchorsDidAdd(_ anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let imageAnchor = anchor as? ARImageAnchor else { continue }
            handleRecognizedPlaque(imageAnchor)
        }
    }

    func imageAnchorsDidUpdate(_ anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let imageAnchor = anchor as? ARImageAnchor else { continue }
            if imageAnchor.isTracked {
                handleRecognizedPlaque(imageAnchor)
            } else {
                releasePlaqueIfMatching(imageAnchor)
            }
        }
    }

    func imageAnchorsDidRemove(_ anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let imageAnchor = anchor as? ARImageAnchor else { continue }
            releasePlaqueIfMatching(imageAnchor)
        }
    }

    private func releasePlaqueIfMatching(_ imageAnchor: ARImageAnchor) {
        guard geoAnchors.plaqueAnchors.trackedAnchor?.identifier == imageAnchor.identifier else { return }
        geoAnchors.plaqueAnchors.unbind(sign: geoAnchors.anchors.sign, returningTo: geoAnchors.anchors.worldRoot)
        applySignPlacement()
    }

    /// Recognizing the physical plate can open the sign through the existing state machine
    /// (`userOpenedSign`) so GPS/geocode error does not block an on-site visitor. Dismissed
    /// this visit still wins.
    private func handleRecognizedPlaque(_ imageAnchor: ARImageAnchor) {
        guard imageAnchor.isTracked, let expected = expectedPlaqueImageName,
              geoAnchors.plaqueAnchors.matches(imageAnchor, expectedName: expected) else { return }
        if tour.proximityMachine?.hasManuallyDismissed == true { return }
        if tour.proximityState == .completed { return }
        guard let stop = tour.currentStop else { return }
        tour.confirmPlaqueArrival(for: stop.id)
        geoAnchors.plaqueAnchors.bind(imageAnchor: imageAnchor, sign: geoAnchors.anchors.sign, offset: .abovePlaque)
        applySignPlacement()
    }

    // MARK: Session delegate forwarding

    func frameDidUpdate(_ frame: ARFrame) {
        geoAnchors.frameDidUpdate(frame)
        updateWalkingOrientation(timestamp: frame.timestamp)
        // Observation only fires when tour properties change; the 8 s plaque hunt
        // must advance on frames so a still visitor still gets the geo fallback.
        if placementMode == .searchingForPlaque || (tour.isSignPresented && tour.currentStop?.hasPlaqueReference == true && placementMode == .hidden) {
            applySignPlacement()
        }
    }

    private func updateWalkingOrientation(timestamp: TimeInterval) {
        let visible = walkingOrientation.update(relativeBearing: relativeBearingToWaypoint, timestamp: timestamp,
                                                isAtStop: tour.isCurrentStopVisited || isMarkerAvailable || tour.phase == .complete)
        if isShowingWalkingOrientation != visible { isShowingWalkingOrientation = visible }
    }

    /// Geospatial unavailable: same AR session owner, same LocationService, Core Location provider.
    func fallbackToCoreLocation(reason: GeoSpatialFallbackReason) {
        guard geoAnchors.provider.backend == .arCoreGeospatial else { return }
        let next = CoreLocationGeoSpatialProvider(fallbackReason: reason)
        geoAnchors.replaceProvider(with: next, session: arView?.session)
        if let arView {
            isSessionRunning = false
            runSession(on: arView)
        }
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
        guard let entity else { return }
        if geoAnchors.isCloseControl(entity) {
            closeSign()
            return
        }
        guard geoAnchors.isSignEntity(entity), tour.isSignPresented else { return }
        if tour.isCurrentStopVisited {
            isShowingSignDetails = true
        } else {
            activateMarker()
        }
    }

    /// The on-screen accessibility button and a tap on the 3D marker use the same checks.
    func activateMarker() {
        guard let stop = tour.currentStop else { return }
        guard isMarkerAvailable, geoAnchors.anchors.sign.isPresented else {
            activationMessage = StopActivationIssue.markerNotReady.message
            return
        }
        let plaqueIsTracked = geoAnchors.plaqueAnchors.trackedAnchor?.isTracked == true
            && geoAnchors.plaqueAnchors.trackedImageName == stop.plaque?.referenceImageName
        let decision = tour.activateCurrentStop(
            stopID: stop.id,
            trackingReady: isSessionRunning && geoAnchors.isTrackingReady,
            plaqueIsTracked: plaqueIsTracked
        )
        switch decision {
        case .allow:
            activationMessage = nil
            geoAnchors.hasActivatedStop = true
            applySignPlacement()
            if narrationPlayer.prepare(stop) { narrationPlayer.play() }
        case .deny(let issue):
            activationMessage = issue.message
        case .alreadyActivated:
            break // Repeated taps must not restart narration or create duplicate visits.
        }
    }

    /// Closing only hides the card. Continuing to another destination is a separate action.
    func closeSign() {
        isShowingSignDetails = false
        tour.closeSign()
    }

    func continueToNextStop() {
        guard tour.isCurrentStopVisited else { return }
        isShowingSignDetails = false
        activationMessage = nil
        tour.completeCurrentStopAndAdvance()
        pushTourStateToAnchors()
    }

    func showSign() {
        activationMessage = nil
        tour.openSignManually()
    }

    var canShowSignManually: Bool {
        guard let state = tour.proximityState else { return false }
        return tour.isCurrentStopVisited || state == .signDismissed || state == .nearby
            || (state == .approaching && tour.isWithinArrivalRadius)
    }
}
