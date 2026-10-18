import XCTest
@testable import TourCore

final class PlaqueArrivalPolicyTests: XCTestCase {
    func testMatchingPlaqueConfirmsAndOpensTheSign() {
        let decision = PlaqueArrivalPolicy.confirmation(
            tourInProgress: true,
            currentStopID: "hpab-001",
            requestedStopID: "hpab-001",
            stopHasPlaqueReference: true,
            hasManuallyDismissed: false,
            isSignPresented: false
        )
        XCTAssertEqual(decision, .confirm(openSign: true))
    }

    func testAlreadyOpenSignIsConfirmedWithoutOpeningAgain() {
        let decision = PlaqueArrivalPolicy.confirmation(
            tourInProgress: true,
            currentStopID: "hpab-001",
            requestedStopID: "hpab-001",
            stopHasPlaqueReference: true,
            hasManuallyDismissed: false,
            isSignPresented: true
        )
        XCTAssertEqual(decision, .confirm(openSign: false))
    }

    func testWrongStopUnusablePlateAndDismissedVisitAreIgnored() {
        let base = (
            tourInProgress: true,
            currentStopID: Optional("hpab-001"),
            requestedStopID: "hpab-001",
            stopHasPlaqueReference: true,
            hasManuallyDismissed: Optional(false),
            isSignPresented: false
        )
        XCTAssertEqual(PlaqueArrivalPolicy.confirmation(
            tourInProgress: base.tourInProgress,
            currentStopID: base.currentStopID,
            requestedStopID: "hpab-002",
            stopHasPlaqueReference: base.stopHasPlaqueReference,
            hasManuallyDismissed: base.hasManuallyDismissed,
            isSignPresented: base.isSignPresented
        ), .ignore, "a plate for another stop must not complete the current one")

        XCTAssertEqual(PlaqueArrivalPolicy.confirmation(
            tourInProgress: base.tourInProgress,
            currentStopID: base.currentStopID,
            requestedStopID: base.requestedStopID,
            stopHasPlaqueReference: false,
            hasManuallyDismissed: base.hasManuallyDismissed,
            isSignPresented: base.isSignPresented
        ), .ignore)

        XCTAssertEqual(PlaqueArrivalPolicy.confirmation(
            tourInProgress: base.tourInProgress,
            currentStopID: base.currentStopID,
            requestedStopID: base.requestedStopID,
            stopHasPlaqueReference: base.stopHasPlaqueReference,
            hasManuallyDismissed: true,
            isSignPresented: base.isSignPresented
        ), .ignore, "closing the sign this visit must win over a still-tracked plate")

        XCTAssertEqual(PlaqueArrivalPolicy.confirmation(
            tourInProgress: false,
            currentStopID: base.currentStopID,
            requestedStopID: base.requestedStopID,
            stopHasPlaqueReference: base.stopHasPlaqueReference,
            hasManuallyDismissed: base.hasManuallyDismissed,
            isSignPresented: base.isSignPresented
        ), .ignore)

        XCTAssertEqual(PlaqueArrivalPolicy.confirmation(
            tourInProgress: base.tourInProgress,
            currentStopID: nil,
            requestedStopID: base.requestedStopID,
            stopHasPlaqueReference: base.stopHasPlaqueReference,
            hasManuallyDismissed: base.hasManuallyDismissed,
            isSignPresented: base.isSignPresented
        ), .ignore)

        XCTAssertEqual(PlaqueArrivalPolicy.confirmation(
            tourInProgress: base.tourInProgress,
            currentStopID: base.currentStopID,
            requestedStopID: base.requestedStopID,
            stopHasPlaqueReference: base.stopHasPlaqueReference,
            hasManuallyDismissed: nil,
            isSignPresented: base.isSignPresented
        ), .ignore, "no proximity machine means the tour is not ready to arrive")
    }

    func testConfirmedPlaqueIgnoresEveryFollowingGPSFix() {
        for accuracy in [-1.0, 0, 5, 100, 320, Double.nan, Double.infinity] {
            XCTAssertFalse(
                PlaqueArrivalPolicy.shouldApplyLocationSample(
                    plaqueConfirmedForCurrentStop: true,
                    horizontalAccuracy: accuracy
                ),
                "accuracy \(accuracy) must not dismiss a recognized plaque"
            )
        }
    }

    func testUnconfirmedArrivalStillRejectsUnusableFixes() {
        XCTAssertTrue(PlaqueArrivalPolicy.shouldApplyLocationSample(plaqueConfirmedForCurrentStop: false, horizontalAccuracy: 0))
        XCTAssertTrue(PlaqueArrivalPolicy.shouldApplyLocationSample(plaqueConfirmedForCurrentStop: false, horizontalAccuracy: 5))
        XCTAssertTrue(PlaqueArrivalPolicy.shouldApplyLocationSample(
            plaqueConfirmedForCurrentStop: false,
            horizontalAccuracy: PlaqueArrivalPolicy.maximumHorizontalAccuracyMeters
        ))
        XCTAssertFalse(PlaqueArrivalPolicy.shouldApplyLocationSample(plaqueConfirmedForCurrentStop: false, horizontalAccuracy: -1))
        XCTAssertFalse(PlaqueArrivalPolicy.shouldApplyLocationSample(plaqueConfirmedForCurrentStop: false, horizontalAccuracy: 100.1))
        XCTAssertFalse(PlaqueArrivalPolicy.shouldApplyLocationSample(plaqueConfirmedForCurrentStop: false, horizontalAccuracy: .nan))
        XCTAssertFalse(PlaqueArrivalPolicy.shouldApplyLocationSample(plaqueConfirmedForCurrentStop: false, horizontalAccuracy: .infinity))
    }
}
