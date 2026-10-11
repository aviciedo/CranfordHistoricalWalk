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
            case .poor: return "AR positioning is approximate — GPS or compass accuracy is low."
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

    /// Navigation target (next waypoint on the route) and destination (the stop itself).
    struct NavigationTarget: Equatable {
        var waypoint: GeoCoordinate
        var destination: GeoCoordinate
        var bearingToWaypoint: Double
        var distanceToDestination: Double
        var arrivalRadius: Double
    }

    /// Sign content requested by the view model; placed as soon as the camera is tracking.
    struct SignRequest: Equatable {
        var stop: HistoricalStop
        var image: UIImage?
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

    /// Frames are processed at most this often (seconds). ARKit delivers 60 Hz; 10 Hz is plenty.
    static let frameInterval: TimeInterval = 0.1

    init(provider: any GeoSpatialProvider, anchors: ARAnchorManager = ARAnchorManager()) {
        self.provider = provider
        self.anchors = anchors
    }

    var preferredWorldAlignment: ARConfiguration.WorldAlignment { provider.preferredWorldAlignment }

    /// Swap in a stronger provider (e.g. ARCore) later without touching the rest of the AR code.
    func replaceProvider(with newProvider: any GeoSpatialProvider, session: ARSession?) {
        provider.detach()
        provider = newProvider
        if let session { newProvider.attach(session: session) }
    }

    // MARK: Session lifecycle

    func sessionDidStart(_ session: ARSession, arView: ARView) {
        anchors.attach(to: arView)
        provider.attach(session: session)
        localizationState = .initializing
        isInterrupted = false
    }

    func sessionDidStop() {
        provider.detach()
        anchors.hideAll()
        signAnchoredPosition = nil
        localizationState = .notStarted
        cameraTransform = nil
    }

    func sessionWasInterrupted() {
        isInterrupted = true
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
        localizationState = .failed(message)
    }

    func trackingStateDidChange(_ state: ARCamera.TrackingState) {
        trackingState = state
        refreshLocalizationState()
    }

    // MARK: Inputs

    /// Called from the AR session delegate (main queue). Throttled; retains no `ARFrame`.
    func frameDidUpdate(cameraTransform: simd_float4x4, trackingState: ARCamera.TrackingState, timestamp: TimeInterval) {
        guard timestamp - lastFrameTime >= GeoAnchorManager.frameInterval else { return }
        lastFrameTime = timestamp
        self.cameraTransform = cameraTransform
        self.trackingState = trackingState
        provider.update(cameraTransform: cameraTransform, trackingState: trackingState, timestamp: timestamp)
        refreshLocalizationState()
        placeContent(now: timestamp)
        placeSign(now: timestamp)
    }

    // MARK: Sign

    /// Show the sign for `stop` (idempotent). The texture is rendered once per stop.
    func presentSign(for stop: HistoricalStop, image: UIImage?, displayScale: CGFloat) {
        let request = SignRequest(stop: stop, image: image, displayScale: displayScale)
        guard request != signRequest else { return }
        signRequest = request
        signAnchoredPosition = nil
        anchors.sign.configure(stop: stop, image: image, scale: displayScale)
        if anchors.sign.isPresented { anchors.sign.dismiss() }
        placeSign(now: lastFrameTime)
    }

    func dismissSign() {
        guard signRequest != nil else { return }
        signRequest = nil
        signAnchoredPosition = nil
        anchors.sign.dismiss()
    }

    var isSignEntity: (Entity) -> Bool { { [anchors] in anchors.sign.contains($0) } }

    /// Sign base sits this far below the camera (bottom edge roughly at chest height).
    static let signBaseBelowCamera: Float = 0.45
    static let signMinDistance: Float = 2.4
    static let signMaxDistance: Float = 9.0

    private func placeSign(now: TimeInterval) {
        guard let request = signRequest, let cameraTransform else { return }
        guard case .normal = trackingState, !isInterrupted else { return }
        let cameraPosition = cameraTransform.translation

        // Geographic placement when the provider can localize; otherwise a comfortable spot ahead.
        var base: SIMD3<Float>
        if let geo = provider.worldPosition(for: request.stop.coordinate, heightBelowCamera: GeoAnchorManager.signBaseBelowCamera) {
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
        guard localizationState.isUsable, let target, let base = cameraGroundPosition else {
            anchors.arrows.setVisible(false)
            return
        }
        // Inside the arrival radius the sign takes over (Stage 5); arrows would only clutter.
        guard target.distanceToDestination > target.arrivalRadius else {
            anchors.arrows.setVisible(false)
            return
        }
        // Point at the next route vertex unless the destination is close, then point straight at it.
        let bearing: Double
        if target.distanceToDestination < 20, let pose = provider.pose {
            bearing = GeoMath.bearing(from: pose.coordinate, to: target.destination)
        } else {
            bearing = target.bearingToWaypoint
        }
        guard let direction = provider.worldDirection(forBearing: bearing) else {
            anchors.arrows.setVisible(false)
            return
        }
        anchors.arrows.setVisible(true)
        anchors.arrows.update(base: base, direction: direction, now: now, force: forceLayout)
    }

    /// World position for a stop, used by the sign (Stage 5) and by debugging overlays.
    func worldPosition(for coordinate: GeoCoordinate, heightBelowCamera: Float) -> SIMD3<Float>? {
        provider.worldPosition(for: coordinate, heightBelowCamera: heightBelowCamera)
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
