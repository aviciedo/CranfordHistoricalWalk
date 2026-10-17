import Foundation

/// Decides whether a GPS fix may move the arrival/departure geofence.
///
/// The sign opens at 35 m and closes past 50 m, but the app otherwise accepts fixes
/// with up to 100 m of reported accuracy and any age. A single sloppy or cached fix
/// can land inside the arrival radius, mark the stop visited, and the next real fix
/// then dismisses the sign and advances the tour.
public enum ProximityFixFilter {
    /// Core Location can deliver a cached fix immediately. Apple's guidance is to
    /// ignore locations older than about 15 seconds.
    public static let maximumAge: TimeInterval = 15
    /// Allow a few seconds of clock skew so a fix timestamped slightly ahead of `now` is kept.
    public static let maximumFutureSkew: TimeInterval = 5

    public static func isFresh(timestamp: Date, now: Date = Date(), maximumAge: TimeInterval = maximumAge) -> Bool {
        let age = now.timeIntervalSince(timestamp)
        return age >= -maximumFutureSkew && age < maximumAge
    }

    /// Raw distance to feed the state machine, or `nil` when the fix is too uncertain
    /// to change arrival or departure. `nil` means "ignore this sample", not "distance zero".
    public static func distanceToApply(
        reportedMeters: Double,
        horizontalAccuracy: Double,
        state: StopProximityState,
        arrivalRadius: Double,
        departureRadius: Double
    ) -> Double? {
        guard reportedMeters.isFinite, horizontalAccuracy.isFinite, horizontalAccuracy >= 0 else { return nil }
        switch state {
        case .approaching, .nearby:
            // The whole error circle must sit inside the arrival radius before the sign opens.
            if reportedMeters <= arrivalRadius, reportedMeters + horizontalAccuracy > arrivalRadius {
                return nil
            }
        case .signPresented, .signDismissed:
            // The whole error circle must sit outside the departure radius before the sign closes.
            if reportedMeters > departureRadius, reportedMeters - horizontalAccuracy <= departureRadius {
                return nil
            }
        case .completed:
            break
        }
        return reportedMeters
    }
}
