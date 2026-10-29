import Foundation

/// Fresh GPS evidence separates quick arrival detection from a three-minute physical visit.
/// Only reliable near-stop intervals count; leaving toward the next stop can complete sooner.
/// The owner creates a fresh policy whenever the destination changes.
public struct WalkingProgressionPolicy: Sendable {
    public enum Event: Equatable, Sendable { case arrived, visitReady, departed }
    public private(set) var hasArrived = false
    public var isHeld = false
    public var isConfirmingArrival: Bool { !hasArrived && arrivalSince != nil }
    public static let minimumVisitSeconds: TimeInterval = 180
    public private(set) var accumulatedVisitSeconds: TimeInterval = 0
    private var previousNearFix: Date?
    private var hasCompletedVisit = false
    private var hasDeparted = false
    private var arrivalNextStopDistance: Double?
    private var arrivalSince: Date?
    private var departureSince: Date?
    public private(set) var lastFix: Date?

    public init() {}

    /// Restore a previously confirmed arrival when undoing an automatic transition.
    public mutating func confirmArrival() { hasArrived = true; arrivalSince = nil; departureSince = nil }

    public mutating func interrupt() { arrivalSince = nil; departureSince = nil; previousNearFix = nil }

    public mutating func update(distance: Double, accuracy: Double, timestamp: Date,
                                now: Date = Date(), arrivalRadius: Double,
                                departureRadius: Double, allowsDeparture: Bool, nextStopDistance: Double? = nil) -> Event? {
        guard StopActivationPolicy.isFresh(timestamp, now: now), distance.isFinite, distance >= 0,
              accuracy.isFinite, accuracy >= 0, accuracy <= StopActivationPolicy.maximumAccuracyMeters,
              arrivalRadius.isFinite, arrivalRadius > 0, departureRadius.isFinite,
              departureRadius > arrivalRadius else { interrupt(); return nil }
        // Cached/repeated fixes cannot satisfy either dwell, even across a presentation.
        if let lastFix, timestamp <= lastFix { return nil }
        if let lastFix, timestamp.timeIntervalSince(lastFix) > 10 { interrupt() }
        lastFix = timestamp
        let isNear = distance + accuracy <= arrivalRadius
        if isNear {
            if let previousNearFix {
                accumulatedVisitSeconds += timestamp.timeIntervalSince(previousNearFix)
            }
            previousNearFix = timestamp
            if arrivalNextStopDistance == nil, let nextStopDistance,
               nextStopDistance.isFinite, nextStopDistance >= 0 {
                arrivalNextStopDistance = nextStopDistance
            }
        } else { previousNearFix = nil }
        if !hasArrived {
            guard distance + accuracy <= arrivalRadius else { arrivalSince = nil; return nil }
            guard let since = arrivalSince else { arrivalSince = timestamp; return nil }
            guard timestamp.timeIntervalSince(since) >= 3 else { return nil }
            confirmArrival()
            return .arrived
        }
        if !hasCompletedVisit && accumulatedVisitSeconds >= Self.minimumVisitSeconds {
            hasCompletedVisit = true
            return .visitReady
        }
        // When a next stop is supplied, leaving in another direction must never advance.
        let isTowardNext: Bool
        if let nextStopDistance {
            isTowardNext = nextStopDistance.isFinite && nextStopDistance >= 0
                && arrivalNextStopDistance.map { $0 - nextStopDistance >= max(8, accuracy) } == true
        } else { isTowardNext = true }
        guard allowsDeparture, !isHeld, !hasDeparted, isTowardNext,
              distance - accuracy > departureRadius else {
            departureSince = nil
            return nil
        }
        guard let since = departureSince else { departureSince = timestamp; return nil }
        guard timestamp.timeIntervalSince(since) >= 5 else { return nil }
        departureSince = nil
        // Consume departure; accidental reuse cannot emit a second transition.
        hasDeparted = true
        return .departed
    }
}
