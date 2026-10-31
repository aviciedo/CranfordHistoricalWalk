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
}
