import Foundation

public enum RouteRefreshReason: String, Sendable, Equatable {
    case noRoute
    case destinationChanged
    case movedMeaningfully
    case offRoute
    case stale
}

/// Decides when the walking route should be re-requested from the Directions provider.
/// Everything else (remaining distance/time) is derived locally; see `RouteProgressCalculator`.
public struct RouteRefreshPolicy: Sendable, Equatable {
    /// Re-route after the user has moved this far from the origin of the last request.
    public var movementThresholdMeters: Double
    /// Re-route when the user is further than this from the polyline.
    public var offRouteThresholdMeters: Double
    /// Re-route if the route is older than this *and* the user has moved at least `staleMovementMeters`.
    public var staleAfterSeconds: TimeInterval
    public var staleMovementMeters: Double
    /// Never issue two requests closer together than this, regardless of reason (except destination change).
    public var minimumIntervalSeconds: TimeInterval

    public init(
        movementThresholdMeters: Double = 25,
        offRouteThresholdMeters: Double = 30,
        staleAfterSeconds: TimeInterval = 90,
        staleMovementMeters: Double = 10,
        minimumIntervalSeconds: TimeInterval = 8
    ) {
        self.movementThresholdMeters = movementThresholdMeters
        self.offRouteThresholdMeters = offRouteThresholdMeters
        self.staleAfterSeconds = staleAfterSeconds
        self.staleMovementMeters = staleMovementMeters
        self.minimumIntervalSeconds = minimumIntervalSeconds
    }

    public static let `default` = RouteRefreshPolicy()

    public struct Context: Sendable {
        public var currentRoute: WalkingRoute?
        public var currentDestination: GeoCoordinate
        public var userLocation: GeoCoordinate
        public var progress: RouteProgress?
        public var lastRequestOrigin: GeoCoordinate?
        public var lastRequestDestination: GeoCoordinate?
        public var lastRequestDate: Date?
        public var now: Date

        public init(
            currentRoute: WalkingRoute?,
            currentDestination: GeoCoordinate,
            userLocation: GeoCoordinate,
            progress: RouteProgress?,
            lastRequestOrigin: GeoCoordinate?,
            lastRequestDestination: GeoCoordinate?,
            lastRequestDate: Date?,
            now: Date = Date()
        ) {
            self.currentRoute = currentRoute
            self.currentDestination = currentDestination
            self.userLocation = userLocation
            self.progress = progress
            self.lastRequestOrigin = lastRequestOrigin
            self.lastRequestDestination = lastRequestDestination
            self.lastRequestDate = lastRequestDate
            self.now = now
        }
    }

    /// Returns the reason to refresh, or `nil` when the current route is still good enough.
    public func refreshReason(for context: Context) -> RouteRefreshReason? {
        if let lastDestination = context.lastRequestDestination,
           GeoMath.distance(from: lastDestination, to: context.currentDestination) > 1 {
            return .destinationChanged
        }
        guard let route = context.currentRoute, let lastOrigin = context.lastRequestOrigin else {
            return .noRoute
        }
        if GeoMath.distance(from: route.destination, to: context.currentDestination) > 1 {
            return .destinationChanged
        }

        if let last = context.lastRequestDate, context.now.timeIntervalSince(last) < minimumIntervalSeconds {
            return nil
        }

        let movedSinceRequest = GeoMath.distance(from: lastOrigin, to: context.userLocation)

        if let progress = context.progress, progress.distanceFromRoute > offRouteThresholdMeters {
            return .offRoute
        }
        if movedSinceRequest >= movementThresholdMeters {
            return .movedMeaningfully
        }
        if let last = context.lastRequestDate,
           context.now.timeIntervalSince(last) >= staleAfterSeconds,
           movedSinceRequest >= staleMovementMeters {
            return .stale
        }
        return nil
    }
}
