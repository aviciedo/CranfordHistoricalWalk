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

    func testVisitNeedsThreeMinutesOfAccurateOnSiteTime() {
        var policy = WalkingProgressionPolicy()
        for seconds in 0..<180 {
            let event = fix(&policy, Double(seconds))
            XCTAssertNotEqual(event, .visitReady)
        }
        XCTAssertEqual(fix(&policy, 180), .visitReady)
        XCTAssertNil(fix(&policy, 181))
    }

    func testAwayWeakGPSAndGapsDoNotAddVisitTime() {
        var policy = WalkingProgressionPolicy()
        for seconds in 0...60 { _ = fix(&policy, Double(seconds)) }
        for seconds in 61...120 { _ = fix(&policy, Double(seconds), distance: 100, allowed: false) }
        for seconds in 121...150 { _ = fix(&policy, Double(seconds), accuracy: 50) }
        XCTAssertEqual(policy.accumulatedVisitSeconds, 60)
        _ = fix(&policy, 200)
        XCTAssertEqual(policy.accumulatedVisitSeconds, 60, "A signal gap must not count as presence")
        for seconds in 201..<320 { XCTAssertNotEqual(fix(&policy, Double(seconds)), .visitReady) }
        XCTAssertEqual(fix(&policy, 320), .visitReady)
    }

    func testPausedTimeDoesNotCountEvenWhenResumeIsWithinGPSGapLimit() {
        var policy = WalkingProgressionPolicy()
        for seconds in 0...60 { _ = fix(&policy, Double(seconds)) }
        policy.interrupt()
        XCTAssertNil(fix(&policy, 65))
        XCTAssertEqual(policy.accumulatedVisitSeconds, 60)
        for seconds in 66..<185 { XCTAssertNotEqual(fix(&policy, Double(seconds)), .visitReady) }
        XCTAssertEqual(fix(&policy, 185), .visitReady)
    }

    func testLeavingTowardNextStopBypassesDwellButWrongWayDoesNot() {
        var policy = WalkingProgressionPolicy()
        func update(_ time: Double, _ distance: Double, _ remaining: Double) -> WalkingProgressionPolicy.Event? {
            let date = start.addingTimeInterval(time)
            return policy.update(distance: distance, accuracy: 3, timestamp: date, now: date,
                arrivalRadius: 35, departureRadius: 50, allowsDeparture: true, nextStopDistance: remaining)
        }
        XCTAssertNil(update(0, 0, 200))
        XCTAssertEqual(update(3, 0, 200), .arrived)
        XCTAssertNil(update(4, 60, 230))
        XCTAssertNil(update(9, 65, 235))
        XCTAssertNil(update(10, 60, 180))
        XCTAssertEqual(update(15, 65, 170), .departed)
        XCTAssertLessThan(policy.accumulatedVisitSeconds, 180)
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

    func testVisitClockAcceptsTheAccuracyLimitAndIgnoresTheNextMillimeter() {
        var policy = WalkingProgressionPolicy()
        for seconds in 0...180 {
            XCTAssertNotEqual(fix(&policy, Double(seconds), accuracy: 25.1), .visitReady)
        }
        XCTAssertEqual(policy.accumulatedVisitSeconds, 0)
        for seconds in 181..<361 {
            XCTAssertNotEqual(fix(&policy, Double(seconds), accuracy: 25), .visitReady)
        }
        XCTAssertEqual(fix(&policy, 361, accuracy: 25), .visitReady)
    }

    func testLeavingTowardNextRequiresEightMetersOrTheAccuracy() {
        var policy = WalkingProgressionPolicy()
        func update(_ time: Double, _ distance: Double, _ remaining: Double, _ accuracy: Double = 3) -> WalkingProgressionPolicy.Event? {
            let date = start.addingTimeInterval(time)
            return policy.update(distance: distance, accuracy: accuracy, timestamp: date, now: date,
                arrivalRadius: 35, departureRadius: 50, allowsDeparture: true, nextStopDistance: remaining)
        }
        XCTAssertNil(update(0, 0, 100))
        XCTAssertEqual(update(3, 0, 100), .arrived)
        XCTAssertNil(update(4, 60, 92.001))
        XCTAssertNil(update(9, 65, 92.001))
        XCTAssertNil(update(10, 60, .nan))
        XCTAssertNil(update(15, 65, -1))
        XCTAssertNil(update(16, 60, 92))
        XCTAssertEqual(update(21, 65, 92), .departed)

        policy = WalkingProgressionPolicy()
        XCTAssertNil(update(30, 0, 100, 10))
        XCTAssertEqual(update(33, 0, 100, 10), .arrived)
        XCTAssertNil(update(34, 70, 90.001, 10))
        XCTAssertNil(update(39, 75, 90.001, 10))
        XCTAssertNil(update(40, 70, 90, 10))
        XCTAssertEqual(update(45, 75, 90, 10), .departed)
    }

    func testArrivalUncertaintyMustFitEntirelyInsideStop() {
        var policy = WalkingProgressionPolicy()
        XCTAssertNil(fix(&policy, 0, distance: 31))
        XCTAssertNil(fix(&policy, 4, distance: 31))
        XCTAssertFalse(policy.hasArrived)
        XCTAssertNil(fix(&policy, 5, distance: 30))
        XCTAssertEqual(fix(&policy, 8, distance: 30), .arrived)
    }
}
