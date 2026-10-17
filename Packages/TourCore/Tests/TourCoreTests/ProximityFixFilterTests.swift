import XCTest
@testable import TourCore

final class ProximityFixFilterTests: XCTestCase {
    private let arrival = 35.0
    private let departure = 50.0

    func testFreshnessRejectsCachedAndFutureFixes() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertTrue(ProximityFixFilter.isFresh(timestamp: now.addingTimeInterval(-1), now: now))
        XCTAssertTrue(ProximityFixFilter.isFresh(timestamp: now.addingTimeInterval(-14.9), now: now))
        XCTAssertFalse(ProximityFixFilter.isFresh(timestamp: now.addingTimeInterval(-15), now: now))
        XCTAssertFalse(ProximityFixFilter.isFresh(timestamp: now.addingTimeInterval(-120), now: now))
        XCTAssertTrue(ProximityFixFilter.isFresh(timestamp: now.addingTimeInterval(4), now: now))
        XCTAssertFalse(ProximityFixFilter.isFresh(timestamp: now.addingTimeInterval(30), now: now))
    }

    func testSloppyFixInsideReportedRadiusDoesNotCountAsArrival() {
        // Reported 20 m from the stop, but ±50 m — the visitor may still be well outside.
        let distance = ProximityFixFilter.distanceToApply(
            reportedMeters: 20,
            horizontalAccuracy: 50,
            state: .approaching,
            arrivalRadius: arrival,
            departureRadius: departure
        )
        XCTAssertNil(distance)
    }

    func testConfidentFixInsideArrivalRadiusIsApplied() {
        let distance = ProximityFixFilter.distanceToApply(
            reportedMeters: 20,
            horizontalAccuracy: 10,
            state: .approaching,
            arrivalRadius: arrival,
            departureRadius: departure
        )
        XCTAssertEqual(distance, 20)
    }

    func testFixClearlyOutsideArrivalIsStillApplied() {
        let distance = ProximityFixFilter.distanceToApply(
            reportedMeters: 80,
            horizontalAccuracy: 15,
            state: .approaching,
            arrivalRadius: arrival,
            departureRadius: departure
        )
        XCTAssertEqual(distance, 80)
    }

    func testSloppyFixBeyondDepartureDoesNotCountAsLeaving() {
        // Reported 70 m away with ±40 m accuracy still overlaps the 50 m departure radius.
        let distance = ProximityFixFilter.distanceToApply(
            reportedMeters: 70,
            horizontalAccuracy: 40,
            state: .signPresented,
            arrivalRadius: arrival,
            departureRadius: departure
        )
        XCTAssertNil(distance)
    }

    func testConfidentFixBeyondDepartureIsApplied() {
        let distance = ProximityFixFilter.distanceToApply(
            reportedMeters: 70,
            horizontalAccuracy: 5,
            state: .signPresented,
            arrivalRadius: arrival,
            departureRadius: departure
        )
        XCTAssertEqual(distance, 70)
    }

    func testInsideDepartureWhileSignIsUpIsAppliedUnchanged() {
        let distance = ProximityFixFilter.distanceToApply(
            reportedMeters: 40,
            horizontalAccuracy: 10,
            state: .signPresented,
            arrivalRadius: arrival,
            departureRadius: departure
        )
        XCTAssertEqual(distance, 40)
    }

    func testDismissedStateUsesTheSameDepartureConfidence() {
        XCTAssertNil(ProximityFixFilter.distanceToApply(
            reportedMeters: 80,
            horizontalAccuracy: 40,
            state: .signDismissed,
            arrivalRadius: arrival,
            departureRadius: departure
        ))
        XCTAssertEqual(ProximityFixFilter.distanceToApply(
            reportedMeters: 80,
            horizontalAccuracy: 5,
            state: .signDismissed,
            arrivalRadius: arrival,
            departureRadius: departure
        ), 80)
    }
}
