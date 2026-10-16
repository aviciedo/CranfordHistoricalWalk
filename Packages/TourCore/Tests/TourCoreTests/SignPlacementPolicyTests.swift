import XCTest
@testable import TourCore

final class SignPlacementPolicyTests: XCTestCase {
    func testSearchingUntilTimeoutThenGeoFallback() {
        var input = presentedMill()
        XCTAssertEqual(SignPlacementPolicy.mode(input), .searchingForPlaque)
        XCTAssertEqual(
            SignPlacementPolicy.plaqueHint(mode: .searchingForPlaque, stopHasPlaqueReference: true, proximity: .signPresented),
            "Look for the mill plaque on the door"
        )
        XCTAssertTrue(SignPlacementPolicy.shouldKeepNavigationArrows(mode: .searchingForPlaque, insideArrivalRadius: true))

        input.searchElapsed = SignPlacementPolicy.searchTimeout
        XCTAssertEqual(SignPlacementPolicy.mode(input), .geoFallback)
        XCTAssertNil(SignPlacementPolicy.plaqueHint(mode: .geoFallback, stopHasPlaqueReference: true, proximity: .signPresented))
        XCTAssertFalse(SignPlacementPolicy.shouldKeepNavigationArrows(mode: .geoFallback, insideArrivalRadius: true))
    }

    func testPlaqueDetectionLocksCardToPlate() {
        var input = presentedMill()
        input.plaqueDetected = true
        XCTAssertEqual(SignPlacementPolicy.mode(input), .plaqueAnchored)
        XCTAssertNil(SignPlacementPolicy.plaqueHint(mode: .plaqueAnchored, stopHasPlaqueReference: true, proximity: .signPresented))
    }

    func testManualDismissHidesTheCardBeforeProximityCatchesUp() {
        var input = presentedMill()
        input.hasManuallyDismissed = true
        input.proximity = .signPresented
        input.isSignRequested = true
        input.plaqueDetected = true
        XCTAssertEqual(SignPlacementPolicy.mode(input), .hidden)
    }

    func testSearchContinuesUntilTheTimeout() {
        var input = presentedMill()
        input.searchElapsed = SignPlacementPolicy.searchTimeout - 0.001
        XCTAssertEqual(SignPlacementPolicy.mode(input), .searchingForPlaque)
        XCTAssertTrue(SignPlacementPolicy.shouldKeepNavigationArrows(mode: .geoFallback, insideArrivalRadius: false))
    }

    func testDismissedThisVisitDoesNotReshowOnRetrack() {
        var input = presentedMill()
        input.hasManuallyDismissed = true
        input.proximity = .signDismissed
        input.isSignRequested = false
        input.plaqueDetected = true
        XCTAssertEqual(SignPlacementPolicy.mode(input), .hidden)

        // Same visit, still inside 50 m, plaque still in view.
        input.isSignRequested = false
        input.proximity = .signDismissed
        XCTAssertEqual(SignPlacementPolicy.mode(input), .hidden)
        XCTAssertNil(SignPlacementPolicy.plaqueHint(mode: .hidden, stopHasPlaqueReference: true, proximity: .signDismissed))
    }

    func testUnsupportedOrMissingReferenceFallsBackWithoutSearching() {
        var input = presentedMill()
        input.imageTrackingAvailable = false
        XCTAssertEqual(SignPlacementPolicy.mode(input), .geoFallback)

        input.imageTrackingAvailable = true
        input.stopHasPlaqueReference = false
        XCTAssertEqual(SignPlacementPolicy.mode(input), .geoFallback)
    }

    func testNoCardUntilStateMachineRequestsOne() {
        var input = presentedMill()
        input.isSignRequested = false
        input.proximity = .approaching
        XCTAssertEqual(SignPlacementPolicy.mode(input), .hidden)
        XCTAssertEqual(
            SignPlacementPolicy.plaqueHint(mode: .hidden, stopHasPlaqueReference: true, proximity: .approaching),
            SignPlacementPolicy.millPlaqueHint,
            "Look-around at the mill still gets the restrained plaque hint"
        )
    }

    func testCompletedAndMissingProximityStayHidden() {
        var input = presentedMill()
        input.proximity = .completed
        input.plaqueDetected = true
        XCTAssertEqual(SignPlacementPolicy.mode(input), .hidden)

        input.proximity = nil
        XCTAssertEqual(SignPlacementPolicy.mode(input), .hidden)
    }

    func testAssumedWidthAndAboveFacadeOffset() {
        XCTAssertEqual(SignPlacementPolicy.assumedPlaqueWidthMeters, 0.18, accuracy: 0.0001)
        XCTAssertEqual(SignPlacementPolicy.millReferenceImageName, "droeschers-mill-plaque")
        let offset = PlaqueCardOffset.aboveFacade
        XCTAssertEqual(offset.upMeters, 3.80, accuracy: 0.001)
        XCTAssertEqual(offset.outMeters, 0.40, accuracy: 0.001)
        let local = offset.imageLocalTranslation
        XCTAssertEqual(local.x, 0, accuracy: 0.001)
        XCTAssertEqual(local.y, 0.40, accuracy: 0.001)
        XCTAssertEqual(local.z, -3.80, accuracy: 0.001, "up the wall is −Z in ARKit image space")
    }

    func testHysteresisRadiiUnchanged() {
        let stop = makeStop(arrival: 35, departure: 50)
        XCTAssertEqual(stop.arrivalRadius, 35)
        XCTAssertEqual(stop.effectiveDepartureRadius, 50)
        var sm = StopProximityStateMachine(stop: stop)
        XCTAssertEqual(sm.handle(.distanceUpdated(meters: 35)), [.presentSign])
        XCTAssertEqual(sm.handle(.userClosedSign), [.dismissSign])
        XCTAssertEqual(sm.state, .signDismissed)
        XCTAssertEqual(sm.handle(.distanceUpdated(meters: 20)), [])
        XCTAssertTrue(sm.hasManuallyDismissed)
    }

    private func presentedMill() -> SignPlacementInput {
        SignPlacementInput(
            proximity: .signPresented,
            isSignRequested: true,
            hasManuallyDismissed: false,
            stopHasPlaqueReference: true,
            imageTrackingAvailable: true,
            plaqueDetected: false,
            searchElapsed: 1
        )
    }
}
