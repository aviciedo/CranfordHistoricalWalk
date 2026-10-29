import Foundation

/// WGS84 ECEF → local east/north/up; ARKit north-aligned axes are east/up/south.
public struct WGS84LocalFrame: Sendable {
    public let origin: GeoCoordinate
    public let altitude: Double
    public init(origin: GeoCoordinate, altitude: Double = 0) { self.origin = origin; self.altitude = altitude }
    private func ecef(_ p: GeoCoordinate, _ height: Double) -> SIMD3<Double> {
        let lat = p.latitude * .pi / 180, lon = p.longitude * .pi / 180
        let a = 6_378_137.0, e2 = 6.69437999014e-3
        let n = a / sqrt(1 - e2 * sin(lat) * sin(lat))
        return [(n + height) * cos(lat) * cos(lon), (n + height) * cos(lat) * sin(lon), (n * (1 - e2) + height) * sin(lat)]
    }
    public func eastNorthUp(_ p: GeoCoordinate, altitude height: Double = 0) -> SIMD3<Double>? {
        guard origin.isValid, p.isValid, altitude.isFinite, height.isFinite else { return nil }
        let d = ecef(p, height) - ecef(origin, altitude)
        let lat = origin.latitude * .pi / 180, lon = origin.longitude * .pi / 180
        let slon = sin(lon), clon = cos(lon), slat = sin(lat), clat = cos(lat)
        let east: Double = -slon * d.x + clon * d.y
        let horizontal: Double = clon * d.x + slon * d.y
        let north: Double = -slat * horizontal + clat * d.z
        let up: Double = clat * horizontal + slat * d.z
        return SIMD3<Double>(east, north, up)
    }
    public func arOffset(_ p: GeoCoordinate) -> SIMD3<Double>? {
        guard let enu = eastNorthUp(p, altitude: altitude) else { return nil }
        return [enu.x, enu.z, -enu.y]
    }
}

/// Matches delayed GPS timestamps to AR translation without retaining ARFrames.
public struct ARCameraPositionHistory: Sendable {
    private var samples: [(Date, SIMD3<Double>)] = []
    public init() {}
    public mutating func append(_ position: SIMD3<Double>, at date: Date) {
        guard [position.x, position.y, position.z].allSatisfy(\.isFinite),
              samples.last.map({ date > $0.0 }) ?? true else { return }
        samples.append((date, position))
        if samples.count > 100 { samples.removeFirst(samples.count - 100) }
    }
    public func position(at date: Date) -> SIMD3<Double>? {
        guard let first = samples.first, let last = samples.last else { return nil }
        if date < first.0 { return first.0.timeIntervalSince(date) <= 0.25 ? first.1 : nil }
        if date >= last.0 { return date.timeIntervalSince(last.0) <= 0.25 ? last.1 : nil }
        for index in 1..<samples.count where samples[index].0 >= date {
            let a = samples[index - 1], b = samples[index]
            let duration = b.0.timeIntervalSince(a.0)
            guard duration <= 0.5 else { return nil }
            return a.1 + (b.1 - a.1) * (date.timeIntervalSince(a.0) / duration)
        }
        return nil
    }
}

/// Stable geographic origin plus bounded translation corrections, never a new origin per fix.
public struct ARGeographicAlignment: Sendable {
    private var frame: WGS84LocalFrame?
    private var translation = SIMD3<Double>.zero
    private var lastTimestamp: Date?
    private var courseReference: SIMD3<Double>?
    private var courseCoordinate: GeoCoordinate?
    public private(set) var isConsistent = false
    public private(set) var residualError = 0.0
    public init() {}
    public mutating func reset() { self = Self() }
    public mutating func update(coordinate: GeoCoordinate, camera: SIMD3<Double>, accuracy: Double, timestamp: Date, course: Double? = nil, speed: Double? = nil) {
        guard coordinate.isValid, accuracy.isFinite, (0...8).contains(accuracy),
              [camera.x, camera.y, camera.z].allSatisfy(\.isFinite),
              lastTimestamp.map({ timestamp > $0 }) ?? true else { return }
        lastTimestamp = timestamp
        if frame == nil { frame = WGS84LocalFrame(origin: coordinate); translation = camera; courseReference = camera; courseCoordinate = coordinate; isConsistent = true; return }
        guard let offset = frame?.arOffset(coordinate) else { isConsistent = false; return }
        // Walking course validates north against AR translation; it is never camera heading.
        if let courseReference, let courseCoordinate, let course, let speed,
           course.isFinite, (0..<360).contains(course), (0.7...3).contains(speed),
           hypot(camera.x - courseReference.x, camera.z - courseReference.z) >= max(8, accuracy * 3),
           GeoMath.distance(from: courseCoordinate, to: coordinate) >= max(8, accuracy * 3) {
            let worldCourse = GeoMath.normalizeBearing(atan2(camera.x - courseReference.x, -(camera.z - courseReference.z)) * 180 / .pi)
            // Compare the same interval on both sensors. Instantaneous course at a turn
            // is not the bearing of a several-metre VIO trajectory.
            let geographicCourse = GeoMath.bearing(from: courseCoordinate, to: coordinate)
            guard abs(GeoMath.relativeBearing(heading: worldCourse, bearing: geographicCourse)) <= 25 else { isConsistent = false; return }
            self.courseReference = camera
            self.courseCoordinate = coordinate
        }
        let desired = camera - offset
        let error = SIMD2(desired.x - translation.x, desired.z - translation.z)
        let length = hypot(error.x, error.y)
        residualError = length
        // A GPS jump cannot silently move the whole street. Require recovery at the stable frame.
        guard length <= max(6, accuracy * 2) else { isConsistent = false; return }
        let fraction = length > 0 ? min(0.12, 0.25 / length) : 0
        translation.x += error.x * fraction; translation.z += error.y * fraction
        isConsistent = true
    }
    public func position(for coordinate: GeoCoordinate) -> SIMD3<Double>? {
        guard isConsistent, let offset = frame?.arOffset(coordinate) else { return nil }
        return translation + offset
    }
}

/// Geometry selection uses the same route/progress as the map. Never cuts across a sharp turn.
public enum ARRoutePlacementEngine {
    public struct Preview: Equatable, Sendable {
        public let coordinate: GeoCoordinate
        public let bearing: Double
        public let segmentIndex: Int
        public let distanceAhead: Double
    }
    public static func preview(route: WalkingRoute, progress: RouteProgress, speed: Double? = nil) -> Preview? {
        guard route.source != .straightLineEstimate, route.source != .simulated,
              progress.distanceFromRoute.isFinite, (0...8).contains(progress.distanceFromRoute),
              progress.snappedCoordinate.isValid, route.routeCoordinates.count >= 2,
              route.routeCoordinates.allSatisfy(\.isValid),
              route.routeCoordinates.indices.contains(progress.segmentIndex),
              route.routeCoordinates.indices.contains(progress.segmentIndex + 1) else { return nil }
        let desired = min(10, max(5, 5 + (speed.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil } ?? 1) * 2))
        var point = progress.snappedCoordinate, remaining = desired, covered = 0.0
        var previousBearing: Double?
        for index in progress.segmentIndex..<(route.routeCoordinates.count - 1) {
            let end = route.routeCoordinates[index + 1]
            let length = GeoMath.distance(from: point, to: end)
            if length < 0.1 { point = end; continue }
            let bearing = GeoMath.bearing(from: point, to: end)
            if let previousBearing, abs(GeoMath.relativeBearing(heading: previousBearing, bearing: bearing)) > 25 { return nil }
            let next = index + 2 < route.routeCoordinates.count ? route.routeCoordinates[index + 2] : nil
            let sharpCorner = next.map { abs(GeoMath.relativeBearing(heading: bearing, bearing: GeoMath.bearing(from: end, to: $0))) > 25 } ?? true
            let safeLength = sharpCorner ? max(0, length - 1) : length
            if remaining <= safeLength || sharpCorner {
                let step = min(remaining, safeLength)
                guard covered + step >= 3 else { return nil }
                return Preview(coordinate: GeoMath.destination(from: point, bearing: bearing, distance: step),
                               bearing: bearing, segmentIndex: index, distanceAhead: covered + step)
            }
            remaining -= length; covered += length; point = end; previousBearing = bearing
        }
        return nil
    }
}

/// Tight spatial thresholds, wider retention thresholds, delayed acquisition and immediate hard loss.
public struct ARSpatialConfidence: Sendable {
    public enum Reason: String, Equatable, Sendable { case tracking, location, heading, offRoute, route, alignment }
    public enum Mode: Equatable, Sendable { case aligning, spatial, degraded(Reason) }
    public private(set) var mode: Mode = .aligning
    private var goodSince: TimeInterval?
    private var lastTime: TimeInterval?
    public init() {}
    public mutating func reset() { self = Self() }
    public mutating func update(tracking: Bool, locationAge: Double, accuracy: Double, yawAccuracy: Double,
                                routeOffset: Double, hasPreview: Bool, alignment: Bool, timestamp: TimeInterval) -> Mode {
        guard timestamp.isFinite, lastTime.map({ timestamp >= $0 }) ?? true else { return mode }
        if let lastTime, timestamp - lastTime > 1 { goodSince = nil; mode = .aligning }
        lastTime = timestamp
        let retaining = mode == .spatial
        let reason: Reason?
        if !tracking { reason = .tracking }
        else if !locationAge.isFinite || !(-1...5).contains(locationAge) || !accuracy.isFinite || accuracy < 0 || accuracy > (retaining ? 8 : 5) { reason = .location }
        else if !yawAccuracy.isFinite || yawAccuracy < 0 || yawAccuracy > (retaining ? 15 : 10) { reason = .heading }
        else if !routeOffset.isFinite || routeOffset < 0 || routeOffset > (retaining ? 5 : 3) { reason = .offRoute }
        else if !hasPreview { reason = .route }
        else if !alignment { reason = .alignment }
        else { reason = nil }
        if let reason { goodSince = nil; mode = .degraded(reason); return mode }
        if retaining { return mode }
        if goodSince == nil { goodSince = timestamp }
        mode = timestamp - (goodSince ?? timestamp) >= 2 ? .spatial : .aligning
        return mode
    }
}

/// Pins a route-oriented pose. Camera yaw is deliberately absent from the API.
public struct ARWorldPlacementState: Sendable {
    public struct Pose: Equatable, Sendable {
        public let position: SIMD3<Double>
        public let yaw: Double
        public let direction: ARWalkingGuidance.Direction
        public let segment: Int
    }
    public private(set) var pose: Pose?
    private var placedCamera: SIMD3<Double>?
    private var pendingSegment: Int?
    private var pendingDirection: ARWalkingGuidance.Direction?
    private var pendingSince: TimeInterval?
    private var lastTime: TimeInterval?
    public init() {}
    public mutating func reset() { self = Self() }
    public mutating func update(position: SIMD3<Double>, routeYaw: Double, direction: ARWalkingGuidance.Direction,
                                segment: Int, camera: SIMD3<Double>, timestamp: TimeInterval) -> Pose? {
        guard [position.x, position.y, position.z, routeYaw, camera.x, camera.y, camera.z, timestamp].allSatisfy(\.isFinite),
              lastTime.map({ timestamp >= $0 }) ?? true else { return pose }
        if let lastTime, timestamp - lastTime > 1 { pendingSince = nil; pendingSegment = nil }
        lastTime = timestamp
        if let pose, let placedCamera {
            let moving = hypot(camera.x - placedCamera.x, camera.z - placedCamera.z) >= 3
            let approaching = hypot(camera.x - pose.position.x, camera.z - pose.position.z) < 3
            let changed = pose.segment != segment || pose.direction != direction
            if changed {
                if pendingSegment != segment || pendingDirection != direction || pendingSince == nil {
                    pendingSegment = segment; pendingDirection = direction; pendingSince = timestamp
                }
                guard timestamp - (pendingSince ?? timestamp) >= 1 else { return pose }
            } else { pendingSegment = nil; pendingSince = nil }
            guard changed || moving || approaching else { return pose }
        }
        let range = hypot(position.x - camera.x, position.z - camera.z)
        guard (2.5...16).contains(range) else { return pose }
        let next = Pose(position: position, yaw: routeYaw, direction: direction, segment: segment)
        pose = next; placedCamera = camera; pendingSegment = nil; pendingSince = nil
        return next
    }
}
