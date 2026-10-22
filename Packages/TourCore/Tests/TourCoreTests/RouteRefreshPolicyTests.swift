import XCTest
@testable import TourCore

final class RouteRefreshPolicyTests: XCTestCase {
    let policy = RouteRefreshPolicy.default
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func context(route: WalkingRoute?, user: GeoCoordinate, destination: GeoCoordinate, lastOrigin: GeoCoordinate?, lastDestination: GeoCoordinate?, lastDate: Date?, now: Date) -> RouteRefreshPolicy.Context {
        let progress = route.map { RouteProgressCalculator.progress(along: $0, userLocation: user) }
        return .init(currentRoute: route, currentDestination: destination, userLocation: user, progress: progress, lastRequestOrigin: lastOrigin, lastRequestDestination: lastDestination, lastRequestDate: lastDate, now: now)
    }

    func testNoRouteTriggersRefresh() {
        let dest = GeoMath.destination(from: cranfordCenter, bearing: 0, distance: 500)
        let c = context(route: nil, user: cranfordCenter, destination: dest, lastOrigin: nil, lastDestination: nil, lastDate: nil, now: t0)
        XCTAssertEqual(policy.refreshReason(for: c), .noRoute)
    }

    func testSmallMovementDoesNotRefresh() {
        let route = makeRoute(from: cranfordCenter, bearing: 0, segments: 5, segmentMeters: 100)
        let user = GeoMath.destination(from: cranfordCenter, bearing: 0, distance: 10)
        let c = context(route: route, user: user, destination: route.destination, lastOrigin: cranfordCenter, lastDestination: route.destination, lastDate: t0, now: t0 + 20)
        XCTAssertNil(policy.refreshReason(for: c))
    }

    func testMeaningfulMovementRefreshes() {
        let route = makeRoute(from: cranfordCenter, bearing: 0, segments: 5, segmentMeters: 100)
        let user = GeoMath.destination(from: cranfordCenter, bearing: 0, distance: 30)
        let c = context(route: route, user: user, destination: route.destination, lastOrigin: cranfordCenter, lastDestination: route.destination, lastDate: t0, now: t0 + 20)
        XCTAssertEqual(policy.refreshReason(for: c), .movedMeaningfully)
    }

    func testOffRouteRefreshesEvenWithoutMuchMovement() {
        let route = makeRoute(from: cranfordCenter, bearing: 0, segments: 5, segmentMeters: 100)
        // Sidestep 35 m east: only ~35 m from origin, but 35 m off the polyline (> 30).
        let user = GeoMath.destination(from: cranfordCenter, bearing: 90, distance: 35)
        var tight = policy
        tight.movementThresholdMeters = 1000
        let c = context(route: route, user: user, destination: route.destination, lastOrigin: cranfordCenter, lastDestination: route.destination, lastDate: t0, now: t0 + 20)
        XCTAssertEqual(tight.refreshReason(for: c), .offRoute)
    }

    func testDestinationChangeAlwaysRefreshes() {
        let route = makeRoute(from: cranfordCenter, bearing: 0, segments: 5, segmentMeters: 100)
        let newDest = GeoMath.destination(from: cranfordCenter, bearing: 90, distance: 800)
        // Even inside the minimum interval.
        let c = context(route: route, user: cranfordCenter, destination: newDest, lastOrigin: cranfordCenter, lastDestination: route.destination, lastDate: t0, now: t0 + 1)
        XCTAssertEqual(policy.refreshReason(for: c), .destinationChanged)
    }

    func testOffRouteInsideMinimumIntervalDoesNotRefresh() {
        let route = makeRoute(from: cranfordCenter, bearing: 0, segments: 5, segmentMeters: 100)
        let jumped = GeoMath.destination(from: cranfordCenter, bearing: 90, distance: 40)
        let soon = context(route: route, user: jumped, destination: route.destination, lastOrigin: cranfordCenter, lastDestination: route.destination, lastDate: t0, now: t0 + 2)
        XCTAssertNil(policy.refreshReason(for: soon), "a GPS jump inside the minimum interval must not stampede the Routes API")
        let later = context(route: route, user: jumped, destination: route.destination, lastOrigin: cranfordCenter, lastDestination: route.destination, lastDate: t0, now: t0 + 20)
        XCTAssertEqual(policy.refreshReason(for: later), .offRoute)
    }

    func testStalePolylineForTheNewStopRefreshesImmediately() {
        let oldRoute = makeRoute(from: cranfordCenter, bearing: 0, segments: 5, segmentMeters: 100)
        let newDestination = GeoMath.destination(from: cranfordCenter, bearing: 90, distance: 400)
        // The request was already recorded for the new stop, but the polyline still ends at the old one.
        let pending = context(route: oldRoute, user: cranfordCenter, destination: newDestination, lastOrigin: cranfordCenter, lastDestination: newDestination, lastDate: t0, now: t0 + 1)
        XCTAssertEqual(policy.refreshReason(for: pending), .destinationChanged)

        let jitter = GeoMath.destination(from: oldRoute.destination, bearing: 45, distance: 0.4)
        let noise = context(route: oldRoute, user: cranfordCenter, destination: jitter, lastOrigin: cranfordCenter, lastDestination: oldRoute.destination, lastDate: t0, now: t0 + 1)
        XCTAssertNil(policy.refreshReason(for: noise), "sub-meter destination noise is not a new stop")
    }

    func testMinimumIntervalSuppressesRapidRefresh() {
        let route = makeRoute(from: cranfordCenter, bearing: 0, segments: 5, segmentMeters: 100)
        let user = GeoMath.destination(from: cranfordCenter, bearing: 0, distance: 60)
        let c = context(route: route, user: user, destination: route.destination, lastOrigin: cranfordCenter, lastDestination: route.destination, lastDate: t0, now: t0 + 3)
        XCTAssertNil(policy.refreshReason(for: c))
    }

    func testStaleRouteRefreshesOnlyIfUserMoved() {
        let route = makeRoute(from: cranfordCenter, bearing: 0, segments: 5, segmentMeters: 100)
        let still = context(route: route, user: cranfordCenter, destination: route.destination, lastOrigin: cranfordCenter, lastDestination: route.destination, lastDate: t0, now: t0 + 600)
        XCTAssertNil(policy.refreshReason(for: still), "Standing still must not burn API quota")
        let moved = GeoMath.destination(from: cranfordCenter, bearing: 0, distance: 15)
        let c = context(route: route, user: moved, destination: route.destination, lastOrigin: cranfordCenter, lastDestination: route.destination, lastDate: t0, now: t0 + 600)
        XCTAssertEqual(policy.refreshReason(for: c), .stale)
    }

    func testSimulatedWalkIssuesBoundedNumberOfRequests() {
        // Walk 1 km straight along the route at 1.4 m/s with 1 Hz updates; count refreshes.
        let route = makeRoute(from: cranfordCenter, bearing: 0, segments: 10, segmentMeters: 100)
        var lastOrigin: GeoCoordinate? = cranfordCenter
        var lastDate: Date? = t0
        var requests = 0
        let sim = WalkSimulator(metersPerSecond: 1.4)
        var pos = cranfordCenter
        for second in 1...700 {
            pos = sim.step(from: pos, toward: route.destination, deltaTime: 1).coordinate
            let now = t0 + TimeInterval(second)
            let c = context(route: route, user: pos, destination: route.destination, lastOrigin: lastOrigin, lastDestination: route.destination, lastDate: lastDate, now: now)
            if policy.refreshReason(for: c) != nil {
                requests += 1
                lastOrigin = pos
                lastDate = now
            }
        }
        // ~1000 m / 25 m ≈ 40 requests max; must be far below one per update (700).
        XCTAssertLessThanOrEqual(requests, 45)
        XCTAssertGreaterThan(requests, 10)
    }
}
