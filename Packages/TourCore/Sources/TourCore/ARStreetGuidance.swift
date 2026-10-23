import Foundation

/// Route and world-space placement policy shared by native AR and portable regression tests.
public enum ARStreetGuidance {
    public static let lookAheadMeters = 6.0
    public static let centerAboveGroundMeters = 0.9
    public static let chevronScale = 0.5

    /// Stay on the current segment: a short preview must never cut across a corner.
    public static func routePoint(route: WalkingRoute, progress: RouteProgress) -> GeoCoordinate? {
        guard route.source != .straightLineEstimate, progress.snappedCoordinate.isValid,
              progress.distanceFromRoute.isFinite, (0...35).contains(progress.distanceFromRoute),
              route.routeCoordinates.indices.contains(progress.segmentIndex),
              progress.segmentIndex < route.routeCoordinates.count - 1 else { return nil }
        let end = route.routeCoordinates[progress.segmentIndex + 1]
        guard end.isValid else { return nil }
        let distance = GeoMath.distance(from: progress.snappedCoordinate, to: end)
        guard distance.isFinite, distance > 0.1 else { return end }
        return GeoMath.destination(from: progress.snappedCoordinate,
                                   bearing: GeoMath.bearing(from: progress.snappedCoordinate, to: end),
                                   distance: min(lookAheadMeters, distance))
    }

    public struct AnchorState: Sendable {
        public private(set) var position: SIMD3<Double>?
        private var heading: SIMD2<Double>?
        private var segment: Int?

        public init() {}
        public mutating func reset() { position = nil; heading = nil; segment = nil }

        /// Keep a WORLD position while the phone moves. Recycle only after approaching/passing
        /// it, a meaningful route change, or a requested relayout; never chase every GPS fix.
        public mutating func update(candidate: SIMD3<Double>, camera: SIMD3<Double>,
                                    direction: SIMD2<Double>, segment: Int, force: Bool = false) -> SIMD3<Double>? {
            let values = [candidate.x, candidate.y, candidate.z, camera.x, camera.y, camera.z, direction.x, direction.y]
            let length = hypot(direction.x, direction.y)
            guard values.allSatisfy(\.isFinite), length.isFinite, length > 0.001 else { reset(); return nil }
            let unit = direction / length
            if let position, let heading, self.segment == segment, !force {
                let delta = SIMD2(position.x - camera.x, position.z - camera.z)
                let range = hypot(delta.x, delta.y)
                let ahead = delta.x * unit.x + delta.y * unit.y
                let similarity = heading.x * unit.x + heading.y * unit.y
                if range >= 2.4, range <= 14, ahead > 1.2, similarity > cos(35 * Double.pi / 180) {
                    return position
                }
            }
            let range = hypot(candidate.x - camera.x, candidate.z - camera.z)
            guard range >= 3, range <= 14 else { reset(); return nil }
            position = candidate
            heading = unit
            self.segment = segment
            return candidate
        }
    }
}
