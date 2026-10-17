import Foundation

/// Which GPS fixes are allowed to move tour state. Extracted from `TourViewModel` so the gates
/// can be tested without Core Location.
public enum LocationFixPolicy {
    /// Fixes worse than this must not open or close the AR sign. A 200 m jump with poor GPS
    /// would otherwise present the sign blocks away from the stop.
    public static let proximityAccuracyLimitMeters: Double = 100
    /// Fixes worse than this are "weak GPS" and do not add to the walked distance.
    public static let poorAccuracyMeters: Double = 40
    /// A fix older than this is not a usable current position.
    public static let usableFixMaxAge: TimeInterval = 60

    public static func acceptsProximityUpdate(horizontalAccuracy: Double) -> Bool {
        horizontalAccuracy >= 0 && horizontalAccuracy <= proximityAccuracyLimitMeters
    }

    /// Meters to add to the walked total, or `nil` when the fix is too coarse or the step is jitter.
    /// Steps must be strictly greater than `max(2 m, half the reported accuracy)`.
    public static func walkedMeters(moved: Double, horizontalAccuracy: Double) -> Double? {
        guard horizontalAccuracy <= poorAccuracyMeters else { return nil }
        guard moved > max(2, horizontalAccuracy * 0.5) else { return nil }
        return moved
    }

    public static func isUsable(horizontalAccuracy: Double, age: TimeInterval) -> Bool {
        horizontalAccuracy >= 0 && age < usableFixMaxAge
    }
}
