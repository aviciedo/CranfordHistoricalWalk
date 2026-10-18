import ARKit
import Foundation
import Observation
import RealityKit
import simd
import TourCore
import UIKit

/// Where AR tracking stands, in user terms (spec §15, §21).
enum ARLocalizationState: Equatable {
    case notStarted
    case initializing
    case tracking(GeoLocalizationQuality)
    case limited(String)
    case interrupted
    case failed(String)

    var isUsable: Bool {
        if case .tracking(let q) = self { return q.isUsable }
        return false
    }

    var userMessage: String? {
        switch self {
        case .notStarted, .initializing: return "Hold your phone up and look around to start AR."
        case .tracking(let q):
            switch q {
            case .good, .fair: return nil
            case .poor: return "AR positioning is approximate — localization accuracy is low."
            case .unavailable: return "AR positioning is temporarily unavailable. Continue walking and try again."
            }
        case .limited(let reason): return reason
        case .interrupted: return "AR paused. Return to the app to continue."
        case .failed(let text): return text
        }
    }
}

/// Bridges geography and the AR scene (spec §15): determines position/heading through a
/// `GeoSpatialProvider`, tracks AR localization state, and places/refreshes AR content.
@MainActor
@Observable
final class GeoAnchorManager {
    private(set) var localizationState: ARLocalizationState = .notStarted
    private(set) var provider: any GeoSpatialProvider
    let anchors: ARAnchorManager
    let plaqueAnchors = PlaqueAnchorController()
    /// Placement decided by `SignPlacementPolicy` (image vs geo). Not tour progress.
    var placementMode: SignPlacementMode = .hidden
    var hasActivatedStop = false
    private(set) var navigationBearing: Double?
    private(set) var isWindowBonusAccessible = false

    var isTrackingReady: Bool {
        guard cameraTransform != nil, !isInterrupted, case .normal = trackingState else { return false }
        if case .failed = localizationState { return false }
        return true
    }

    /// Route-aware direction and destination identity (forces a fresh layout on Continue).
    struct NavigationTarget: Equatable {
        var destination: GeoCoordinate
        var bearingToWaypoint: Double
        var turnCue: ARWalkingGuidance.RouteCue?
    }

    /// Sign content requested by the view model; placed as soon as the camera is tracking.
    struct SignRequest: Equatable {
        var stop: HistoricalStop
        var image: LoadedImage?
        var displayScale: CGFloat
        static func == (lhs: SignRequest, rhs: SignRequest) -> Bool {
            lhs.stop.id == rhs.stop.id && (lhs.image == nil) == (rhs.image == nil)
        }
    }

    @ObservationIgnored private var target: NavigationTarget?
    @ObservationIgnored private var signRequest: SignRequest?
    @ObservationIgnored private var signAnchoredPosition: SIMD3<Float>?
    @ObservationIgnored private var lastSignMoveTime: TimeInterval = 0
    @ObservationIgnored private var lastFrameTime: TimeInterval = 0
    @ObservationIgnored private var cameraTransform: simd_float4x4?
    @ObservationIgnored private var trackingState: ARCamera.TrackingState = .notAvailable
    @ObservationIgnored private var isInterrupted = false
    @ObservationIgnored private var groundHeight: Float?
    @ObservationIgnored private var lastGuidanceTime: TimeInterval?
    @ObservationIgnored private var windowStopID: String?
    @ObservationIgnored private var windowLayout: WindowBonusLayout?
    @ObservationIgnored private var windowPosition: SIMD3<Float>?
    @ObservationIgnored private var windowWasClosed = false

    /// Called when Geospatial cannot be used and Core Location should take over.
    var onNeedsFallback: ((GeoSpatialFallbackReason) -> Void)?
    @ObservationIgnored private var geospatialWaitStarted: TimeInterval?
    @ObservationIgnored private var didRequestFallback = false

    /// Frames are processed at most this often (seconds). ARKit delivers 60 Hz; 10 Hz is plenty.
    static let frameInterval: TimeInterval = 0.1

    init(provider: any GeoSpatialProvider, anchors: ARAnchorManager? = nil) {
        self.provider = provider
        self.anchors = anchors ?? ARAnchorManager()
    }

    var preferredWorldAlignment: ARConfiguration.WorldAlignment { provider.preferredWorldAlignment }

    /// Combines ARKit tracking copy with Geospatial fallback / VPS-reduced-accuracy copy.
    var userFacingNotice: String? {
        if let notice = provider.statusNotice {
            if case .tracking(let quality) = localizationState, quality.isUsable {
                return notice
            }
            if localizationState.userMessage == nil { return notice }
        }
        return localizationState.userMessage ?? provider.statusNotice
    }

    /// Swap in a stronger provider (e.g. ARCore) later without touching the rest of the AR code.
    func replaceProvider(with newProvider: any GeoSpatialProvider, session: ARSession?) {
        provider.detach()
        provider = newProvider
        geospatialWaitStarted = nil
        didRequestFallback = false
        if let session { newProvider.attach(session: session) }
    }

    // MARK: Session lifecycle

    func sessionDidStart(_ session: ARSession, arView: ARView) {
        clearWindowBonus()
        cameraTransform = nil
        trackingState = .notAvailable
        navigationBearing = nil
        groundHeight = nil
        lastGuidanceTime = nil
        lastFrameTime = 0
        anchors.attach(to: arView)
        plaqueAnchors.attach(to: arView)
        provider.attach(session: session)
        localizationState = .initializing
        isInterrupted = false
        geospatialWaitStarted = nil
    }

    func sessionDidStop() {
        clearWindowBonus()
        provider.detach()
        plaqueAnchors.unbind(sign: anchors.sign, returningTo: anchors.worldRoot)
        anchors.hideAll()
        signAnchoredPosition = nil
        localizationState = .notStarted
        navigationBearing = nil
        cameraTransform = nil
    }

    func sessionWasInterrupted() {
        isWindowBonusAccessible = false
        isInterrupted = true
        navigationBearing = nil
        plaqueAnchors.unbind(sign: anchors.sign, returningTo: anchors.worldRoot)
        anchors.hideAll()
        signAnchoredPosition = nil
        localizationState = .interrupted
    }

    func sessionInterruptionEnded() {
        isInterrupted = false
        localizationState = .initializing
    }

    func sessionDidFail(_ message: String) {
        isWindowBonusAccessible = false
        anchors.windowBonus.isEnabled = false
        anchors.hideNavigation()
        navigationBearing = nil
        localizationState = .failed(message)
    }

    func trackingStateDidChange(_ state: ARCamera.TrackingState) {
        trackingState = state
        refreshLocalizationState()
    }

    // MARK: Inputs

    /// Called from the AR session delegate (main queue). Throttled; the `ARFrame` is not stored.
    func frameDidUpdate(_ frame: ARFrame) {
        let timestamp = frame.timestamp
        guard timestamp - lastFrameTime >= GeoAnchorManager.frameInterval else { return }
        lastFrameTime = timestamp
        let cameraTransform = frame.camera.transform
        let trackingState = frame.camera.trackingState
        self.cameraTransform = cameraTransform
        self.trackingState = trackingState
        provider.update(frame: frame)
        provider.update(cameraTransform: cameraTransform, trackingState: trackingState, timestamp: timestamp)
        updateGroundHeight(frame: frame)
        refreshLocalizationState()
        considerGeospatialFallback()
        placeContent(now: timestamp)
        placeSign(now: timestamp)
        refreshWindowBonusAccess()
    }

    /// Capture a facade pose from the plaque, then keep a WORLD anchor over the panes when
    /// the camera moves off the plaque. This does not claim independent window recognition.
    func presentWindowBonus(for stop: HistoricalStop, imageAnchor: ARImageAnchor, layout: WindowBonusLayout, displayScale: CGFloat) {
        if windowStopID != stop.id { clearWindowBonus(); windowStopID = stop.id }
        guard !windowWasClosed else { return }
        guard windowPosition == nil || windowLayout != layout else { refreshWindowBonusAccess(); return }
        let plaqueWidth = Double(imageAnchor.referenceImage.physicalSize.width)
        guard let size = layout.dimensions(plaqueWidthMeters: plaqueWidth),
              let offset = layout.translation(plaqueWidthMeters: plaqueWidth),
              anchors.windowBonus.configure(stop: stop, image: nil, scale: displayScale, appearance: .windowBonus) else { return }
        var translation = matrix_identity_float4x4
        translation.columns.3 = SIMD4<Float>(Float(offset.x), Float(offset.y), Float(offset.z), 1)
        let faceOut = simd_float4x4(simd_quatf(angle: -.pi / 2, axis: [1, 0, 0]))
        let world = imageAnchor.transform * translation * faceOut
        anchors.windowBonus.transform = Transform(matrix: world)
        anchors.windowBonus.setWindowSize(width: Float(size.width), height: Float(size.height))
        if !anchors.windowBonus.isPresented { anchors.windowBonus.presentOnPlaque() }
        windowPosition = world.translation
        windowLayout = layout
        refreshWindowBonusAccess()
    }

    func closeWindowBonus() {
        windowWasClosed = true
        anchors.windowBonus.dismiss()
    }

    func reopenWindowBonus() {
        guard isWindowBonusAccessible else { return }
        windowWasClosed = false
        if !anchors.windowBonus.isPresented { anchors.windowBonus.presentOnPlaque() }
    }

    func clearWindowBonus() {
        guard windowStopID != nil || windowPosition != nil || anchors.windowBonus.isPresented else { return }
        anchors.windowBonus.dismiss()
        windowStopID = nil
        windowPosition = nil
        windowLayout = nil
        windowWasClosed = false
        isWindowBonusAccessible = false
    }

    private func refreshWindowBonusAccess() {
        let accessible = windowPosition.map { point in
            guard let camera = cameraTransform?.translation else { return false }
            return isTrackingReady && simd_distance(camera, point) <= 12
        } ?? false
        if isWindowBonusAccessible != accessible { isWindowBonusAccessible = accessible }
        if anchors.windowBonus.isPresented { anchors.windowBonus.isEnabled = accessible && !windowWasClosed }
    }

    // MARK: Sign

    /// Show the sign for `stop` (idempotent). The texture is rendered once per stop.
    func presentSign(for stop: HistoricalStop, image: LoadedImage?, displayScale: CGFloat) {
        presentSign(for: stop, image: image, displayScale: displayScale, appearance: .geoPost)
    }

    func presentSign(for stop: HistoricalStop, image: LoadedImage?, displayScale: CGFloat, appearance: ARHistoricalSignEntity.Appearance, anchorToPlaque: Bool = false) {
        let request = SignRequest(stop: stop, image: image, displayScale: displayScale)
        let sameStop = signRequest?.stop.id == stop.id
        let wasOnPlaque = anchors.sign.parent !== anchors.worldRoot
        let previousAppearance = anchors.sign.appearance
        guard anchors.sign.configure(stop: stop, image: image, scale: displayScale, appearance: appearance) else {
            dismissSign()
            return
        }
        signRequest = request
        if anchorToPlaque || appearance == .plaqueCard {
            if let imageAnchor = plaqueAnchors.trackedAnchor {
                plaqueAnchors.bind(imageAnchor: imageAnchor, sign: anchors.sign, offset: .abovePlaque)
            }
            if !wasOnPlaque || previousAppearance != appearance || !anchors.sign.isPresented {
                anchors.sign.presentOnPlaque()
            }
            return
        }
        let switchingFromPlaque = wasOnPlaque
        plaqueAnchors.unbind(sign: anchors.sign, returningTo: anchors.worldRoot)
        if switchingFromPlaque {
            signAnchoredPosition = nil
            if anchors.sign.isPresented { anchors.sign.dismiss() }
            placeSign(now: lastFrameTime)
            return
        }
        // Artwork arriving for the sign already on display swaps the texture in place; a new stop
        // replays the entrance at a fresh position.
        guard !(sameStop && previousAppearance == appearance && anchors.sign.isPresented) else { return }
        signAnchoredPosition = nil
        if anchors.sign.isPresented { anchors.sign.dismiss() }
        placeSign(now: lastFrameTime)
    }

    func dismissSign() {
        guard signRequest != nil || anchors.sign.isPresented else { return }
        signRequest = nil
        signAnchoredPosition = nil
        plaqueAnchors.unbind(sign: anchors.sign, returningTo: anchors.worldRoot)
        anchors.sign.dismiss()
    }

    var isSignEntity: (Entity) -> Bool { { [anchors] in anchors.sign.contains($0) } }
    var isCloseControl: (Entity) -> Bool { { [anchors] in anchors.sign.containsCloseControl($0) } }

    /// Sign base sits this far below the camera (bottom edge roughly at chest height).
    static let signBaseBelowCamera: Float = 0.45
    static let signMinDistance: Float = 2.4
    static let signMaxDistance: Float = 9.0

    private func placeSign(now: TimeInterval) {
        guard placementMode == .geoFallback else { return }
        guard let request = signRequest, let cameraTransform else { return }
        guard case .normal = trackingState, !isInterrupted else { return }
        let cameraPosition = cameraTransform.translation

        // Geographic placement when the provider can localize; otherwise a comfortable spot ahead.
        var base: SIMD3<Float>
        if let geo = provider.worldPosition(for: request.stop.coordinate, altitude: request.stop.altitude, heightBelowCamera: GeoAnchorManager.signBaseBelowCamera) {
            base = geo
        } else {
            let forward = -SIMD3<Float>(cameraTransform.columns.2.x, 0, cameraTransform.columns.2.z)
            let dir = simd_length(forward) > 0.1 ? simd_normalize(forward) : SIMD3<Float>(0, 0, -1)
            base = cameraPosition + dir * 3.5
            base.y = cameraPosition.y - GeoAnchorManager.signBaseBelowCamera
        }
        // Clamp so GPS error never puts the sign inside the user or a block away (spec §15 honesty).
        var flat = SIMD3<Float>(base.x - cameraPosition.x, 0, base.z - cameraPosition.z)
        var distance = simd_length(flat)
        if distance < 0.01 {
            flat = -SIMD3<Float>(cameraTransform.columns.2.x, 0, cameraTransform.columns.2.z)
            distance = max(simd_length(flat), 0.01)
        }
        let clamped = min(max(distance, GeoAnchorManager.signMinDistance), GeoAnchorManager.signMaxDistance)
        let dir = flat / distance
        base = SIMD3<Float>(cameraPosition.x + dir.x * clamped, base.y, cameraPosition.z + dir.z * clamped)

        let sign = anchors.sign
        if !sign.isPresented {
            sign.present(at: base, facing: cameraPosition)
            signAnchoredPosition = base
            lastSignMoveTime = now
            return
        }
        // Re-anchor only on meaningful change, at most every few seconds, so the sign feels fixed.
        if let anchored = signAnchoredPosition, simd_distance(anchored, base) > 2.5, now - lastSignMoveTime > 3 {
            sign.move(to: base, facing: cameraPosition)
            signAnchoredPosition = base
            lastSignMoveTime = now
        } else if now - lastSignMoveTime > 0.7 {
            sign.face(cameraPosition, animated: false)
        }
    }

    func locationDidUpdate(_ location: LocationSample?, heading: HeadingSample?) {
        provider.update(location: location, heading: heading)
        refreshLocalizationState()
    }

    func setNavigationTarget(_ newTarget: NavigationTarget?) {
        let destinationChanged = newTarget?.destination != target?.destination
        target = newTarget
        if destinationChanged, cameraTransform != nil {
            navigationBearing = nil
            lastGuidanceTime = nil
            placeContent(now: lastFrameTime, forceLayout: true)
        }
    }

    // MARK: Placement

    /// User-space position of the camera projected to the arrow plane.
    private var cameraGroundPosition: SIMD3<Float>? {
        guard let cameraTransform else { return nil }
        var p = cameraTransform.translation
        p.y = (groundHeight ?? (p.y - ARNavigationArrowEntity.heightBelowCamera)) + 0.015
        return p
    }

    /// Prefer a nearby detected horizontal surface beneath the phone. Until one is found,
    /// hold a stable estimated height rather than making the arrow bob with the camera.
    private func updateGroundHeight(frame: ARFrame) {
        let camera = frame.camera.transform.translation
        let candidates = frame.anchors.compactMap { $0 as? ARPlaneAnchor }.filter { plane in
            let center = plane.transform * SIMD4<Float>(plane.center.x, plane.center.y, plane.center.z, 1)
            let below = camera.y - center.y
            return plane.alignment == .horizontal && plane.extent.x * plane.extent.z >= 0.5
                && plane.classification != .table && plane.classification != .seat && plane.classification != .ceiling
                && below > 0.45 && below < 2.5
                && simd_length(SIMD2(center.x - camera.x, center.z - camera.z)) < 8
        }
        let closest = candidates.min { lhs, rhs in
            let l = lhs.transform * SIMD4<Float>(lhs.center.x, lhs.center.y, lhs.center.z, 1)
            let r = rhs.transform * SIMD4<Float>(rhs.center.x, rhs.center.y, rhs.center.z, 1)
            return simd_length(SIMD2(l.x - camera.x, l.z - camera.z)) < simd_length(SIMD2(r.x - camera.x, r.z - camera.z))
        }
        if let closest {
            let center = closest.transform * SIMD4<Float>(closest.center.x, closest.center.y, closest.center.z, 1)
            groundHeight = groundHeight.map { $0 + (center.y - $0) * 0.12 } ?? center.y
        } else if groundHeight == nil, case .normal = frame.camera.trackingState {
            groundHeight = camera.y - ARNavigationArrowEntity.heightBelowCamera
        }
    }

    private func placeContent(now: TimeInterval, forceLayout: Bool = false) {
        guard !hasActivatedStop, isTrackingReady, let base = cameraGroundPosition else {
            anchors.hideNavigation()
            navigationBearing = nil
            lastGuidanceTime = nil
            return
        }
        let direction: SIMD3<Float>
        let markerDistance: Float?
        if anchors.sign.isPresented,
           placementMode == .plaqueAnchored || (placementMode == .geoFallback && localizationState.isUsable) {
            // A real image anchor is stronger than the bundled geocode. Point to the
            // actual marker, not back toward a potentially incorrect GPS destination.
            let marker = anchors.sign.position(relativeTo: anchors.worldRoot)
            direction = SIMD3(marker.x - base.x, 0, marker.z - base.z)
            markerDistance = simd_length(direction)
        } else {
            guard localizationState.isUsable, let target,
                  let worldDirection = provider.worldDirection(forBearing: target.bearingToWaypoint) else {
                anchors.hideNavigation()
                navigationBearing = nil
                return
            }
            direction = worldDirection
            markerDistance = nil
        }
        guard simd_length(direction) > 0.05 else {
            anchors.hideNavigation()
            navigationBearing = nil
            return
        }
        updateCameraGuidance(direction: direction, now: now)
        anchors.arrows.setVisible(true)
        // Keep arrows until activation, including inside the GPS arrival radius.
        anchors.arrows.update(base: base, direction: direction, force: forceLayout, maximumDistance: markerDistance)
        if markerDistance == nil, let cue = target?.turnCue, cue.isUpcomingTurn,
           cue.isNearTurn || (anchors.turnSign.isShowing && cue.distanceMeters <= 55), let coordinate = cue.coordinate,
           let camera = cameraTransform?.translation,
           var position = provider.worldPosition(for: coordinate, altitude: nil, heightBelowCamera: 0) {
            let flat = SIMD3<Float>(position.x - camera.x, 0, position.z - camera.z)
            let distance = simd_length(flat)
            if distance > 0.1 {
                position = camera + flat / distance * max(3, min(25, distance))
                position.y = base.y + 2.0
                anchors.turnSign.update(cue: cue, position: position, camera: camera)
            } else {
                anchors.turnSign.hide(animated: true)
            }
        } else {
            anchors.turnSign.hide(animated: true)
        }
    }

    private func updateCameraGuidance(direction: SIMD3<Float>, now: TimeInterval) {
        guard let cameraTransform else { navigationBearing = nil; return }
        let next = ARWalkingGuidance.relativeBearing(
            directionX: Double(direction.x), directionZ: Double(direction.z),
            cameraForwardX: Double(-cameraTransform.columns.2.x),
            cameraForwardZ: Double(-cameraTransform.columns.2.z)
        )
        let elapsed = lastGuidanceTime.map { now - $0 } ?? Self.frameInterval
        lastGuidanceTime = now
        guard let next else { navigationBearing = nil; return }
        navigationBearing = ARWalkingGuidance.smoothAngle(from: navigationBearing, to: next, elapsed: elapsed)
    }

    /// World position for a stop, used by the sign (Stage 5) and by debugging overlays.
    func worldPosition(for coordinate: GeoCoordinate, altitude: Double? = nil, heightBelowCamera: Float) -> SIMD3<Float>? {
        provider.worldPosition(for: coordinate, altitude: altitude, heightBelowCamera: heightBelowCamera)
    }

    var cameraPosition: SIMD3<Float>? { cameraTransform?.translation }

    // MARK: State

    private func refreshLocalizationState() {
        if isInterrupted { localizationState = .interrupted; return }
        if case .failed = localizationState { return }
        switch trackingState {
        case .notAvailable:
            localizationState = .initializing
        case .limited(let reason):
            localizationState = .limited(GeoAnchorManager.message(for: reason))
        case .normal:
            localizationState = .tracking(provider.quality)
        }
    }

    private func considerGeospatialFallback() {
        guard provider.backend == .arCoreGeospatial, !didRequestFallback else { return }
        if let reason = provider.fallbackReason {
            switch reason {
            case .deviceUnsupported, .sessionConfigurationFailed, .earthNotAuthorized, .earthResourceExhausted, .earthInternalError:
                requestFallback(reason)
                return
            default:
                break
            }
        }
        guard case .normal = trackingState else { return }
        if provider.quality.isUsable {
            geospatialWaitStarted = nil
            return
        }
        if geospatialWaitStarted == nil { geospatialWaitStarted = lastFrameTime }
        if lastFrameTime - (geospatialWaitStarted ?? lastFrameTime) >= GeoSpatialSelector.localizationTimeout {
            requestFallback(.localizationTimedOut)
        }
    }

    private func requestFallback(_ reason: GeoSpatialFallbackReason) {
        guard !didRequestFallback else { return }
        didRequestFallback = true
        onNeedsFallback?(reason)
    }

    static func message(for reason: ARCamera.TrackingState.Reason) -> String {
        switch reason {
        case .initializing: return "Starting AR — move your phone slowly."
        case .excessiveMotion: return "Slow down — moving too fast for AR tracking."
        case .insufficientFeatures: return "Point the camera at more detailed surroundings."
        case .relocalizing: return "Re-establishing AR tracking…"
        @unknown default: return "AR tracking is limited."
        }
    }
}
