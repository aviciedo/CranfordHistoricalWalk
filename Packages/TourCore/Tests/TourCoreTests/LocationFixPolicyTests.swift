import XCTest
@testable import TourCore

final class LocationFixPolicyTests: XCTestCase {
    func testProximityIgnoresInvalidAndVeryPoorFixes() {
        XCTAssertTrue(LocationFixPolicy.acceptsProximityUpdate(horizontalAccuracy: 0))
        XCTAssertTrue(LocationFixPolicy.acceptsProximityUpdate(horizontalAccuracy: 100))
        XCTAssertFalse(LocationFixPolicy.acceptsProximityUpdate(horizontalAccuracy: 100.1))
        XCTAssertFalse(LocationFixPolicy.acceptsProximityUpdate(horizontalAccuracy: -1))
        XCTAssertFalse(LocationFixPolicy.acceptsProximityUpdate(horizontalAccuracy: .nan))
        XCTAssertEqual(LocationFixPolicy.proximityAccuracyLimitMeters, 100)
    }

    func testWalkedDistanceIgnoresJitterAndWeakGPS() {
        XCTAssertNil(LocationFixPolicy.walkedMeters(moved: 2, horizontalAccuracy: 0))
        XCTAssertEqual(LocationFixPolicy.walkedMeters(moved: 2.01, horizontalAccuracy: 0), 2.01)
        XCTAssertNil(LocationFixPolicy.walkedMeters(moved: 5, horizontalAccuracy: 10))
        XCTAssertEqual(LocationFixPolicy.walkedMeters(moved: 5.01, horizontalAccuracy: 10), 5.01)
        XCTAssertNil(LocationFixPolicy.walkedMeters(moved: 20, horizontalAccuracy: 40))
        XCTAssertEqual(LocationFixPolicy.walkedMeters(moved: 20.1, horizontalAccuracy: 40), 20.1)
        XCTAssertNil(LocationFixPolicy.walkedMeters(moved: 100, horizontalAccuracy: 40.1))
        XCTAssertNil(LocationFixPolicy.walkedMeters(moved: .nan, horizontalAccuracy: 5))
        XCTAssertNil(LocationFixPolicy.walkedMeters(moved: -10, horizontalAccuracy: 5))
        // The gate is `accuracy <= 40`, so a negative (invalid) fix still counts once the step is past 2 m.
        XCTAssertEqual(LocationFixPolicy.walkedMeters(moved: 3, horizontalAccuracy: -1), 3)
        XCTAssertEqual(LocationFixPolicy.poorAccuracyMeters, 40)
    }

    func testUsableFixRejectsNegativeAccuracyAndASixtySecondOldSample() {
        XCTAssertTrue(LocationFixPolicy.isUsable(horizontalAccuracy: 80, age: 0))
        XCTAssertTrue(LocationFixPolicy.isUsable(horizontalAccuracy: 0, age: 59.9))
        XCTAssertFalse(LocationFixPolicy.isUsable(horizontalAccuracy: 5, age: 60))
        XCTAssertFalse(LocationFixPolicy.isUsable(horizontalAccuracy: -1, age: 1))
        XCTAssertEqual(LocationFixPolicy.usableFixMaxAge, 60)
    }

    func testCompletionDistanceUsesMeasuredWalkOnlyAtFiftyMeters() {
        let jumped = TourCompletionDistance.select(walkedMeters: 0, routedMeters: 1800)
        XCTAssertEqual(jumped.meters, 1800)
        XCTAssertFalse(jumped.isMeasured)

        let almost = TourCompletionDistance.select(walkedMeters: 49.9, routedMeters: 1800)
        XCTAssertEqual(almost.meters, 1800)
        XCTAssertFalse(almost.isMeasured)

        let walked = TourCompletionDistance.select(walkedMeters: 50, routedMeters: 1800)
        XCTAssertEqual(walked.meters, 50)
        XCTAssertTrue(walked.isMeasured)

        let wandered = TourCompletionDistance.select(walkedMeters: 2400, routedMeters: 1800)
        XCTAssertEqual(wandered.meters, 2400)
        XCTAssertTrue(wandered.isMeasured)

        let missing = TourCompletionDistance.select(walkedMeters: .nan, routedMeters: 900)
        XCTAssertEqual(missing.meters, 900)
        XCTAssertFalse(missing.isMeasured)
        XCTAssertEqual(TourCompletionDistance.minimumMeasuredMeters, 50)
    }

    func testNarrationSkipClampsToTheTrack() {
        XCTAssertEqual(NarrationSeek.position(afterSkipping: -15, from: 10, duration: 180), 0)
        XCTAssertEqual(NarrationSeek.position(afterSkipping: 15, from: 20, duration: 180), 35)
        XCTAssertEqual(NarrationSeek.position(afterSkipping: 15, from: 170, duration: 180), 180)
        XCTAssertEqual(NarrationSeek.position(afterSkipping: 15, from: 100, duration: 50), 50)
        XCTAssertEqual(NarrationSeek.position(afterSkipping: 0, from: 0, duration: 0), 0)
    }

    func testDeveloperJumpLandsInsideTheArrivalRadiusAndOpensTheSign() {
        XCTAssertEqual(SimulatedArrival.jumpLandingDistance(arrivalRadius: 35), 8)
        XCTAssertEqual(SimulatedArrival.jumpLandingDistance(arrivalRadius: 12), 4)
        XCTAssertEqual(SimulatedArrival.jumpBearing, 200)

        for radius in [6.0, 9, 24, 35, 80] {
            let landing = SimulatedArrival.jumpLandingDistance(arrivalRadius: radius)
            XCTAssertGreaterThanOrEqual(landing, 0)
            XCTAssertLessThanOrEqual(landing, radius, "radius \(radius)")
            let point = GeoMath.destination(from: cranfordCenter, bearing: SimulatedArrival.jumpBearing, distance: landing)
            XCTAssertEqual(GeoMath.distance(from: cranfordCenter, to: point), landing, accuracy: 0.05)
            let departure = max(radius + 15, radius * 1.4)
            var machine = StopProximityStateMachine(arrivalRadius: radius, departureRadius: departure)
            XCTAssertEqual(machine.handle(.distanceUpdated(meters: landing)), [.presentSign], "radius \(radius)")
        }
    }
}
