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

    var isTrackingReady: Bool {
        guard cameraTransform != nil, !isInterrupted, case .normal = trackingState else { return false }
        if case .failed = localizationState { return false }
        return true
    }

    /// Route-aware direction and destination identity (forces a fresh layout on Continue).
    struct NavigationTarget: Equatable {
        var destination: GeoCoordinate
        var bearingToWaypoint: Double
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
        cameraTransform = nil
        trackingState = .notAvailable
        navigationBearing = nil
        lastFrameTime = 0
        anchors.attach(to: arView)
        plaqueAnchors.attach(to: arView)
        provider.attach(session: session)
        localizationState = .initializing
        isInterrupted = false
        geospatialWaitStarted = nil
    }

    func sessionDidStop() {
        provider.detach()
        plaqueAnchors.unbind(sign: anchors.sign, returningTo: anchors.worldRoot)
        anchors.hideAll()
        signAnchoredPosition = nil
        localizationState = .notStarted
        navigationBearing = nil
        cameraTransform = nil
    }

    func sessionWasInterrupted() {
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
        refreshLocalizationState()
        considerGeospatialFallback()
        placeContent(now: timestamp)
        placeSign(now: timestamp)
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
            placeContent(now: lastFrameTime, forceLayout: true)
        }
    }

    // MARK: Placement

    /// User-space position of the camera projected to the arrow plane.
    private var cameraGroundPosition: SIMD3<Float>? {
        guard let cameraTransform else { return nil }
        var p = cameraTransform.translation
        p.y -= ARNavigationArrowEntity.heightBelowCamera
        return p
    }

    private func placeContent(now: TimeInterval, forceLayout: Bool = false) {
        guard !hasActivatedStop, isTrackingReady, let base = cameraGroundPosition else {
            anchors.arrows.setVisible(false)
            navigationBearing = nil
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
                anchors.arrows.setVisible(false)
                navigationBearing = nil
                return
            }
            direction = worldDirection
            markerDistance = nil
        }
        guard simd_length(direction) > 0.05 else {
            anchors.arrows.setVisible(false)
            navigationBearing = nil
            return
        }
        updateCameraGuidance(direction: direction)
        anchors.arrows.setVisible(true)
        // Keep arrows until activation, including inside the GPS arrival radius.
        anchors.arrows.update(base: base, direction: direction, now: now, force: forceLayout, maximumDistance: markerDistance)
    }

    private func updateCameraGuidance(direction: SIMD3<Float>) {
        guard let cameraTransform else { navigationBearing = nil; return }
        let next = ARWalkingGuidance.relativeBearing(
            directionX: Double(direction.x), directionZ: Double(direction.z),
            cameraForwardX: Double(-cameraTransform.columns.2.x),
            cameraForwardZ: Double(-cameraTransform.columns.2.z)
        )
        if let previous = navigationBearing, let next,
           abs(GeoMath.relativeBearing(heading: previous, bearing: next)) < 2 { return }
        navigationBearing = next
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
