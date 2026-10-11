import ARKit
import CoreLocation
import Foundation
import simd
import TourCore

/// How much to trust geographic placement of AR content right now (spec §15, §21).
enum GeoLocalizationQuality: Equatable {
    /// No fix, no AR tracking, or the provider is not attached.
    case unavailable
    /// Fix exists but accuracy is poor (> 25 m or heading error > 30°).
    case poor
    /// Typical outdoor GPS + compass.
    case fair
    /// VPS-grade (ARCore Geospatial) or very good GPS.
    case good

    var isUsable: Bool { self == .fair || self == .good }
}

struct GeoPose: Equatable, Sendable {
    var coordinate: GeoCoordinate
    var horizontalAccuracy: Double
    /// True heading in degrees when known.
    var heading: Double?
    var headingAccuracy: Double?
    var timestamp: Date
}

/// Converts geographic coordinates into AR world-space positions.
///
/// `CoreLocationGeoSpatialProvider` is the MVP implementation (GPS + compass + ARKit world tracking).
/// `ARCoreGeoSpatialProvider` is the integration point for Google's Geospatial API / VPS; swapping
/// providers requires no changes to `GeoAnchorManager` or the views.
@MainActor
protocol GeoSpatialProvider: AnyObject {
    var displayName: String { get }
    var quality: GeoLocalizationQuality { get }
    var pose: GeoPose? { get }

    /// The world alignment the AR session should run with for this provider.
    var preferredWorldAlignment: ARConfiguration.WorldAlignment { get }

    /// Called once the AR session is running.
    func attach(session: ARSession)
    func detach()

    /// Per-frame hook (already throttled by the caller). `cameraTransform` is ARKit world space.
    func update(cameraTransform: simd_float4x4, trackingState: ARCamera.TrackingState, timestamp: TimeInterval)

    /// Fed from the app's single location source.
    func update(location: LocationSample?, heading: HeadingSample?)

    /// World-space position for a geographic coordinate at the camera's height minus `heightBelowCamera`.
    /// Returns `nil` when the provider cannot localize yet.
    func worldPosition(for coordinate: GeoCoordinate, heightBelowCamera: Float) -> SIMD3<Float>?

    /// Unit vector in world space pointing along a compass bearing on the ground plane.
    func worldDirection(forBearing bearing: Double) -> SIMD3<Float>?
}

// MARK: - Core Location + ARKit implementation

/// Uses ARKit's `.gravityAndHeading` alignment (−Z = true north, +X = east) so that a compass bearing
/// maps directly onto world axes, then offsets from the most recent (GPS fix, camera position) pair.
/// ARKit keeps relative motion accurate between GPS fixes; GPS keeps the pair from drifting.
///
/// Accuracy is bounded by GPS (3–10 m outdoors) and compass error (5–25°). The quality value tells
/// the UI when to warn the user instead of pretending to be precise.
@MainActor
final class CoreLocationGeoSpatialProvider: GeoSpatialProvider {
    let displayName = "GPS + compass (Core Location)"
    private(set) var quality: GeoLocalizationQuality = .unavailable
    private(set) var pose: GeoPose?

    /// Falls back to `.gravity` + manual yaw correction on devices without a compass.
    let preferredWorldAlignment: ARConfiguration.WorldAlignment

    private struct ReferencePair {
        var coordinate: GeoCoordinate
        var cameraPosition: SIMD3<Float>
        var accuracy: Double
        var date: Date
    }

    private var session: ARSession?
    private var cameraTransform: simd_float4x4?
    private var trackingState: ARCamera.TrackingState = .notAvailable
    private var reference: ReferencePair?
    private var pendingLocation: LocationSample?
    private var latestHeading: HeadingSample?
    /// Only used with `.gravity` alignment: rotation (radians) from ARKit −Z to true north.
    private var yawToNorth: Float?

    init(hasCompass: Bool = CLLocationManager.headingAvailable()) {
        preferredWorldAlignment = hasCompass ? .gravityAndHeading : .gravity
    }

    func attach(session: ARSession) {
        self.session = session
        reference = nil
        recomputeQuality()
    }

    func detach() {
        session = nil
        cameraTransform = nil
        reference = nil
        quality = .unavailable
    }

    func update(cameraTransform: simd_float4x4, trackingState: ARCamera.TrackingState, timestamp: TimeInterval) {
        self.cameraTransform = cameraTransform
        self.trackingState = trackingState
        // Pair the newest GPS fix with the camera position as soon as a frame is available.
        if let location = pendingLocation {
            pendingLocation = nil
            bind(location: location, cameraPosition: cameraTransform.translation)
        }
        if preferredWorldAlignment == .gravity, let heading = latestHeading, heading.isReliable {
            // Device yaw in ARKit world: direction the camera looks projected on the ground.
            let forward = -SIMD3<Float>(cameraTransform.columns.2.x, 0, cameraTransform.columns.2.z)
            if simd_length(forward) > 0.2 {
                let cameraYaw = atan2(forward.x, -forward.z) // radians clockwise from −Z
                let trueYaw = Float(heading.bestHeading * .pi / 180)
                yawToNorth = trueYaw - cameraYaw
            }
        }
        recomputeQuality()
    }

    func update(location: LocationSample?, heading: HeadingSample?) {
        latestHeading = heading
        guard let location, location.horizontalAccuracy >= 0 else { return }
        if let cameraTransform, case .normal = trackingState {
            bind(location: location, cameraPosition: cameraTransform.translation)
        } else {
            pendingLocation = location
        }
        pose = GeoPose(
            coordinate: location.coordinate,
            horizontalAccuracy: location.horizontalAccuracy,
            heading: heading?.bestHeading,
            headingAccuracy: heading?.accuracy,
            timestamp: location.timestamp
        )
        recomputeQuality()
    }

    private func bind(location: LocationSample, cameraPosition: SIMD3<Float>) {
        // Prefer not to replace a good reference with a worse one unless the old one is stale.
        if let reference, location.horizontalAccuracy > reference.accuracy * 1.5,
           Date().timeIntervalSince(reference.date) < 20 {
            return
        }
        reference = ReferencePair(coordinate: location.coordinate, cameraPosition: cameraPosition, accuracy: location.horizontalAccuracy, date: Date())
    }

    func worldDirection(forBearing bearing: Double) -> SIMD3<Float>? {
        let θ = Float(bearing * .pi / 180)
        var direction = SIMD3<Float>(sin(θ), 0, -cos(θ))
        if preferredWorldAlignment == .gravity {
            guard let yawToNorth else { return nil }
            direction = rotateY(direction, by: -yawToNorth)
        }
        return direction
    }

    func worldPosition(for coordinate: GeoCoordinate, heightBelowCamera: Float) -> SIMD3<Float>? {
        guard let reference, let cameraTransform else { return nil }
        let offset = GeoMath.localOffset(of: coordinate, from: reference.coordinate)
        var delta = SIMD3<Float>(Float(offset.east), 0, Float(-offset.north))
        if preferredWorldAlignment == .gravity {
            guard let yawToNorth else { return nil }
            delta = rotateY(delta, by: -yawToNorth)
        }
        var position = reference.cameraPosition + delta
        position.y = cameraTransform.translation.y - heightBelowCamera
        return position
    }

    private func rotateY(_ v: SIMD3<Float>, by angle: Float) -> SIMD3<Float> {
        let c = cos(angle), s = sin(angle)
        return SIMD3<Float>(v.x * c + v.z * s, v.y, -v.x * s + v.z * c)
    }

    private func recomputeQuality() {
        guard session != nil, let pose else { quality = .unavailable; return }
        guard case .normal = trackingState, reference != nil else { quality = .unavailable; return }
        if preferredWorldAlignment == .gravity && yawToNorth == nil { quality = .unavailable; return }
        let headingError = pose.headingAccuracy ?? 15
        if pose.horizontalAccuracy > 25 || headingError > 30 || headingError < 0 {
            quality = .poor
        } else if pose.horizontalAccuracy <= 8 && headingError <= 12 {
            quality = .good
        } else {
            quality = .fair
        }
    }
}

// MARK: - ARCore Geospatial integration point

#if ARCORE_GEOSPATIAL && canImport(ARCoreGeospatial)
import ARCoreGeospatial

/// Google ARCore Geospatial API (VPS) provider. Compiled only when the ARCore package is linked and
/// `ENABLE_ARCORE_GEOSPATIAL=1`. The structure follows Google's iOS Geospatial quickstart:
/// create a `GARSession`, enable `geospatialMode`, forward every `ARFrame`, read
/// `earth.cameraGeospatialTransform`, and create anchors with `createAnchor(coordinate:altitude:eastUpSouthQAnchor:)`.
/// Verify names against the ARCore SDK version you link before shipping.
@MainActor
final class ARCoreGeoSpatialProvider: GeoSpatialProvider {
    let displayName = "ARCore Geospatial (VPS)"
    private(set) var quality: GeoLocalizationQuality = .unavailable
    private(set) var pose: GeoPose?
    let preferredWorldAlignment: ARConfiguration.WorldAlignment = .gravity

    private let apiKey: String
    private var garSession: GARSession?
    private var arSession: ARSession?
    private var lastFrame: GARFrame?
    private var lastEarth: GAREarth?

    init(apiKey: String) { self.apiKey = apiKey }

    func attach(session: ARSession) {
        arSession = session
        do {
            let gar = try GARSession(apiKey: apiKey, bundleIdentifier: nil)
            guard gar.isGeospatialModeSupported(.enabled) else { quality = .unavailable; return }
            let config = GARSessionConfiguration()
            config.geospatialMode = .enabled
            var error: NSError?
            gar.setConfiguration(config, error: &error)
            if error == nil { garSession = gar }
        } catch {
            garSession = nil
        }
    }

    func detach() {
        garSession = nil
        arSession = nil
        lastEarth = nil
        quality = .unavailable
    }

    func update(cameraTransform: simd_float4x4, trackingState: ARCamera.TrackingState, timestamp: TimeInterval) {
        // Frames are forwarded by `GeoAnchorManager.forward(frame:)` because this hook only has the transform.
    }

    /// Call with the live ARFrame (not retained beyond this call).
    func forward(frame: ARFrame) {
        guard let garSession, let garFrame = try? garSession.update(frame) else { return }
        guard let earth = garFrame.earth, earth.trackingState == .tracking, let t = earth.cameraGeospatialTransform else {
            quality = .unavailable
            return
        }
        lastEarth = earth
        pose = GeoPose(
            coordinate: GeoCoordinate(latitude: t.coordinate.latitude, longitude: t.coordinate.longitude),
            horizontalAccuracy: t.horizontalAccuracy,
            heading: t.heading,
            headingAccuracy: t.headingAccuracy,
            timestamp: Date()
        )
        quality = t.horizontalAccuracy <= 5 && t.headingAccuracy <= 10 ? .good : (t.horizontalAccuracy <= 15 ? .fair : .poor)
    }

    func update(location: LocationSample?, heading: HeadingSample?) {
        // ARCore computes its own pose; Core Location is only used by ARCore internally.
    }

    func worldPosition(for coordinate: GeoCoordinate, heightBelowCamera: Float) -> SIMD3<Float>? {
        guard let garSession, let earth = lastEarth, earth.trackingState == .tracking, let t = earth.cameraGeospatialTransform else { return nil }
        // Terrain/rooftop anchors would be preferable; a plain geospatial anchor at camera altitude is the MVP path.
        let anchor = try? garSession.createAnchor(
            coordinate: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude),
            altitude: t.altitude - Double(heightBelowCamera),
            eastUpSouthQAnchor: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        )
        return anchor?.transform.translation
    }

    func worldDirection(forBearing bearing: Double) -> SIMD3<Float>? {
        guard let earth = lastEarth, let t = earth.cameraGeospatialTransform, let arSession, let frame = arSession.currentFrame else { return nil }
        // Rotate ARKit forward by the difference between true heading and camera yaw.
        let cam = frame.camera.transform
        let forward = -SIMD3<Float>(cam.columns.2.x, 0, cam.columns.2.z)
        let cameraYaw = atan2(forward.x, -forward.z)
        let yawToNorth = Float(t.heading * .pi / 180) - cameraYaw
        let θ = Float(bearing * .pi / 180) - yawToNorth
        return SIMD3<Float>(sin(θ), 0, -cos(θ))
    }
}
#else
/// Placeholder so the type exists in every build. Enable the ARCore package to use the real one.
@MainActor
final class ARCoreGeoSpatialProvider: GeoSpatialProvider {
    let displayName = "ARCore Geospatial (not linked)"
    let quality: GeoLocalizationQuality = .unavailable
    let pose: GeoPose? = nil
    let preferredWorldAlignment: ARConfiguration.WorldAlignment = .gravity
    init(apiKey: String) {}
    func attach(session: ARSession) {}
    func detach() {}
    func update(cameraTransform: simd_float4x4, trackingState: ARCamera.TrackingState, timestamp: TimeInterval) {}
    func update(location: LocationSample?, heading: HeadingSample?) {}
    func worldPosition(for coordinate: GeoCoordinate, heightBelowCamera: Float) -> SIMD3<Float>? { nil }
    func worldDirection(forBearing bearing: Double) -> SIMD3<Float>? { nil }
}
#endif

extension simd_float4x4 {
    var translation: SIMD3<Float> {
        SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
}
