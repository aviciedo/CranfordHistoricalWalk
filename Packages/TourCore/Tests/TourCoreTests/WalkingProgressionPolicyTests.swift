import XCTest
@testable import TourCore

final class WalkingProgressionPolicyTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000)
    private func fix(_ policy: inout WalkingProgressionPolicy, _ seconds: Double,
                     distance: Double = 0, accuracy: Double = 5, allowed: Bool = true) -> WalkingProgressionPolicy.Event? {
        let date = start.addingTimeInterval(seconds)
        return policy.update(distance: distance, accuracy: accuracy, timestamp: date, now: date,
                             arrivalRadius: 35, departureRadius: 50, allowsDeparture: allowed)
    }

    func testArrivalRequiresDistinctAccurateFixesAndThreeSeconds() {
        var policy = WalkingProgressionPolicy()
        XCTAssertNil(fix(&policy, 0))
        XCTAssertNil(fix(&policy, 0))
        XCTAssertNil(fix(&policy, 2))
        XCTAssertEqual(fix(&policy, 3), .arrived)
        XCTAssertNil(fix(&policy, 4))
        XCTAssertTrue(policy.hasArrived)
    }

    func testDepartureRequiresEntireErrorCircleOutsideBoundaryAndFiveSeconds() {
        var policy = WalkingProgressionPolicy(); policy.confirmArrival()
        XCTAssertNil(fix(&policy, 0, distance: 55)) // Boundary touches the circle.
        XCTAssertNil(fix(&policy, 3, distance: 60))
        XCTAssertNil(fix(&policy, 7, distance: 60))
        XCTAssertEqual(fix(&policy, 8, distance: 60), .departed)
        XCTAssertNil(fix(&policy, 14, distance: 60), "Departure is consumed once")
    }

    func testDepartureCannotHappenBeforeArrivalOrWhileHeld() {
        var policy = WalkingProgressionPolicy()
        XCTAssertNil(fix(&policy, 0, distance: 100))
        XCTAssertNil(fix(&policy, 6, distance: 100))
        policy.confirmArrival(); policy.isHeld = true
        XCTAssertNil(fix(&policy, 7, distance: 100))
        XCTAssertNil(fix(&policy, 13, distance: 100))
        policy.isHeld = false
        XCTAssertNil(fix(&policy, 14, distance: 100))
        XCTAssertEqual(fix(&policy, 19, distance: 100), .departed)
    }

    func testExploringInterruptsDepartureAndNeedsNewDwellOnMap() {
        var policy = WalkingProgressionPolicy(); policy.confirmArrival()
        XCTAssertNil(fix(&policy, 0, distance: 100))
        XCTAssertNil(fix(&policy, 4, distance: 100, allowed: false))
        XCTAssertNil(fix(&policy, 6, distance: 100))
        XCTAssertEqual(fix(&policy, 11, distance: 100), .departed)
    }

    func testWeakLocationAndReentryCancelDwell() {
        var policy = WalkingProgressionPolicy(); policy.confirmArrival()
        XCTAssertNil(fix(&policy, 0, distance: 100))
        XCTAssertNil(fix(&policy, 4, distance: 100, accuracy: 30))
        XCTAssertNil(fix(&policy, 5, distance: 100))
        XCTAssertNil(fix(&policy, 9, distance: 40))
        XCTAssertNil(fix(&policy, 10, distance: 100))
        XCTAssertEqual(fix(&policy, 15, distance: 100), .departed)
    }

    func testLongGapsAndExplicitSuspensionRestartArrivalEvidence() {
        var policy = WalkingProgressionPolicy()
        XCTAssertNil(fix(&policy, 0))
        XCTAssertNil(fix(&policy, 20))
        policy.interrupt()
        XCTAssertNil(fix(&policy, 23))
        XCTAssertEqual(fix(&policy, 26), .arrived)
    }

    func testStaleFutureInvalidAndOutOfOrderFixesCannotAdvance() {
        var policy = WalkingProgressionPolicy(); policy.confirmArrival()
        for (distance, accuracy) in [(Double.nan, 5.0), (100, -1), (100, .infinity)] {
            XCTAssertNil(fix(&policy, 0, distance: distance, accuracy: accuracy))
        }
        for age in [-6.0, 30, 100] {
            XCTAssertNil(policy.update(distance: 100, accuracy: 5, timestamp: start,
                now: start.addingTimeInterval(age), arrivalRadius: 35, departureRadius: 50, allowsDeparture: true))
        }
        XCTAssertNil(fix(&policy, 10, distance: 100))
        XCTAssertNil(fix(&policy, 9, distance: 100))
        XCTAssertEqual(fix(&policy, 15, distance: 100), .departed)
    }

    func testArrivalUncertaintyMustFitEntirelyInsideStop() {
        var policy = WalkingProgressionPolicy()
        XCTAssertNil(fix(&policy, 0, distance: 31))
        XCTAssertNil(fix(&policy, 4, distance: 31))
        XCTAssertFalse(policy.hasArrived)
        XCTAssertNil(fix(&policy, 5, distance: 30))
        XCTAssertEqual(fix(&policy, 8, distance: 30), .arrived)
    }

    func testLeavingTheCircleRestartsArrivalAndHoldDoesNotBlockIt() {
        var policy = WalkingProgressionPolicy()
        XCTAssertFalse(policy.isConfirmingArrival)
        XCTAssertNil(fix(&policy, 0))
        XCTAssertTrue(policy.isConfirmingArrival)
        XCTAssertNil(fix(&policy, 2, distance: 40))
        XCTAssertFalse(policy.isConfirmingArrival)
        XCTAssertNil(fix(&policy, 4))
        XCTAssertNil(fix(&policy, 6), "Time spent outside does not count toward the dwell")
        XCTAssertEqual(fix(&policy, 7), .arrived)
        XCTAssertFalse(policy.isConfirmingArrival)

        policy = WalkingProgressionPolicy()
        policy.isHeld = true
        XCTAssertNil(fix(&policy, 0))
        XCTAssertEqual(fix(&policy, 3), .arrived)
        XCTAssertNil(fix(&policy, 4, distance: 100))
        XCTAssertNil(fix(&policy, 9, distance: 100))
        XCTAssertTrue(policy.isHeld)
        XCTAssertTrue(policy.hasArrived)
    }

    func testBadRadiiAndAccuracyAboveTheCeilingRestartArrival() {
        let ceiling = StopActivationPolicy.maximumAccuracyMeters
        var policy = WalkingProgressionPolicy()
        XCTAssertNil(fix(&policy, 0, accuracy: ceiling))
        XCTAssertEqual(fix(&policy, 3, accuracy: ceiling), .arrived)

        policy = WalkingProgressionPolicy()
        policy.confirmArrival()
        XCTAssertNil(fix(&policy, 0, distance: 51 + ceiling, accuracy: ceiling))
        XCTAssertNil(fix(&policy, 4, distance: 50 + ceiling, accuracy: ceiling), "The error circle still touches the boundary")
        XCTAssertNil(fix(&policy, 9, distance: 51 + ceiling, accuracy: ceiling))
        XCTAssertEqual(fix(&policy, 14, distance: 51 + ceiling, accuracy: ceiling), .departed)

        policy = WalkingProgressionPolicy()
        XCTAssertNil(fix(&policy, 0))
        let badAt = start.addingTimeInterval(1)
        XCTAssertNil(policy.update(distance: 0, accuracy: ceiling + 0.1, timestamp: badAt, now: badAt,
            arrivalRadius: 35, departureRadius: 50, allowsDeparture: true))
        XCTAssertFalse(policy.isConfirmingArrival)
        for radii in [(35.0, 35.0), (0.0, 50.0), (Double.nan, 50.0), (35.0, .infinity)] {
            XCTAssertNil(policy.update(distance: 0, accuracy: ceiling, timestamp: badAt, now: badAt,
                arrivalRadius: radii.0, departureRadius: radii.1, allowsDeparture: true))
            XCTAssertFalse(policy.isConfirmingArrival)
            XCTAssertFalse(policy.hasArrived)
        }
        XCTAssertNil(fix(&policy, 2))
        XCTAssertNil(fix(&policy, 4), "The rejected sample must not leave the original dwell running")
        XCTAssertEqual(fix(&policy, 5), .arrived)
    }

    func testExactlyTenSecondsStillDepartsAndALongerGapRestartsTheDwell() {
        var policy = WalkingProgressionPolicy()
        policy.confirmArrival()
        XCTAssertNil(fix(&policy, 0, distance: 100))
        XCTAssertEqual(fix(&policy, 10, distance: 100), .departed)

        policy = WalkingProgressionPolicy()
        policy.confirmArrival()
        XCTAssertNil(fix(&policy, 0, distance: 100))
        XCTAssertNil(fix(&policy, 11, distance: 100))
        XCTAssertNil(fix(&policy, 15, distance: 100))
        XCTAssertEqual(fix(&policy, 16, distance: 100), .departed)
    }
}
