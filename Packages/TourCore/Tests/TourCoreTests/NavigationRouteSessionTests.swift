import XCTest
@testable import TourCore

final class NavigationRouteSessionTests: XCTestCase {
    let origin = GeoCoordinate(latitude: 40.65, longitude: -74.3)
    let destination = GeoCoordinate(latitude: 40.652, longitude: -74.299)
    func testOldSameDestinationResponseCannotFinishOrReplaceNewRequest() {
        var state = NavigationRouteSession()
        let first = state.begin(origin: origin, destination: destination, reason: .stale)
        let second = state.begin(origin: origin, destination: destination, reason: .stale)
        state.finish(generation: first)
        XCTAssertTrue(state.isRequestInFlight)
        XCTAssertFalse(state.accepts(generation: first, destination: destination, currentDestination: destination))
        XCTAssertTrue(state.accepts(generation: second, destination: destination, currentDestination: destination))
        state.finish(generation: second)
        XCTAssertFalse(state.isRequestInFlight)
        state.resetDestination()
        XCTAssertFalse(state.accepts(generation: second, destination: destination, currentDestination: destination))
        XCTAssertNil(state.route)
        XCTAssertNil(state.progress)
    }
    func testDestinationMismatchFailsClosed() {
        var state = NavigationRouteSession()
        let request = state.begin(origin: origin, destination: destination, reason: .stale)
        XCTAssertFalse(state.accepts(generation: request, destination: destination, currentDestination: origin))
        XCTAssertFalse(state.accepts(generation: request, destination: destination, currentDestination: nil))
    }

    func testLateResponseMatchesTheCurrentStopOnlyInsideOneMeter() {
        var state = NavigationRouteSession()
        let route = makeRoute(from: origin, bearing: 0, segments: 1, segmentMeters: 80)
        state.route = route
        let request = state.begin(origin: origin, destination: destination, reason: .stale,
                                  now: Date(timeIntervalSince1970: 50))
        let inside = GeoMath.destination(from: destination, bearing: 90, distance: 0.999)
        let outside = GeoMath.destination(from: destination, bearing: 90, distance: 1.001)
        XCTAssertLessThan(GeoMath.distance(from: destination, to: inside), 1)
        XCTAssertGreaterThanOrEqual(GeoMath.distance(from: destination, to: outside), 1)
        XCTAssertLessThan(GeoMath.distance(from: destination, to: outside), 1.01)
        XCTAssertTrue(state.accepts(generation: request, destination: inside, currentDestination: destination))
        XCTAssertFalse(state.accepts(generation: request, destination: outside, currentDestination: destination))
        state.invalidate()
        XCTAssertFalse(state.isRequestInFlight)
        XCTAssertEqual(state.route, route, "Cancelling the request keeps the route already on screen")
        XCTAssertFalse(state.accepts(generation: request, destination: destination, currentDestination: destination))
        state.finish(generation: request)
        XCTAssertEqual(state.route, route)
        XCTAssertNil(state.progress)
    }
    func testVisitInterruptPreservesAcceptedDwellButNotMissingTime() {
        var state = TourVisitSession()
        let date = Date(timeIntervalSince1970: 1000)
        for second in 0...10 {
            _ = state.active.update(distance: 0, accuracy: 3, timestamp: date.addingTimeInterval(Double(second)),
                now: date.addingTimeInterval(Double(second)), arrivalRadius: 35, departureRadius: 50, allowsDeparture: false)
        }
        state.interrupt()
        XCTAssertEqual(state.active.accumulatedVisitSeconds, 10)
        state.resetActive(held: true)
        XCTAssertEqual(state.active.accumulatedVisitSeconds, 0)
        XCTAssertTrue(state.active.isHeld)
    }

    func testPassiveInterruptDoesNotBankTimeInsideTheGPSGap() throws {
        var passive = WalkingProgressionPolicy()
        let date = Date(timeIntervalSince1970: 1000)
        for second in 0...10 {
            _ = passive.update(distance: 0, accuracy: 3, timestamp: date.addingTimeInterval(Double(second)),
                now: date.addingTimeInterval(Double(second)), arrivalRadius: 35, departureRadius: 50, allowsDeparture: false)
        }
        var state = TourVisitSession()
        state.passive["stop-2"] = passive
        state.interrupt()
        var resumed = try XCTUnwrap(state.passive["stop-2"])
        let resumedAt = date.addingTimeInterval(15)
        _ = resumed.update(distance: 0, accuracy: 3, timestamp: resumedAt, now: resumedAt,
            arrivalRadius: 35, departureRadius: 50, allowsDeparture: false)
        XCTAssertEqual(resumed.accumulatedVisitSeconds, 10,
                       "A pause inside the GPS gap must not count as time at the other stop")
        state.resetActive(held: false)
        XCTAssertEqual(state.passive["stop-2"]?.accumulatedVisitSeconds, 10)
        XCTAssertEqual(state.active.accumulatedVisitSeconds, 0)
    }
}
