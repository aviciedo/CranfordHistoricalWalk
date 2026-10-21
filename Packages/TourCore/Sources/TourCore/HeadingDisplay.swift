import Foundation

/// Heading drawn on the map and in AR. A reliable compass wins; otherwise the GPS course
/// is used only while the visitor is actually moving.
public enum HeadingDisplay {
    public static let maximumReliableAccuracyDegrees: Double = 25
    /// Course at this speed or slower is treated as standing still.
    public static let minimumMovingSpeedMetersPerSecond: Double = 0.5

    public static func best(trueHeading: Double?, magneticHeading: Double) -> Double {
        trueHeading ?? magneticHeading
    }

    public static func isReliable(accuracy: Double, heading: Double) -> Bool {
        accuracy.isFinite && accuracy >= 0 && accuracy <= maximumReliableAccuracyDegrees && heading.isFinite
    }

    public static func choose(reliableCompass: Double?, course: Double?, speed: Double?) -> Double? {
        if let reliableCompass { return reliableCompass }
        if let course, (speed ?? 0) > minimumMovingSpeedMetersPerSecond { return course }
        return nil
    }
}
