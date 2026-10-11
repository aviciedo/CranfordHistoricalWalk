import ARKit
import Foundation
import Observation
import RealityKit
import simd
import TourCore

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

    @ObservationIgnored private var target: NavigationTarget?
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
        anchors.hideNavigation()
        localizationState = .notStarted
        cameraTransform = nil
    }

    func sessionWasInterrupted() {
        isInterrupted = true
        anchors.hideNavigation()
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
