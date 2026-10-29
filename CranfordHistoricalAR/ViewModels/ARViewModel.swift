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
    @ObservationIgnored private var observedStopID: String?
    let isPlaqueScanner: Bool
    private(set) var scannerAttemptStartedAt = Date()
    /// True when world tracking accepted a non-empty `PlaqueAnchors` group. Missing assets
    /// disable the sketchbook discovery; they never fall back to a GPS-only verification.
    private(set) var imageTrackingAvailable = false
    private(set) var placementMode: SignPlacementMode = .hidden
    /// Restrained HUD line while looking for the mill plate.
    private(set) var plaqueHint: String?

    init(tour: TourViewModel, provider: any GeoSpatialProvider, imageLoader: any ImageLoader, narrationPlayer: NarrationPlayer, isPlaqueScanner: Bool = false) {
        self.tour = tour
        self.isPlaqueScanner = isPlaqueScanner
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
        if !isPlaqueScanner, let notice = geoAnchors.navigationNotice { return notice }
        if placementMode == .plaqueAnchored, geoAnchors.isTrackingReady { return nil }
        if localizationState.isUsable, geoAnchors.provider.backend == .coreLocation {
            return nil // The compact walking footer carries the accuracy notice.
        }
        return geoAnchors.userFacingNotice
    }
    var destinationName: String? { tour.arStop?.name }
    var distanceText: String {
        if tour.arStop?.id != tour.currentStop?.id { return "Sketch discovery" }
        return tour.hasPlaqueConfirmedArrival ? "At plaque" : tour.remainingDistanceText
    }
    var timeText: String {
        if tour.arStop?.id != tour.currentStop?.id { return "Optional" }
        return tour.hasPlaqueConfirmedArrival ? "Arrived" : tour.remainingTimeText
    }

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
        guard let route = tour.currentRoute, let progress = tour.routeProgress,
              progress.distanceFromRoute <= 35 else { return guidanceDetail }
        if let street = ARWalkingGuidance.currentStreetLabel(route: route, progress: progress) { return street }
        if let street = walkingCue?.streetName { return "Toward \(street)" }
        return guidanceDetail
    }

    var isMarkerAvailable: Bool {
        guard isPlaqueScanner else { return false }
        if tour.isPlaqueDiscoveryStop { return false }
        return tour.isSignPresented && (placementMode == .plaqueAnchored || placementMode == .geoFallback)
    }

    var guidanceDetail: String {
        if isMarkerAvailable { return "Look for the stop marker · Tap to discover" }
        if tour.currentRoute == nil { return "Finding your walking route" }
        if let progress = tour.routeProgress, progress.distanceFromRoute > 35 {
            return "Updating your walking route · Use the map"
        }
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
        tour.endARDiscoverySession()
        imageTrackingAvailable = false
        placementMode = .hidden
        plaqueHint = nil
        geoAnchors.sessionDidStop()
        geoAnchors.anchors.detach()
        arView = nil
    }

    private func runSession(on arView: ARView) {
        guard availability == .ready, !isSessionRunning else { return }
        let configuration = makeSessionConfiguration()
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isSessionRunning = true
        if isPlaqueScanner { scannerAttemptStartedAt = Date() }
        tour.isARSessionActive = true
        isShowingWalkingOrientation = !isPlaqueScanner
        walkingOrientation = ARWalkingGuidance.OrientationState()
        geoAnchors.sessionDidStart(arView.session, arView: arView)
        pushTourStateToAnchors()
    }

    /// Session purpose is fixed at entry. Walking never registers physical plaque images.
    func makeSessionConfiguration() -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = isPlaqueScanner ? .gravity : geoAnchors.preferredWorldAlignment
        configuration.planeDetection = isPlaqueScanner ? [] : [.horizontal]
        configuration.environmentTexturing = .none
        configuration.isLightEstimationEnabled = true
        configuration.isAutoFocusEnabled = true
        imageTrackingAvailable = isPlaqueScanner && PlaqueAnchorController.applyDetectionImages(to: configuration)
        return configuration
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
        if observedStopID != tour.arStop?.id {
            observedStopID = tour.arStop?.id
            scannerAttemptStartedAt = Date()
            activationMessage = nil
            isShowingSignDetails = false
            isShowingWalkingOrientation = !isPlaqueScanner
            walkingOrientation = ARWalkingGuidance.OrientationState()
        }
        geoAnchors.hasActivatedStop = isPlaqueScanner ? tour.isARStopVisited : tour.shouldSuppressWalkingAR
        if !isPlaqueScanner { geoAnchors.locationDidUpdate(tour.userLocation, heading: tour.heading) }
        applySignPlacement()
        if tour.presentedSignStop == nil {
            imageRequestedForStopID = nil
        } else if let signStop = tour.presentedSignStop, imageLoader.cachedImage(for: signStop) == nil, signStop.hasAnyImage {
            loadSignImage(for: signStop)
        }
        guard !isPlaqueScanner, tour.arStop?.id == tour.currentStop?.id,
              !tour.shouldSuppressWalkingAR, !tour.isRouteAnEstimate,
              tour.currentRoute != nil, let stop = tour.arStop, let user = tour.userLocation,
              StopActivationPolicy.isFresh(user.timestamp), user.horizontalAccuracy.isFinite,
              user.horizontalAccuracy >= 0 else {
            geoAnchors.setNavigationTarget(nil)
            return
        }
        imageLoader.prefetch([stop])
        guard let route = tour.currentRoute, let progress = tour.routeProgress,
              let bearing = ARWalkingGuidance.walkingBearing(route: route, progress: progress, user: user.coordinate) else {
            geoAnchors.setNavigationTarget(nil)
            return
        }
        geoAnchors.setNavigationTarget(GeoAnchorManager.NavigationTarget(
            destination: stop.coordinate,
            bearingToWaypoint: bearing,
            anchorCoordinate: ARStreetGuidance.routePoint(route: route, progress: progress),
            turnCue: walkingCue,
            locationTimestamp: user.timestamp
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

    // MARK: Plaque recognition and sketchbook collection

    var discoverySearchHint: String {
        SignPlacementPolicy.discoveryHint(referenceImageName: tour.arStop?.plaque?.referenceImageName)
    }

    private func applySignPlacement() {
        guard isPlaqueScanner else {
            geoAnchors.dismissSign()
            placementMode = .hidden
            geoAnchors.placementMode = .hidden
            plaqueHint = nil
            return
        }
        if tour.isPlaqueDiscoveryStop {
            // Story is read outside AR. Only the sketch unlock is recorded.
            geoAnchors.dismissSign()
            if placementMode != .hidden { placementMode = .hidden }
            if geoAnchors.placementMode != .hidden { geoAnchors.placementMode = .hidden }
            let hint: String? = tour.discovery.stage == .searching
                ? (imageTrackingAvailable ? discoverySearchHint
                   : "Plaque recognition is unavailable. You can return to the stop and try again.") : nil
            if plaqueHint != hint { plaqueHint = hint }
            return
        }
        // Stops without a reference plaque retain their GPS marker/story flow.
        let mode: SignPlacementMode = tour.presentedSignStop == nil ? .hidden : .geoFallback
        if placementMode != mode { placementMode = mode }
        if geoAnchors.placementMode != mode { geoAnchors.placementMode = mode }
        if plaqueHint != nil { plaqueHint = nil }
        guard let stop = tour.presentedSignStop else { geoAnchors.dismissSign(); return }
        let image = tour.isARStopVisited ? imageLoader.cachedImage(for: stop) : nil
        geoAnchors.presentSign(for: stop, image: image, displayScale: displayScale,
                               appearance: tour.isARStopVisited ? .geoPost : .visitMarker)
    }

    private var expectedPlaqueImageName: String? {
        tour.arStop?.plaque?.referenceImageName
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
        // Recognition is saved independently of subsequent image tracking loss.
        geoAnchors.plaqueAnchors.unbind(sign: geoAnchors.anchors.sign, returningTo: geoAnchors.anchors.worldRoot)
        applySignPlacement()
    }

    /// A supported tracked image is the evidence. Story completion is independent, and image
    /// callbacks never start playback or retarget the walking itinerary.
    private func handleRecognizedPlaque(_ imageAnchor: ARImageAnchor) {
        guard isPlaqueScanner, isSessionRunning else { return }
        let decision = tour.recognizeSketchPlaque(imageName: imageAnchor.referenceImage.name,
            isTracked: imageAnchor.isTracked, trackingReady: geoAnchors.isTrackingReady)
        switch decision {
        case .deny: return
        case .allow, .alreadyActivated: break
        }
        // Resolve the recognized site before synchronizing its visual state. The shared
        // scanner then celebrates the persisted event and its host opens that sketchbook leaf.
        if observedStopID != tour.arStop?.id { pushTourStateToAnchors() }
        geoAnchors.plaqueAnchors.observe(imageAnchor)
        geoAnchors.hasActivatedStop = true
        applySignPlacement()
    }

    // MARK: Session delegate forwarding

    func frameDidUpdate(_ frame: ARFrame) {
        geoAnchors.frameDidUpdate(frame)
        updateWalkingOrientation(timestamp: frame.timestamp)

    }

    func startPlaqueDiscovery() {
        guard isPlaqueScanner else { return }
        guard let stopID = tour.arStop?.id, tour.preparePlaqueScanner(stopID: stopID) else { return }
        scannerAttemptStartedAt = Date()
        isShowingWalkingOrientation = false
        geoAnchors.setNavigationTarget(nil)
        isShowingSignDetails = false
        pushTourStateToAnchors()
        // ARKit may keep the plaque continuously tracked while the story sheet is open.
        // Reuse its current tracked anchor instead of requiring a new didAdd callback.
        if let anchors = arView?.session.currentFrame?.anchors {
            imageAnchorsDidUpdate(anchors)
        }
    }

    var scannerPhaseTitle: String {
        guard isSessionRunning else { return "Camera starting" }
        guard imageTrackingAvailable else { return "Recognition unavailable" }
        if case .failed = localizationState { return "Scanning stopped" }
        return tour.discovery.hasVerifiedPlaque ? "Plaque found" : "Looking for plaque"
    }

    var scannerSketchResult: String {
        if tour.discovery.isPracticeUnlock { return "Practice recognition · Sketch not saved" }
        guard let id = tour.arStop?.id, tour.activities[id].plaqueUnlockedAt != nil else {
            return "Plaque recognized · Sketch not saved"
        }
        return "Sketch unlocked"
    }

    func scannerInstruction(at date: Date) -> String {
        guard isSessionRunning else { return "Preparing the camera. You can return to the story at any time." }
        guard imageTrackingAvailable else { return "Plaque recognition is unavailable. Return to the story or try again." }
        if case .failed = localizationState { return "Scanning stopped. Try again, or return to the story." }
        if tour.discovery.hasVerifiedPlaque {
            return scannerSketchResult
        }
        if date.timeIntervalSince(scannerAttemptStartedAt) >= 12 {
            return "Move closer until the whole plaque is visible. Hold steady, avoid glare and try better light. You can retry or return to the story."
        }
        return "Frame the entire plaque and some surrounding wall in good light."
    }

    /// Retry discards camera tracking only; saved learning/visits/sketches and routing survive.
    func retryPlaqueScanner() {
        guard isPlaqueScanner else { return }
        scannerAttemptStartedAt = Date()
        activationMessage = nil
        if let stopID = tour.arStop?.id { _ = tour.preparePlaqueScanner(stopID: stopID) }
        retrySession()
    }

    private func updateWalkingOrientation(timestamp: TimeInterval) {
        guard !isPlaqueScanner else { isShowingWalkingOrientation = false; return }
        let visible = walkingOrientation.update(relativeBearing: relativeBearingToWaypoint, timestamp: timestamp,
                                                isAtStop: tour.isARStopVisited || isMarkerAvailable || tour.phase == .complete
                                                    || (tour.isPlaqueDiscoveryStop && tour.discovery.hasArrived))
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

    func sessionWasInterrupted() {
        geoAnchors.sessionWasInterrupted()
    }

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
        guard isPlaqueScanner else { return }
        guard let entity else { return }
        if geoAnchors.isCloseControl(entity) {
            closeSign()
            return
        }
        guard geoAnchors.isSignEntity(entity), tour.isSignPresented else { return }
        if tour.isARStopVisited {
            isShowingSignDetails = true
        } else {
            activateMarker()
        }
    }

    /// The on-screen accessibility button and a tap on the 3D marker use the same checks.
    func activateMarker() {
        guard isPlaqueScanner else { return }
        guard let stop = tour.arStop else { return }
        if stop.hasPlaqueReference { isShowingSignDetails = true; return }
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
            isShowingSignDetails = true
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
        guard !isPlaqueScanner, tour.canContinueARStop else { return }
        isShowingSignDetails = false
        activationMessage = nil
        tour.completeCurrentStopAndAdvance()
        pushTourStateToAnchors()
    }

    func showSign() {
        guard isPlaqueScanner else { return }
        activationMessage = nil
        tour.openSignManually()
    }

    var canShowSignManually: Bool {
        guard isPlaqueScanner else { return false }
        if tour.isPlaqueDiscoveryStop { return false }
        guard let state = tour.proximityState else { return false }
        return tour.isARStopVisited || state == .signDismissed || state == .nearby
            || (state == .approaching && tour.isWithinArrivalRadius)
    }
}
