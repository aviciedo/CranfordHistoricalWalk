import XCTest
@testable import TourCore

/// Independent on-site coordinates supplied by the tour creator, not derived from the catalog.
final class StopPositionRegressionTests: XCTestCase {
    private let fieldPositions = [
        GeoCoordinate(latitude: 40.650249, longitude: -74.301047),
        GeoCoordinate(latitude: 40.6524, longitude: -74.2990)
    ]
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testFirstTwoDestinationsMatchTheSuppliedOnSiteLocations() throws {
        let stops = try HistoricalStopDecoder.decode(Fixtures.data("historical_stops")).stops
        XCTAssertEqual(Array(stops.prefix(2)).map(\.id), ["hpab-001", "hpab-002"])
        for (stop, location) in zip(stops, fieldPositions) {
            XCTAssertLessThan(GeoMath.distance(from: stop.coordinate, to: location), 1, stop.name)
        }
        let separation = GeoMath.distance(from: stops[0].coordinate, to: stops[1].coordinate)
        XCTAssertGreaterThan(separation, 290)
        XCTAssertLessThan(separation, 300, "The supplied points are about 294 m apart; this is not a walking-route measurement")
    }

    func testAnAccurateFixAtEachSuppliedLocationRevealsItsMarkerAndAllowsActivation() throws {
        let stops = try HistoricalStopDecoder.decode(Fixtures.data("historical_stops")).stops
        for (stop, location) in zip(stops, fieldPositions) {
            let distance = GeoMath.distance(from: location, to: stop.coordinate)
            var machine = StopProximityStateMachine(stop: stop)
            XCTAssertEqual(machine.handle(.distanceUpdated(meters: distance)), [.presentSign], stop.name)
            XCTAssertEqual(machine.state, .signPresented)
            XCTAssertEqual(StopActivationPolicy.decide(
                trackingReady: true, plaqueIsTracked: false, isSimulated: false,
                distanceMeters: distance, horizontalAccuracy: 5, locationTimestamp: now,
                arrivalRadius: stop.arrivalRadius, now: now
            ), .allow(.onSiteARMarker), stop.name)
        }
    }

    func testBeingAtOneStopDoesNotActivateTheOther() throws {
        let stops = try HistoricalStopDecoder.decode(Fixtures.data("historical_stops")).stops
        for index in 0..<2 {
            let otherStop = stops[1 - index]
            let distance = GeoMath.distance(from: fieldPositions[index], to: otherStop.coordinate)
            var machine = StopProximityStateMachine(stop: otherStop)
            XCTAssertTrue(machine.handle(.distanceUpdated(meters: distance)).isEmpty)
            XCTAssertEqual(StopActivationPolicy.decide(
                trackingReady: true, plaqueIsTracked: false, isSimulated: false,
                distanceMeters: distance, horizontalAccuracy: 5, locationTimestamp: now,
                arrivalRadius: otherStop.arrivalRadius, now: now
            ), .deny(.outsideStop))
        }
    }

    func testRemainingRouteDistanceReachesZeroAtTheSuppliedSecondStop() throws {
        let stops = try HistoricalStopDecoder.decode(Fixtures.data("historical_stops")).stops
        // Deterministic test geometry only; Google supplies the real street route and ETA.
        let route = WalkingRoute.straightLineEstimate(from: stops[0].coordinate, to: stops[1].coordinate)
        let progress = RouteProgressCalculator.progress(along: route, userLocation: fieldPositions[1])
        XCTAssertLessThan(progress.distanceFromRoute, 1)
        XCTAssertEqual(progress.remainingMeters, 0, accuracy: 1)
        XCTAssertEqual(progress.remainingSeconds, 0, accuracy: 1)
    }
}
