import XCTest
@testable import TourCore

final class SignPlacementPolicyTests: XCTestCase {
    func testParkPlaqueResolvesToGreystoneRatherThanStaleMillDestination() throws {
        let stops = try HistoricalStopDecoder.decode(Fixtures.data("historical_stops")).stops
        let park = try XCTUnwrap(SignPlacementPolicy.recognizedStop(
            imageName: SignPlacementPolicy.parkReferenceImageName, isTracked: true,
            trackingReady: true, stops: stops))
        var walk = TourProgress(stopIDs: stops.map(\.id))
        walk.start()
        XCTAssertNotEqual(walk.currentStopID, park.id)
        XCTAssertTrue(walk.selectStop(withID: park.id))
        XCTAssertEqual(walk.currentStopID, "hpab-002")
        XCTAssertEqual(walk.completedCount, 0)
        XCTAssertFalse(SignPlacementPolicy.matchesReference(park.plaque?.referenceImageName,
                        expectedName: SignPlacementPolicy.millReferenceImageName))
    }

    func testUntrackedUnknownAmbiguousOrLimitedTrackingCannotSelectSite() throws {
        let stops = try HistoricalStopDecoder.decode(Fixtures.data("historical_stops")).stops
        let name = SignPlacementPolicy.parkReferenceImageName
        XCTAssertNil(SignPlacementPolicy.recognizedStop(imageName: name, isTracked: false, trackingReady: true, stops: stops))
        XCTAssertNil(SignPlacementPolicy.recognizedStop(imageName: name, isTracked: true, trackingReady: false, stops: stops))
        for invalid in [nil, "", "unregistered-plaque"] as [String?] {
            XCTAssertNil(SignPlacementPolicy.recognizedStop(imageName: invalid, isTracked: true, trackingReady: true, stops: stops))
        }
        let park = try XCTUnwrap(stops.first { $0.plaque?.referenceImageName == name })
        XCTAssertNil(SignPlacementPolicy.recognizedStop(imageName: name, isTracked: true, trackingReady: true, stops: stops + [park]))
    }

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
        XCTAssertEqual(SignPlacementPolicy.plaqueHint(mode: .plaqueAnchored, stopHasPlaqueReference: true, proximity: .signPresented),
                       "Plaque recognized — the historical sign is just above it")
    }

    func testRecognizedPlaqueAnchorsEvenWhenGPSIsStillApproaching() {
        var input = presentedMill()
        input.proximity = .approaching
        input.plaqueDetected = true
        XCTAssertEqual(SignPlacementPolicy.mode(input), .plaqueAnchored)
    }

    func testLostPlaqueTrackingReturnsToFallbackAfterTimeout() {
        var input = presentedMill()
        input.plaqueDetected = true
        XCTAssertEqual(SignPlacementPolicy.mode(input), .plaqueAnchored)
        input.plaqueDetected = false
        input.searchElapsed = SignPlacementPolicy.searchTimeout
        XCTAssertEqual(SignPlacementPolicy.mode(input), .geoFallback)
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

    func testInitialWidthAndVisibleAbovePlaqueOffset() {
        XCTAssertEqual(SignPlacementPolicy.assumedPlaqueWidthMeters, 0.18, accuracy: 0.0001)
        XCTAssertEqual(SignPlacementPolicy.millReferenceImageName, "droeschers-mill-plaque")
        let offset = PlaqueCardOffset.abovePlaque
        XCTAssertEqual(offset.upMeters, 0.25, accuracy: 0.001)
        XCTAssertEqual(offset.outMeters, 0.08, accuracy: 0.001)
        let local = offset.imageLocalTranslation
        XCTAssertEqual(local.x, 0, accuracy: 0.001)
        XCTAssertEqual(local.y, 0.08, accuracy: 0.001)
        XCTAssertEqual(local.z, -0.25, accuracy: 0.001, "up the wall is −Z in ARKit image space")
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
