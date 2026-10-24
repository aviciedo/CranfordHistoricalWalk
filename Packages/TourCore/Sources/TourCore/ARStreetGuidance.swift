import Foundation

/// Route and world-space placement policy shared by native AR and portable regression tests.
public enum ARStreetGuidance {
    public static let lookAheadMeters = 8.0
    public static let minimumClearanceMeters = 0.16
    public static let chevronScale = 1.1

    public static let repositionDistanceMeters = 5.0
    public static let instructionSettleSeconds = 1.5

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

    /// A road-sign instruction, independent of phone heading and fine-grained polyline segments.
    public struct Instruction: Equatable, Sendable {
        public var direction: ARWalkingGuidance.Direction
        public var streetName: String?
        public init(direction: ARWalkingGuidance.Direction, streetName: String?) {
            self.direction = direction
            let trimmed = streetName?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.streetName = trimmed?.isEmpty == false ? trimmed : nil
        }
    }

    public struct Placement: Equatable, Sendable {
        public let position: SIMD3<Double>
        public let facingYawRadians: Double
        public let instruction: Instruction
    }

    public struct AnchorState: Sendable {
        public private(set) var placement: Placement?
        public var position: SIMD3<Double>? { placement?.position }
        private var placementCamera: SIMD2<Double>?
        private var pendingInstruction: Instruction?
        private var pendingSince: TimeInterval?
        private var lastTimestamp: TimeInterval?

        public init() {}
        public mutating func reset() { self = AnchorState() }

        /// Pin the ENTIRE pose: position, yaw, arrow direction and label. AR camera translation
        /// (not GPS jitter or camera rotation) authorizes a new placement after about five metres.
        /// A changed route instruction must persist before it can replace the fixed sign.
        public mutating func update(candidate: SIMD3<Double>, camera: SIMD3<Double>,
                                    instruction: Instruction, timestamp: TimeInterval) -> Placement? {
            let values = [candidate.x, candidate.y, candidate.z, camera.x, camera.y, camera.z, timestamp]
            guard values.allSatisfy(\.isFinite) else { return nil }
            if let lastTimestamp, timestamp < lastTimestamp { return placement }
            if let lastTimestamp, timestamp - lastTimestamp > 1 {
                pendingInstruction = nil; pendingSince = nil
            }
            let isNewFrame = lastTimestamp.map { timestamp > $0 } ?? true
            lastTimestamp = timestamp
            let cameraXZ = SIMD2(camera.x, camera.z)
            var chosen = instruction
            if let placement, let placementCamera {
                var instructionChanged = false
                if placement.instruction == instruction {
                    pendingInstruction = nil; pendingSince = nil
                } else if pendingInstruction != instruction {
                    pendingInstruction = instruction; pendingSince = timestamp
                } else if isNewFrame, let since = pendingSince,
                          timestamp - since >= ARStreetGuidance.instructionSettleSeconds {
                    instructionChanged = true
                }
                let movement = hypot(cameraXZ.x - placementCamera.x, cameraXZ.y - placementCamera.y)
                // Do not briefly install an unconfirmed instruction while walking across a GPS boundary.
                if pendingInstruction != nil && !instructionChanged { return placement }
                guard movement >= ARStreetGuidance.repositionDistanceMeters || instructionChanged else {
                    return placement
                }
                chosen = instructionChanged ? instruction : placement.instruction
            }
            let range = hypot(candidate.x - camera.x, candidate.z - camera.z)
            // Keep a large sign clear of the camera. An invalid replacement leaves the old pose pinned.
            guard range >= 3, range <= 14 else { return placement }
            let yaw = atan2(camera.x - candidate.x, camera.z - candidate.z)
            let next = Placement(position: candidate, facingYawRadians: yaw, instruction: chosen)
            placement = next
            placementCamera = cameraXZ
            pendingInstruction = nil; pendingSince = nil
            return next
        }
    }
}
