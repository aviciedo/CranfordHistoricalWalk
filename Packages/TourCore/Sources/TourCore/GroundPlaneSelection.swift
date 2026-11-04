import Foundation

/// Detected-surface classes that can affect arrow height. Table, seat, and ceiling never
/// become the walking surface. Only a classified floor is treated as verified ground.
public enum GroundSurfaceKind: String, Equatable, Sendable {
    case none, wall, floor, ceiling, table, seat, window, door, unknown
}

/// Shared filter for ARKit plane anchors and raycast hits. Callers still own the camera
/// frame; this only decides which measured height may move a route arrow.
public enum GroundPlaneSelection {
    public static let minimumArea: Float = 0.5
    public static let minimumClearanceBelowCamera: Float = 0.45
    public static let maximumClearanceBelowCamera: Float = 2.5
    public static let maximumHorizontalDistance: Float = 8
    public static let heightSmoothing: Float = 0.12
    public static let raycastHeightTolerance: Float = 0.6

    public struct Observation: Equatable, Sendable {
        public var center: SIMD3<Float>
        public var area: Float
        public var isHorizontal: Bool
        public var classification: GroundSurfaceKind
        /// Horizontal distance already measured by the caller, so device code can keep
        /// `simd_length` and tests can supply the same cutoff without ARKit.
        public var horizontalDistance: Float

        public init(center: SIMD3<Float>, area: Float, isHorizontal: Bool, classification: GroundSurfaceKind,
                    horizontalDistance: Float) {
            self.center = center
            self.area = area
            self.isHorizontal = isHorizontal
            self.classification = classification
            self.horizontalDistance = horizontalDistance
        }
    }

    public struct RaycastChoice: Equatable, Sendable {
        public var height: Float
        public var isVerifiedFloor: Bool

        public init(height: Float, isVerifiedFloor: Bool) {
            self.height = height
            self.isVerifiedFloor = isVerifiedFloor
        }
    }

    /// The nearest eligible plane. An equal horizontal distance keeps the earlier sample.
    public static func chosenCenter(_ planes: [Observation], cameraY: Float) -> SIMD3<Float>? {
        var chosen: SIMD3<Float>?
        var best = Float.greatestFiniteMagnitude
        for plane in planes where accepts(plane, cameraY: cameraY) {
            if chosen == nil || plane.horizontalDistance < best {
                chosen = plane.center
                best = plane.horizontalDistance
            }
        }
        return chosen
    }

    /// The first sample is used as-is. Later samples move 12% of the way toward the measurement.
    public static func updatedHeight(previous: Float?, measuredY: Float) -> Float {
        previous.map { $0 + (measuredY - $0) * heightSmoothing } ?? measuredY
    }

    /// Height only. A hit that is not a floor can still supply height, but it does not
    /// verify the surface. Table, seat, and ceiling hits are ignored.
    public static func raycastChoice(classification: GroundSurfaceKind, hitHeight: Float,
                                     groundHeight: Float) -> RaycastChoice? {
        switch classification {
        case .table, .seat, .ceiling:
            return nil
        case .none, .wall, .floor, .window, .door, .unknown:
            break
        }
        guard abs(hitHeight - groundHeight) < raycastHeightTolerance else { return nil }
        return RaycastChoice(height: hitHeight, isVerifiedFloor: classification == .floor)
    }

    private static func accepts(_ plane: Observation, cameraY: Float) -> Bool {
        guard plane.isHorizontal, plane.area >= minimumArea else { return false }
        switch plane.classification {
        case .table, .seat, .ceiling:
            return false
        case .none, .wall, .floor, .window, .door, .unknown:
            break
        }
        let below = cameraY - plane.center.y
        guard below > minimumClearanceBelowCamera, below < maximumClearanceBelowCamera else { return false }
        return plane.horizontalDistance < maximumHorizontalDistance
    }
}
