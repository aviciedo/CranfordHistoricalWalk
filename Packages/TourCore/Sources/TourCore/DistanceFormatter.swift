import Foundation

/// Compact, locale-stable strings for the navigation panel ("0.4 mi", "350 ft", "8 min").
/// Kept deterministic (no `MeasurementFormatter`) so unit tests behave identically everywhere.
public enum DistanceFormatter {
    public enum Units: Sendable { case imperial, metric }

    public static func distance(meters: Double, units: Units = .imperial) -> String {
        guard meters.isFinite, meters >= 0 else { return "—" }
        switch units {
        case .imperial:
            let miles = GeoMath.miles(fromMeters: meters)
            if miles < 0.1 {
                let feet = GeoMath.feet(fromMeters: meters)
                return "\(Int((feet / 10).rounded() * 10)) ft"
            }
            if miles < 10 { return String(format: "%.1f mi", miles) }
            return "\(Int(miles.rounded())) mi"
        case .metric:
            if meters < 1000 { return "\(Int((meters / 10).rounded() * 10)) m" }
            if meters < 10_000 { return String(format: "%.1f km", meters / 1000) }
            return "\(Int((meters / 1000).rounded())) km"
        }
    }

    /// Minutes, rounding up so the estimate never under-promises; "< 1 min" below 30 s.
    public static func duration(seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "—" }
        if seconds < 30 { return "< 1 min" }
        let minutes = Int((seconds / 60).rounded(.up))
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours) hr" : "\(hours) hr \(rest) min"
    }

    /// Header style: "~42 MINUTES", "~1 HR 5 MIN".
    public static func approximateDuration(seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "—" }
        let minutes = max(1, Int((seconds / 60).rounded()))
        if minutes < 60 { return "~\(minutes) MINUTES" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "~\(hours) HR" : "~\(hours) HR \(rest) MIN"
    }

    /// Header style: "2.1 MILES".
    public static func headerDistance(meters: Double, units: Units = .imperial) -> String {
        switch units {
        case .imperial:
            let miles = GeoMath.miles(fromMeters: meters)
            return String(format: "%.1f MILES", miles)
        case .metric:
            return String(format: "%.1f KM", meters / 1000)
        }
    }
}
