import XCTest
@testable import TourCore

final class DirectionsRouteCacheTests: XCTestCase {
    func testCellsBucketAboutElevenMetersAndRoundHalfAwayFromZero() {
        let origin = GeoCoordinate(latitude: 40.6584, longitude: -74.3035)
        let destination = GeoCoordinate(latitude: 40.6620, longitude: -74.2990)
        let nearNorth = GeoMath.destination(from: origin, bearing: 0, distance: 4)
        let farNorth = GeoMath.destination(from: origin, bearing: 0, distance: 25)
        XCTAssertLessThan(GeoMath.distance(from: origin, to: nearNorth), 11)
        XCTAssertGreaterThan(GeoMath.distance(from: origin, to: farNorth), 11)
        XCTAssertEqual(
            DirectionsRouteCache.Cell(origin: origin, destination: destination),
            DirectionsRouteCache.Cell(origin: nearNorth, destination: destination)
        )
        XCTAssertNotEqual(
            DirectionsRouteCache.Cell(origin: origin, destination: destination),
            DirectionsRouteCache.Cell(origin: farNorth, destination: destination)
        )

        let otherStop = GeoCoordinate(latitude: destination.latitude + 0.001, longitude: destination.longitude)
        XCTAssertNotEqual(
            DirectionsRouteCache.Cell(origin: origin, destination: destination),
            DirectionsRouteCache.Cell(origin: origin, destination: otherStop)
        )

        // Half units round away from zero, so a western longitude does not collapse into the cell to its east.
        let westHalf = GeoCoordinate(latitude: 40.65845, longitude: -74.30355)
        let halfCell = DirectionsRouteCache.Cell(origin: westHalf, destination: westHalf)
        XCTAssertEqual(halfCell.originLatitude, 406585)
        XCTAssertEqual(halfCell.originLongitude, -743036)
        let justInside = GeoCoordinate(latitude: 40.658449, longitude: -74.303549)
        let insideCell = DirectionsRouteCache.Cell(origin: justInside, destination: justInside)
        XCTAssertEqual(insideCell.originLatitude, 406584)
        XCTAssertEqual(insideCell.originLongitude, -743035)
    }

    func testFreshRouteIsReusedUntilTheTTL() async throws {
        let origin = GeoCoordinate(latitude: 40.6584, longitude: -74.3035)
        let destination = GeoCoordinate(latitude: 40.6620, longitude: -74.2990)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = DirectionsRouteCache(ttl: 300, now: { now })
        let fetches = Counter()
        let stored = makeRoute(at: now.addingTimeInterval(-299), from: origin, to: destination)

        let served = try await cache.route(from: origin, to: destination) {
            await fetches.increment()
            return stored
        }
        let again = try await cache.route(from: origin, to: destination) {
            await fetches.increment()
            return makeRoute(at: now, from: origin, to: destination)
        }

        let fetchCount = await fetches.value
        XCTAssertEqual(served, stored)
        XCTAssertEqual(again, stored)
        XCTAssertEqual(fetchCount, 1)
    }

    func testRouteExactlyOneTTLOldIsFetchedAgain() async throws {
        let origin = GeoCoordinate(latitude: 40.6584, longitude: -74.3035)
        let destination = GeoCoordinate(latitude: 40.6620, longitude: -74.2990)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = DirectionsRouteCache(ttl: 300, now: { now })
        let fetches = Counter()
        let stale = makeRoute(at: now.addingTimeInterval(-300), from: origin, to: destination)
        let replacement = makeRoute(at: now, from: origin, to: destination)

        _ = try await cache.route(from: origin, to: destination) {
            await fetches.increment()
            return stale
        }
        let served = try await cache.route(from: origin, to: destination) {
            await fetches.increment()
            return replacement
        }
        let cached = try await cache.route(from: origin, to: destination) {
            await fetches.increment()
            return makeRoute(at: now.addingTimeInterval(10), from: origin, to: destination)
        }

        let fetchCount = await fetches.value
        XCTAssertEqual(served, replacement)
        XCTAssertEqual(cached, replacement)
        XCTAssertEqual(fetchCount, 2)
    }

    func testNearbyOriginReusesTheCellAndADifferentStopDoesNot() async throws {
        let origin = GeoCoordinate(latitude: 40.6584, longitude: -74.3035)
        let destination = GeoCoordinate(latitude: 40.6620, longitude: -74.2990)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = DirectionsRouteCache(ttl: 300, now: { now })
        let fetches = Counter()
        let stored = makeRoute(at: now, from: origin, to: destination)
        _ = try await cache.route(from: origin, to: destination) {
            await fetches.increment()
            return stored
        }

        let near = GeoMath.destination(from: origin, bearing: 0, distance: 4)
        let reused = try await cache.route(from: near, to: destination) {
            await fetches.increment()
            return makeRoute(at: now.addingTimeInterval(5), from: origin, to: destination)
        }
        XCTAssertEqual(reused, stored)

        let elsewhere = GeoCoordinate(latitude: destination.latitude + 0.01, longitude: destination.longitude)
        let other = makeRoute(at: now, from: origin, to: elsewhere)
        let fetched = try await cache.route(from: origin, to: elsewhere) {
            await fetches.increment()
            return other
        }
        let fetchCount = await fetches.value
        XCTAssertEqual(fetched, other)
        XCTAssertEqual(fetchCount, 2)
    }

    func testFailureIsNotCachedAndALaterCallRetries() async throws {
        let origin = GeoCoordinate(latitude: 40.6584, longitude: -74.3035)
        let destination = GeoCoordinate(latitude: 40.6620, longitude: -74.2990)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = DirectionsRouteCache(ttl: 300, now: { now })
        let fetches = Counter()

        do {
            _ = try await cache.route(from: origin, to: destination) {
                await fetches.increment()
                throw StubFetchError.failed
            }
            XCTFail("expected the fetch to fail")
        } catch is StubFetchError {
        } catch {
            XCTFail("unexpected error \(error)")
        }

        let stored = makeRoute(at: now, from: origin, to: destination)
        let served = try await cache.route(from: origin, to: destination) {
            await fetches.increment()
            return stored
        }
        _ = try await cache.route(from: origin, to: destination) {
            await fetches.increment()
            return makeRoute(at: now.addingTimeInterval(1), from: origin, to: destination)
        }
        let fetchCount = await fetches.value
        XCTAssertEqual(served, stored)
        XCTAssertEqual(fetchCount, 2)
    }

    func testConcurrentCallersShareOneFetch() async throws {
        let origin = GeoCoordinate(latitude: 40.6584, longitude: -74.3035)
        let destination = GeoCoordinate(latitude: 40.6620, longitude: -74.2990)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = DirectionsRouteCache(ttl: 300, now: { now })
        let gate = Gate()
        let expected = makeRoute(at: now, from: origin, to: destination)

        let first = Task { () throws -> WalkingRoute in
            try await cache.route(from: origin, to: destination) {
                await gate.enter()
                return expected
            }
        }
        await gate.waitUntilEntered(1)
        let second = Task { () throws -> WalkingRoute in
            try await cache.route(from: origin, to: destination) {
                await gate.enter()
                return expected
            }
        }
        try await waitUntil { await cache.inFlightJoins == 1 }
        await gate.release()

        let firstRoute = try await first.value
        let secondRoute = try await second.value
        let entered = await gate.enteredCount
        XCTAssertEqual(firstRoute, expected)
        XCTAssertEqual(secondRoute, expected)
        XCTAssertEqual(entered, 1)
    }

    func testJoinerWaitsForTheRefreshInsteadOfReceivingTheStaleRoute() async throws {
        let origin = GeoCoordinate(latitude: 40.6584, longitude: -74.3035)
        let destination = GeoCoordinate(latitude: 40.6620, longitude: -74.2990)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = DirectionsRouteCache(ttl: 300, now: { now })
        let stale = makeRoute(at: now.addingTimeInterval(-300), from: origin, to: destination)
        _ = try await cache.route(from: origin, to: destination) { stale }

        let gate = Gate()
        let fresh = makeRoute(at: now, from: origin, to: destination)
        let refresher = Task { () throws -> WalkingRoute in
            try await cache.route(from: origin, to: destination) {
                await gate.enter()
                return fresh
            }
        }
        await gate.waitUntilEntered(1)
        let joiner = Task { () throws -> WalkingRoute in
            try await cache.route(from: origin, to: destination) {
                await gate.enter()
                return makeRoute(at: now.addingTimeInterval(30), from: origin, to: destination)
            }
        }
        try await waitUntil { await cache.inFlightJoins == 1 }
        await gate.release()

        let refreshed = try await refresher.value
        let joined = try await joiner.value
        let entered = await gate.enteredCount
        XCTAssertEqual(refreshed, fresh)
        XCTAssertEqual(joined, fresh)
        XCTAssertEqual(entered, 1)
    }

    func testSharedFailureDoesNotStickAndDistinctCellsFetchSeparately() async throws {
        let origin = GeoCoordinate(latitude: 40.6584, longitude: -74.3035)
        let destination = GeoCoordinate(latitude: 40.6620, longitude: -74.2990)
        let elsewhere = GeoCoordinate(latitude: destination.latitude + 0.02, longitude: destination.longitude)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = DirectionsRouteCache(ttl: 300, now: { now })
        let gate = Gate()

        let first = Task { () throws -> WalkingRoute in
            try await cache.route(from: origin, to: destination) {
                await gate.enter()
                throw StubFetchError.failed
            }
        }
        await gate.waitUntilEntered(1)
        let second = Task { () throws -> WalkingRoute in
            try await cache.route(from: origin, to: destination) {
                await gate.enter()
                throw StubFetchError.failed
            }
        }
        try await waitUntil { await cache.inFlightJoins == 1 }
        await gate.release()

        do {
            _ = try await first.value
            XCTFail("expected failure")
        } catch is StubFetchError {}
        do {
            _ = try await second.value
            XCTFail("expected failure")
        } catch is StubFetchError {}
        let failedFetches = await gate.enteredCount
        XCTAssertEqual(failedFetches, 1)

        let otherGate = Gate()
        let retry = makeRoute(at: now, from: origin, to: destination)
        let other = makeRoute(at: now, from: origin, to: elsewhere)
        let left = Task { () throws -> WalkingRoute in
            try await cache.route(from: origin, to: destination) {
                await otherGate.enter()
                return retry
            }
        }
        let right = Task { () throws -> WalkingRoute in
            try await cache.route(from: origin, to: elsewhere) {
                await otherGate.enter()
                return other
            }
        }
        await otherGate.waitUntilEntered(2)
        await otherGate.release()
        let leftRoute = try await left.value
        let rightRoute = try await right.value
        let separateFetches = await otherGate.enteredCount
        XCTAssertEqual(leftRoute, retry)
        XCTAssertEqual(rightRoute, other)
        XCTAssertEqual(separateFetches, 2)
    }

    func testCacheKeepsSixtyFourEntriesThenDropsDownToTheNewestFortyEight() async throws {
        let origin = GeoCoordinate(latitude: 40.6584, longitude: -74.3035)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = DirectionsRouteCache(now: { now })
        XCTAssertEqual(DirectionsRouteCache.defaultTTL, 300)
        XCTAssertEqual(DirectionsRouteCache.defaultMaxEntries, 64)
        XCTAssertEqual(DirectionsRouteCache.defaultRetainCount, 48)

        for index in 0..<64 {
            let end = stop(index)
            _ = try await cache.route(from: origin, to: end) {
                makeRoute(at: now.addingTimeInterval(TimeInterval(index) - 200), from: origin, to: end)
            }
        }
        let beforeEviction = await cache.cachedEntryCount
        XCTAssertEqual(beforeEviction, 64)

        let newest = stop(64)
        _ = try await cache.route(from: origin, to: newest) {
            makeRoute(at: now.addingTimeInterval(-100), from: origin, to: newest)
        }
        let afterEviction = await cache.cachedEntryCount
        XCTAssertEqual(afterEviction, 48)

        let fetches = Counter()
        let evicted = stop(16)
        let kept = stop(17)
        _ = try await cache.route(from: origin, to: evicted) {
            await fetches.increment()
            return makeRoute(at: now, from: origin, to: evicted)
        }
        _ = try await cache.route(from: origin, to: kept) {
            await fetches.increment()
            return makeRoute(at: now, from: origin, to: kept)
        }
        _ = try await cache.route(from: origin, to: newest) {
            await fetches.increment()
            return makeRoute(at: now, from: origin, to: newest)
        }
        let refetchCount = await fetches.value
        XCTAssertEqual(refetchCount, 1, "index 16 is the newest evicted route; 17 and 64 stay")
    }

    private func stop(_ index: Int) -> GeoCoordinate {
        GeoCoordinate(latitude: 41 + Double(index) * 0.01, longitude: -74.2)
    }

    private func waitUntil(_ condition: @escaping () async -> Bool) async throws {
        let start = Date()
        while await !condition() {
            if Date().timeIntervalSince(start) > 5 {
                XCTFail("timed out waiting for the cache")
                return
            }
            await Task.yield()
        }
    }
}

private func makeRoute(at date: Date, from origin: GeoCoordinate, to destination: GeoCoordinate) -> WalkingRoute {
    WalkingRoute(
        origin: origin,
        destination: destination,
        distanceMeters: 120,
        durationSeconds: 90,
        routeCoordinates: [origin, destination],
        source: .googleRoutesAPI,
        computedAt: date
    )
}

private enum StubFetchError: Error { case failed }

private actor Counter {
    private(set) var value = 0
    func increment() { value += 1 }
}

private actor Gate {
    private var entered = 0
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var released = false

    var enteredCount: Int { entered }

    func enter() async {
        entered += 1
        if released { return }
        await withCheckedContinuation { continuations.append($0) }
    }

    func waitUntilEntered(_ count: Int) async {
        let start = Date()
        while entered < count {
            if Date().timeIntervalSince(start) > 5 { return }
            await Task.yield()
        }
    }

    func release() {
        released = true
        let pending = continuations
        continuations.removeAll()
        pending.forEach { $0.resume() }
    }
}
