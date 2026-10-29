import Foundation

/// When the foreground map may ask for one fresh fix.
/// Healthy continuous updates are left alone. A paused itinerary uses the same rule.
public enum MapLocationRecovery {
    /// A fix younger than this is still the live stream. Exactly 10 s is stale.
    public static let healthyFixSeconds: TimeInterval = 10
    /// Do not poll again until this long after the previous request. Exactly 15 s may retry.
    public static let minimumIntervalSeconds: TimeInterval = 15

    public static func shouldRequestFreshFix(isSubscribed: Bool, isAuthorized: Bool,
                                             latestFix: Date?, lastRequest: Date?, now: Date) -> Bool {
        guard isSubscribed, isAuthorized else { return false }
        if let latestFix, now.timeIntervalSince(latestFix) < healthyFixSeconds { return false }
        if let lastRequest, now.timeIntervalSince(lastRequest) < minimumIntervalSeconds { return false }
        return true
    }
}
