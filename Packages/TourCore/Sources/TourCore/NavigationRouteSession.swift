import Foundation

/// Pure navigation-session state. Maps and AR observe this same route/progress pair.
/// Network tasks and provider/framework objects remain in the app's injected adapters.
public struct NavigationRouteSession: Sendable {
    public struct Request: Equatable, Sendable {
        public var origin: GeoCoordinate
        public var destination: GeoCoordinate
        public var date: Date
        public var reason: RouteRefreshReason
        public init(origin: GeoCoordinate, destination: GeoCoordinate, date: Date, reason: RouteRefreshReason) {
            self.origin = origin; self.destination = destination; self.date = date; self.reason = reason
        }
    }
    public var route: WalkingRoute?
    public var progress: RouteProgress?
    public var errorMessage: String?
    public var lastRequest: Request?
    public var legRoutes: [String: WalkingRoute] = [:]
    public var refreshPolicy = RouteRefreshPolicy.default
    public var generation = 0
    public var isRequestInFlight = false
    public var recoveryAttempts = 0
    public var retryOnFreshLocation = false
    public init() {}

    @discardableResult
    public mutating func begin(origin: GeoCoordinate, destination: GeoCoordinate,
                                reason: RouteRefreshReason, now: Date = Date()) -> Int {
        generation += 1
        lastRequest = Request(origin: origin, destination: destination, date: now, reason: reason)
        isRequestInFlight = true
        return generation
    }

    public mutating func finish(generation completedGeneration: Int) {
        guard completedGeneration == generation else { return }
        isRequestInFlight = false
    }

    public mutating func invalidate() { generation += 1; isRequestInFlight = false }

    public mutating func resetDestination() {
        invalidate()
        route = nil; progress = nil; errorMessage = nil
        recoveryAttempts = 0; retryOnFreshLocation = false
    }

    /// A late response must not replace a newer request, even if destinations coincide.
    public func accepts(generation candidate: Int, destination: GeoCoordinate,
                        currentDestination: GeoCoordinate?) -> Bool {
        guard candidate == generation, let currentDestination else { return false }
        return GeoMath.distance(from: currentDestination, to: destination) < 1
    }
}

/// One owner for active/passive dwell state. Persistence and rendering do not own timers.
public struct TourVisitSession: Sendable {
    public var active = WalkingProgressionPolicy()
    public var passive: [String: WalkingProgressionPolicy] = [:]
    public init() {}
    public mutating func resetActive(held: Bool) {
        active = WalkingProgressionPolicy(); active.isHeld = held
    }
    public mutating func interrupt() {
        active.interrupt()
        for id in Array(passive.keys) { passive[id]?.interrupt() }
    }
}
