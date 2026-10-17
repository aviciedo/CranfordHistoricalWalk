import Foundation

/// Short-lived memory for walking routes, keyed by ~11 m origin and destination cells.
///
/// The app's `CachedDirectionsService` is a thin wrapper around this actor so the TTL, in-flight
/// coalescing, and eviction rules can be tested without Core Location. Behavior matches the
/// previous in-app cache: a cell is fresh while `now - computedAt < ttl`, callers that arrive
/// while a fetch is running share that fetch, failures are not stored, and the oldest routes are
/// dropped once the cache grows past 64 entries down to 48.
public actor DirectionsRouteCache {
    public static let defaultTTL: TimeInterval = 300
    public static let defaultMaxEntries = 64
    public static let defaultRetainCount = 48

    struct Cell: Hashable {
        var originLatitude: Int
        var originLongitude: Int
        var destinationLatitude: Int
        var destinationLongitude: Int

        init(origin: GeoCoordinate, destination: GeoCoordinate) {
            // ~0.0001° ≈ 11 m of latitude. `.rounded()` is half away from zero, including west of Greenwich.
            originLatitude = Int((origin.latitude * 10_000).rounded())
            originLongitude = Int((origin.longitude * 10_000).rounded())
            destinationLatitude = Int((destination.latitude * 10_000).rounded())
            destinationLongitude = Int((destination.longitude * 10_000).rounded())
        }
    }

    private let ttl: TimeInterval
    private let maxEntries: Int
    private let retainCount: Int
    private let now: @Sendable () -> Date
    private var cache: [Cell: WalkingRoute] = [:]
    private var inFlight: [Cell: Task<WalkingRoute, Error>] = [:]
    /// Callers that attached to a fetch already in progress. The creator of the fetch does not increment this.
    private(set) var inFlightJoins = 0

    public init(
        ttl: TimeInterval = DirectionsRouteCache.defaultTTL,
        maxEntries: Int = DirectionsRouteCache.defaultMaxEntries,
        retainCount: Int = DirectionsRouteCache.defaultRetainCount,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.ttl = ttl
        self.maxEntries = maxEntries
        self.retainCount = retainCount
        self.now = now
    }

    var cachedEntryCount: Int { cache.count }

    public func route(
        from origin: GeoCoordinate,
        to destination: GeoCoordinate,
        fetch: @escaping @Sendable () async throws -> WalkingRoute
    ) async throws -> WalkingRoute {
        let key = Cell(origin: origin, destination: destination)
        if let cached = cache[key], now().timeIntervalSince(cached.computedAt) < ttl {
            return cached
        }
        if let task = inFlight[key] {
            inFlightJoins += 1
            return try await task.value
        }
        let task = Task { try await fetch() }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        let route = try await task.value
        cache[key] = route
        evictIfNeeded()
        return route
    }

    private func evictIfNeeded() {
        guard cache.count > maxEntries else { return }
        let sorted = cache.sorted { $0.value.computedAt < $1.value.computedAt }
        for (key, _) in sorted.prefix(cache.count - retainCount) {
            cache[key] = nil
        }
    }
}
