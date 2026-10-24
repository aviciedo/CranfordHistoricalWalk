import Foundation

/// Conservative GPS hysteresis. Values need outdoor validation; no timer or old fix can
/// advance a walk. The owner creates a fresh policy whenever the destination changes.
public struct WalkingProgressionPolicy: Sendable {
    public enum Event: Equatable, Sendable { case arrived, departed }
    public private(set) var hasArrived = false
    public var isHeld = false
    public var isConfirmingArrival: Bool { !hasArrived && arrivalSince != nil }
    private var arrivalSince: Date?
    private var departureSince: Date?
    public private(set) var lastFix: Date?

    public init() {}

    /// Restore a previously confirmed arrival when undoing an automatic transition.
    public mutating func confirmArrival() { hasArrived = true; arrivalSince = nil; departureSince = nil }

    public mutating func interrupt() { arrivalSince = nil; departureSince = nil }

    public mutating func update(distance: Double, accuracy: Double, timestamp: Date,
                                now: Date = Date(), arrivalRadius: Double,
                                departureRadius: Double, allowsDeparture: Bool) -> Event? {
        guard StopActivationPolicy.isFresh(timestamp, now: now), distance.isFinite, distance >= 0,
              accuracy.isFinite, accuracy >= 0, accuracy <= StopActivationPolicy.maximumAccuracyMeters,
              arrivalRadius.isFinite, arrivalRadius > 0, departureRadius.isFinite,
              departureRadius > arrivalRadius else { interrupt(); return nil }
        // Cached/repeated fixes cannot satisfy either dwell, even across a presentation.
        if let lastFix, timestamp <= lastFix { return nil }
        if let lastFix, timestamp.timeIntervalSince(lastFix) > 10 { interrupt() }
        lastFix = timestamp
        if !hasArrived {
            guard distance + accuracy <= arrivalRadius else { arrivalSince = nil; return nil }
            guard let since = arrivalSince else { arrivalSince = timestamp; return nil }
            guard timestamp.timeIntervalSince(since) >= 3 else { return nil }
            confirmArrival()
            return .arrived
        }
        guard allowsDeparture, !isHeld, distance - accuracy > departureRadius else {
            departureSince = nil
            return nil
        }
        guard let since = departureSince else { departureSince = timestamp; return nil }
        guard timestamp.timeIntervalSince(since) >= 5 else { return nil }
        departureSince = nil
        // Consume departure; accidental reuse cannot emit a second transition.
        isHeld = true
        return .departed
    }
}
