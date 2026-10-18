import ARKit
import CoreLocation
import Foundation
import simd
import TourCore

struct GeoPose: Equatable, Sendable {
    var coordinate: GeoCoordinate
    var horizontalAccuracy: Double
    /// True heading in degrees when known (0 = north, clockwise).
    var heading: Double?
    var headingAccuracy: Double?
    /// WGS84 ellipsoid meters when known (Geospatial / ellipsoidalAltitude).
    var altitude: Double?
    var timestamp: Date
}

/// Converts geographic coordinates into AR world-space positions.
///
/// `CoreLocationGeoSpatialProvider` is GPS + compass + ARKit. `ARCoreGeoSpatialProvider` is Google's
/// Geospatial API (VPS + GPS). `GeoAnchorManager` and the views talk only to this protocol.
@MainActor
protocol GeoSpatialProvider: AnyObject {
    var displayName: String { get }
    var backend: GeoSpatialBackend { get }
    var quality: GeoLocalizationQuality { get }
    var pose: GeoPose? { get }
    var preferredWorldAlignment: ARConfiguration.WorldAlignment { get }
    var fallbackReason: GeoSpatialFallbackReason? { get }
    var vpsCoverage: VPSCoverage { get }

    func attach(session: ARSession)
    func detach()

    /// Per-frame hook (already throttled by the caller). `cameraTransform` is ARKit world space.
    func update(cameraTransform: simd_float4x4, trackingState: ARCamera.TrackingState, timestamp: TimeInterval)
    /// Live `ARFrame` (not retained). ARCore Geospatial requires `-[GARSession update:error:]`.
    func update(frame: ARFrame)
    /// Fed from the app's single location source. ARCore does not start a second location manager.
    func update(location: LocationSample?, heading: HeadingSample?)

    /// World-space position for a geographic coordinate.
    /// `altitude` is WGS84 ellipsoid meters when known; `nil` means “camera height minus `heightBelowCamera`”.
    func worldPosition(for coordinate: GeoCoordinate, altitude: Double?, heightBelowCamera: Float) -> SIMD3<Float>?
    func worldDirection(forBearing bearing: Double) -> SIMD3<Float>?
}

extension GeoSpatialProvider {
    var statusNotice: String? {
        if let fallbackReason { return fallbackReason.userMessage }
        if let vps = vpsCoverage.userMessage { return vps }
        return nil
    }
}

// MARK: - Core Location + ARKit implementation

/// Uses ARKit's `.gravityAndHeading` alignment (−Z = true north, +X = east) so that a compass bearing
/// maps directly onto world axes, then offsets from the most recent (GPS fix, camera position) pair.
@MainActor
final class CoreLocationGeoSpatialProvider: GeoSpatialProvider {
    let displayName = "GPS + compass (Core Location)"
    let backend: GeoSpatialBackend = .coreLocation
    private(set) var quality: GeoLocalizationQuality = .unavailable
    private(set) var pose: GeoPose?
    let preferredWorldAlignment: ARConfiguration.WorldAlignment
    private(set) var fallbackReason: GeoSpatialFallbackReason?
    let vpsCoverage: VPSCoverage = .unknown

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

    init(hasCompass: Bool = CLLocationManager.headingAvailable(), fallbackReason: GeoSpatialFallbackReason? = nil) {
        preferredWorldAlignment = hasCompass ? .gravityAndHeading : .gravity
        self.fallbackReason = fallbackReason
    }

    func attach(session: ARSession) {
        self.session = session
        reference = nil
        cameraTransform = nil
        trackingState = .notAvailable
        yawToNorth = nil
        pose = nil
        pendingLocation = nil
        recomputeQuality()
    }

    func detach() {
        session = nil
        cameraTransform = nil
        reference = nil
        pose = nil
        pendingLocation = nil
        yawToNorth = nil
        quality = .unavailable
    }

    func update(frame: ARFrame) {}

    func update(cameraTransform: simd_float4x4, trackingState: ARCamera.TrackingState, timestamp: TimeInterval) {
        self.cameraTransform = cameraTransform
        self.trackingState = trackingState
        if case .normal = trackingState, let location = pendingLocation {
            pendingLocation = nil
            bind(location: location, cameraPosition: cameraTransform.translation)
        }
        if preferredWorldAlignment == .gravity, let heading = latestHeading, heading.isReliable {
            let forward = -SIMD3<Float>(cameraTransform.columns.2.x, 0, cameraTransform.columns.2.z)
            if simd_length(forward) > 0.2 {
                let cameraYaw = atan2(forward.x, -forward.z)
                let trueYaw = Float(heading.bestHeading * .pi / 180)
                yawToNorth = trueYaw - cameraYaw
            }
        }
        recomputeQuality()
    }

    func update(location: LocationSample?, heading: HeadingSample?) {
        latestHeading = heading
        guard let location, location.horizontalAccuracy >= 0 else { return }
        // Heading and tour-state updates can replay the same GPS sample. Rebinding
        // that old coordinate to a new camera position makes world content drift.
        if pose?.timestamp != location.timestamp || pose?.coordinate != location.coordinate {
            if let cameraTransform, case .normal = trackingState {
                bind(location: location, cameraPosition: cameraTransform.translation)
            } else {
                pendingLocation = location
            }
        }
        pose = GeoPose(
            coordinate: location.coordinate,
            horizontalAccuracy: location.horizontalAccuracy,
            heading: heading?.bestHeading,
            headingAccuracy: heading?.accuracy,
            altitude: location.altitude,
            timestamp: location.timestamp
        )
        recomputeQuality()
    }

    private func bind(location: LocationSample, cameraPosition: SIMD3<Float>) {
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

    func worldPosition(for coordinate: GeoCoordinate, altitude: Double?, heightBelowCamera: Float) -> SIMD3<Float>? {
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
        guard StopActivationPolicy.isFresh(pose.timestamp), pose.coordinate.isValid,
              pose.horizontalAccuracy.isFinite, latestHeading?.isReliable == true else {
            quality = .unavailable
            return
        }
        guard case .normal = trackingState, reference != nil else { quality = .unavailable; return }
        if preferredWorldAlignment == .gravity && yawToNorth == nil { quality = .unavailable; return }
        quality = GeoSpatialSelector.quality(horizontalAccuracy: pose.horizontalAccuracy, yawAccuracy: pose.headingAccuracy ?? -1)
    }
}

// MARK: - ARCore Geospatial

#if canImport(ARCoreGeospatial)
import ARCoreGeospatial

/// Google ARCore Geospatial API. Official selectors (do not invent replacements):
/// `+[GARSession sessionWithAPIKey:bundleIdentifier:error:]`
/// `-[GARSession isGeospatialModeSupported:]` (`GARGeospatialModeEnabled`)
/// `GARSessionConfiguration.geospatialMode`
/// `-[GARSession setConfiguration:error:]`
/// `-[GARSession update:error:]`
/// `GAREarth.cameraGeospatialTransform` / `trackingState` / `earthState`
/// `-[GARSession transformFromGeospatialCoordinate:altitude:eastUpSouthQTarget:error:]`
/// `-[GARSession checkVPSAvailabilityAtCoordinate:completionHandler:]`
/// Heading from `eastUpSouthQTarget` (`heading` is deprecated).
@MainActor
final class ARCoreGeoSpatialProvider: GeoSpatialProvider {
    let displayName = "ARCore Geospatial (VPS)"
    let backend: GeoSpatialBackend = .arCoreGeospatial
    private(set) var quality: GeoLocalizationQuality = .unavailable
    private(set) var pose: GeoPose?
    let preferredWorldAlignment: ARConfiguration.WorldAlignment = .gravity
    private(set) var fallbackReason: GeoSpatialFallbackReason?
    private(set) var vpsCoverage: VPSCoverage = .unknown

    private let apiKey: String
    private var garSession: GARSession?
    private var arSession: ARSession?
    private var lastAltitude: Double?
    private var lastHeading: Double?
    private var lastVPSCheck: Date?
    private var lastVPSCoordinate: GeoCoordinate?

    init(apiKey: String) { self.apiKey = apiKey }

    func attach(session: ARSession) {
        arSession = session
        fallbackReason = nil
        quality = .unavailable
        pose = nil
        do {
            // Official: +[GARSession sessionWithAPIKey:bundleIdentifier:error:]
            let gar = try GARSession(apiKey: apiKey, bundleIdentifier: AppConfiguration.iosBundleIdentifier())
            // Official: -[GARSession isGeospatialModeSupported:]
            guard gar.isGeospatialModeSupported(.enabled) else {
                fallbackReason = .deviceUnsupported
                garSession = nil
                return
            }
            let config = GARSessionConfiguration()
            config.geospatialMode = .enabled
            var error: NSError?
            // Official: -[GARSession setConfiguration:error:]
            gar.setConfiguration(config, error: &error)
            if error != nil {
                fallbackReason = .sessionConfigurationFailed
                garSession = nil
                return
            }
            garSession = gar
        } catch {
            fallbackReason = .sessionConfigurationFailed
            garSession = nil
        }
    }

    func detach() {
        garSession = nil
        arSession = nil
        lastAltitude = nil
        quality = .unavailable
        pose = nil
    }

    func update(cameraTransform: simd_float4x4, trackingState: ARCamera.TrackingState, timestamp: TimeInterval) {}

    func update(frame: ARFrame) {
        guard let garSession else { return }
        let garFrame: GARFrame
        do {
            // Official: -[GARSession update:error:]
            garFrame = try garSession.update(frame)
        } catch {
            return
        }
        // Do not retain `garFrame` / `earth` beyond this call.
        guard let earth = garFrame.earth else {
            quality = .unavailable
            return
        }
        if let reason = GeoSpatialSelector.fallbackReason(fromEarthStateCode: earth.earthState.rawValue) {
            fallbackReason = reason
            quality = .unavailable
            pose = nil
            return
        }
        guard earth.trackingState == .tracking, let transform = earth.cameraGeospatialTransform else {
            quality = .unavailable
            return
        }
        let heading = ARCoreGeoSpatialProvider.headingDegrees(eastUpSouthQTarget: transform.eastUpSouthQTarget)
        lastAltitude = transform.altitude
        lastHeading = heading
        pose = GeoPose(
            coordinate: GeoCoordinate(latitude: transform.coordinate.latitude, longitude: transform.coordinate.longitude),
            horizontalAccuracy: transform.horizontalAccuracy,
            heading: heading,
            headingAccuracy: transform.orientationYawAccuracy,
            altitude: transform.altitude,
            timestamp: Date()
        )
        quality = GeoSpatialSelector.quality(
            horizontalAccuracy: transform.horizontalAccuracy,
            yawAccuracy: transform.orientationYawAccuracy
        )
        maybeCheckVPS(at: pose?.coordinate)
    }

    func update(location: LocationSample?, heading: HeadingSample?) {
        // Location still comes from TourViewModel → LocationService. ARCore consumes camera frames
        // for the geospatial pose; we do not start another CLLocationManager.
        if pose == nil, let location {
            maybeCheckVPS(at: location.coordinate)
        }
    }

    func worldPosition(for coordinate: GeoCoordinate, altitude: Double?, heightBelowCamera: Float) -> SIMD3<Float>? {
        guard let garSession, quality != .unavailable, let lastAltitude else { return nil }
        let ellipsoidAltitude = altitude ?? (lastAltitude - Double(heightBelowCamera))
        // Official: -[GARSession transformFromGeospatialCoordinate:altitude:eastUpSouthQTarget:error:]
        // Identity EUS: +X east, +Y up, +Z south. RealityKit yaws the sign toward the user separately.
        guard let matrix = try? garSession.transform(
            coordinate: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude),
            altitude: ellipsoidAltitude,
            eastUpSouthQTarget: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        ) else { return nil }
        return matrix.translation
    }

    func worldDirection(forBearing bearing: Double) -> SIMD3<Float>? {
        guard let lastHeading, let arSession, let frame = arSession.currentFrame else { return nil }
        let cam = frame.camera.transform
        let forward = -SIMD3<Float>(cam.columns.2.x, 0, cam.columns.2.z)
        guard simd_length(forward) > 0.1 else { return nil }
        let cameraYaw = atan2(forward.x, -forward.z)
        let yawToNorth = Float(lastHeading * .pi / 180) - cameraYaw
        let θ = Float(bearing * .pi / 180) - yawToNorth
        return SIMD3<Float>(sin(θ), 0, -cos(θ))
    }

    /// Yaw analogous to compass heading: identity EUS looks north (camera −Z = −south).
    static func headingDegrees(eastUpSouthQTarget q: simd_quatf) -> Double {
        let forwardEUS = simd_act(q, SIMD3<Float>(0, 0, -1))
        return GeoMath.normalizeBearing(Double(atan2(forwardEUS.x, -forwardEUS.z) * 180 / .pi))
    }

    private func maybeCheckVPS(at coordinate: GeoCoordinate?) {
        guard let garSession, let coordinate else { return }
        if let lastVPSCheck, Date().timeIntervalSince(lastVPSCheck) < 30 { return }
        if let lastVPSCoordinate, GeoMath.distance(from: lastVPSCoordinate, to: coordinate) < 150, lastVPSCheck != nil {
            return
        }
        lastVPSCheck = Date()
        lastVPSCoordinate = coordinate
        // Official: -[GARSession checkVPSAvailabilityAtCoordinate:completionHandler:]
        _ = garSession.checkVPSAvailability(
            coordinate: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
        ) { [weak self] availability in
            MainActor.assumeIsolated {
                self?.vpsCoverage = GeoSpatialSelector.coverage(fromVPSAvailabilityCode: Int(availability.rawValue))
            }
        }
    }
}
#else
/// Compiled on Linux and any Mac build that has not resolved the ARCore package.
@MainActor
final class ARCoreGeoSpatialProvider: GeoSpatialProvider {
    let displayName = "ARCore Geospatial (not linked)"
    let backend: GeoSpatialBackend = .arCoreGeospatial
    let quality: GeoLocalizationQuality = .unavailable
    let pose: GeoPose? = nil
    let preferredWorldAlignment: ARConfiguration.WorldAlignment = .gravity
    let fallbackReason: GeoSpatialFallbackReason? = .sdkNotLinked
    let vpsCoverage: VPSCoverage = .unknown
    init(apiKey: String) {}
    func attach(session: ARSession) {}
    func detach() {}
    func update(cameraTransform: simd_float4x4, trackingState: ARCamera.TrackingState, timestamp: TimeInterval) {}
    func update(frame: ARFrame) {}
    func update(location: LocationSample?, heading: HeadingSample?) {}
    func worldPosition(for coordinate: GeoCoordinate, altitude: Double?, heightBelowCamera: Float) -> SIMD3<Float>? { nil }
    func worldDirection(forBearing bearing: Double) -> SIMD3<Float>? { nil }
}
#endif

extension simd_float4x4 {
    var translation: SIMD3<Float> {
        SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
}
