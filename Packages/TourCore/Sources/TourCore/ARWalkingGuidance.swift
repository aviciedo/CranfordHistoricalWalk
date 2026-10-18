import Foundation

/// Camera-relative guidance, independent of GPS north alignment and Apple rendering APIs.
public enum ARWalkingGuidance {
    /// Positive means turn right. A near-vertical camera has no usable horizontal facing.
    public static func relativeBearing(directionX: Double, directionZ: Double, cameraForwardX: Double, cameraForwardZ: Double) -> Double? {
        let values = [directionX, directionZ, cameraForwardX, cameraForwardZ]
        guard values.allSatisfy(\.isFinite),
              hypot(directionX, directionZ) > 0.001,
              hypot(cameraForwardX, cameraForwardZ) > 0.15 else { return nil }
        let targetYaw = atan2(directionX, -directionZ) * 180 / .pi
        let cameraYaw = atan2(cameraForwardX, -cameraForwardZ) * 180 / .pi
        return GeoMath.relativeBearing(heading: cameraYaw, bearing: targetYaw)
    }

    public static func instruction(for relativeBearing: Double?) -> String {
        guard let bearing = relativeBearing, bearing.isFinite else { return "Hold your phone up and look around" }
        switch abs(bearing) {
        case ..<20: return "Walk ahead"
        case ..<65: return bearing > 0 ? "Bear right" : "Bear left"
        case ..<135: return bearing > 0 ? "Turn right" : "Turn left"
        default: return "Turn around"
        }
    }
}
