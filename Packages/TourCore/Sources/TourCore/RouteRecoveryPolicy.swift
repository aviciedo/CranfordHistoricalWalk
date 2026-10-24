import Foundation

/// Decides whether a failed walking-route request may be retried.
/// A retry must use a fresh, accurate fix. A stale or weak sample only arms a later retry;
/// it never becomes the origin of a directions request and never advances the itinerary.
public enum RouteRecoveryPolicy {
    public static let maximumAttempts = 5

    public struct Fix: Equatable, Sendable {
        public var coordinate: GeoCoordinate
        public var horizontalAccuracy: Double
        public var timestamp: Date

        public init(coordinate: GeoCoordinate, horizontalAccuracy: Double, timestamp: Date) {
            self.coordinate = coordinate
            self.horizontalAccuracy = horizontalAccuracy
            self.timestamp = timestamp
        }
    }

    public enum Decision: Equatable, Sendable {
        /// Leave the deferred-retry flag unchanged and do not request a route.
        case ignore
        /// Remember to retry once a fresh, accurate fix arrives. Do not route from this sample.
        case deferUntilFreshFix
        /// Request a route from this coordinate and clear the deferred-retry flag.
        case request(GeoCoordinate)
    }

    /// `attempts` is how many recoveries have already been scheduled.
    public static func canSchedule(attempts: Int) -> Bool {
        attempts < maximumAttempts
    }

    /// Same acceptance rule as a visit fix: non-negative accuracy within the shared limit, and fresh.
    public static func accepts(_ fix: Fix, now: Date = Date()) -> Bool {
        StopActivationPolicy.isFresh(fix.timestamp, now: now)
            && fix.horizontalAccuracy >= 0
            && fix.horizontalAccuracy <= StopActivationPolicy.maximumAccuracyMeters
    }

    /// Automatic wake after the recovery delay.
    /// A paused walk, a superseded generation, or a request already in flight must not arm a retry.
    public static func onScheduledWake(walking: Bool, routingIdle: Bool, generationCurrent: Bool,
                                       fix: Fix?, hasDestination: Bool, now: Date = Date()) -> Decision {
        guard walking, routingIdle, generationCurrent else { return .ignore }
        guard hasDestination, let fix, accepts(fix, now: now) else { return .deferUntilFreshFix }
        return .request(fix.coordinate)
    }

    /// A later location sample while a retry is waiting on a better fix.
    public static func onLocationSample(deferred: Bool, walking: Bool, hasDestination: Bool,
                                        fix: Fix, now: Date = Date()) -> Decision {
        guard deferred, walking, hasDestination, accepts(fix, now: now) else { return .ignore }
        return .request(fix.coordinate)
    }

    /// The explicit Retry control. Does nothing unless a walk is active; the caller resets the budget.
    public static func onManualRetry(walking: Bool, fix: Fix?, hasDestination: Bool, now: Date = Date()) -> Decision {
        guard walking else { return .ignore }
        guard hasDestination, let fix, accepts(fix, now: now) else { return .deferUntilFreshFix }
        return .request(fix.coordinate)
    }
}
