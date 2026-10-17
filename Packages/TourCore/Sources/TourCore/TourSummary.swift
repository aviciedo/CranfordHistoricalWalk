import Foundation

/// Aggregate figures for the "HISTORICAL WALK / 7 STOPS / 2.1 MILES / ~42 MINUTES" header and
/// the "TOUR COMPLETE" screen (spec §12). Always computed from real `WalkingRoute` legs.
public struct TourSummary: Sendable, Equatable {
    public var stopCount: Int
    public var totalDistanceMeters: Double
    public var totalWalkingSeconds: TimeInterval
    /// Visit time at stops, from `HistoricalStop.estimatedVisitDuration`.
    public var totalVisitSeconds: TimeInterval
    /// False if any leg had to use a straight-line estimate or is still loading.
    public var isFromWalkingRoutes: Bool
    /// Number of legs still missing a route (header can show "Calculating…").
    public var pendingLegCount: Int

    public var totalSeconds: TimeInterval { totalWalkingSeconds + totalVisitSeconds }

    public init(stopCount: Int, totalDistanceMeters: Double, totalWalkingSeconds: TimeInterval, totalVisitSeconds: TimeInterval, isFromWalkingRoutes: Bool, pendingLegCount: Int) {
        self.stopCount = stopCount
        self.totalDistanceMeters = totalDistanceMeters
        self.totalWalkingSeconds = totalWalkingSeconds
        self.totalVisitSeconds = totalVisitSeconds
        self.isFromWalkingRoutes = isFromWalkingRoutes
        self.pendingLegCount = pendingLegCount
    }

    /// `legs[i]` is the route from the start (or stop i-1) to stop i. `nil` legs are pending.
    public static func make(stops: [HistoricalStop], legs: [WalkingRoute?], includeVisitTime: Bool = false) -> TourSummary {
        var distance = 0.0
        var seconds = 0.0
        var allRouted = true
        var pending = 0
        for leg in legs {
            if let leg {
                distance += leg.distanceMeters
                seconds += leg.durationSeconds
                if leg.source == .straightLineEstimate { allRouted = false }
            } else {
                pending += 1
                allRouted = false
            }
        }
        let visit = includeVisitTime ? stops.reduce(0) { $0 + $1.estimatedVisitDuration } : 0
        return TourSummary(
            stopCount: stops.count,
            totalDistanceMeters: distance,
            totalWalkingSeconds: seconds,
            totalVisitSeconds: visit,
            isFromWalkingRoutes: allRouted && pending == 0,
            pendingLegCount: pending
        )
    }
}

/// Distance shown on the tour-complete screen.
///
/// Under 50 m of measured walking (a jump, a simulator teleport, or a tour that barely moved)
/// the routed total is kept so the screen is not blank. A real walk shows the measured distance.
public struct TourCompletionDistance: Equatable, Sendable {
    public static let minimumMeasuredMeters: Double = 50

    public var meters: Double
    public var isMeasured: Bool

    public init(meters: Double, isMeasured: Bool) {
        self.meters = meters
        self.isMeasured = isMeasured
    }

    public static func select(walkedMeters: Double, routedMeters: Double) -> TourCompletionDistance {
        if walkedMeters >= minimumMeasuredMeters {
            return TourCompletionDistance(meters: walkedMeters, isMeasured: true)
        }
        return TourCompletionDistance(meters: routedMeters, isMeasured: false)
    }
}
