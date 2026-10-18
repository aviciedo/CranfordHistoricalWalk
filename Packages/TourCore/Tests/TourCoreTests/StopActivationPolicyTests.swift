import XCTest
@testable import TourCore

final class StopActivationPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func decide(tracking: Bool = true, plaque: Bool = false, simulated: Bool = false,
                        distance: Double? = 10, accuracy: Double? = 5, age: TimeInterval? = 0,
                        radius: Double = 35) -> StopActivationDecision {
        StopActivationPolicy.decide(trackingReady: tracking, plaqueIsTracked: plaque, isSimulated: simulated,
                                   distanceMeters: distance, horizontalAccuracy: accuracy,
                                   locationTimestamp: age.map { now.addingTimeInterval(-$0) }, arrivalRadius: radius, now: now)
    }

    func testOnSiteMarkerRequiresGoodLocationAndTracking() {
        XCTAssertEqual(decide(), .allow(.onSiteARMarker))
        XCTAssertEqual(decide(tracking: false), .deny(.trackingNotReady))
    }

    func testUncertaintyMustFitInsideArrivalRadius() {
        XCTAssertEqual(decide(distance: 30, accuracy: 5), .allow(.onSiteARMarker))
        XCTAssertEqual(decide(distance: 31, accuracy: 5), .deny(.outsideStop))
        XCTAssertEqual(decide(distance: 0, accuracy: 25), .allow(.onSiteARMarker))
        XCTAssertEqual(decide(distance: 0, accuracy: 26), .deny(.weakLocation))
    }

    func testFarAwayMarkerCannotRecordAVisit() {
        XCTAssertEqual(decide(distance: 300), .deny(.outsideStop))
        XCTAssertEqual(decide(distance: nil), .deny(.outsideStop))
    }

    func testBadOrMissingAccuracyCannotRecordAVisit() {
        for accuracy in [Double(-1), 26, .nan, .infinity] {
            XCTAssertEqual(decide(accuracy: accuracy), .deny(.weakLocation))
        }
        XCTAssertEqual(decide(accuracy: nil), .deny(.weakLocation))
    }

    func testStaleMissingAndFutureLocationsAreRejected() {
        XCTAssertEqual(decide(age: 29), .allow(.onSiteARMarker))
        for age in [TimeInterval(30), 60, -6, .infinity, .nan] {
            XCTAssertEqual(decide(age: age), .deny(.waitingForLocation))
        }
        XCTAssertEqual(decide(age: nil), .deny(.waitingForLocation))
    }

    func testBadDistancesAndRadiiCannotRecordAVisit() {
        for distance in [Double(-1), .nan, .infinity] {
            XCTAssertEqual(decide(distance: distance), .deny(.outsideStop))
        }
        for radius in [Double(0), -1, .nan, .infinity] {
            XCTAssertEqual(decide(radius: radius), .deny(.outsideStop))
        }
    }

    func testCurrentlyTrackedPlaqueWorksDespiteBadOrMissingGPS() {
        XCTAssertEqual(decide(plaque: true, distance: 320, accuracy: 200, age: 500), .allow(.recognizedPlaque))
        XCTAssertEqual(decide(plaque: true, distance: nil, accuracy: nil, age: nil), .allow(.recognizedPlaque))
    }

    func testTrackedPlaqueStillNeedsARTracking() {
        XCTAssertEqual(decide(tracking: false, plaque: true), .deny(.trackingNotReady))
    }

    func testLostPlaqueDoesNotBypassAnIncorrectGPSPosition() {
        XCTAssertEqual(decide(plaque: false, distance: 320), .deny(.outsideStop))
    }

    func testPracticeNeverReturnsRealVisitEvidence() {
        XCTAssertEqual(decide(simulated: true), .allow(.simulation))
        XCTAssertEqual(decide(plaque: true, simulated: true, distance: 300), .allow(.simulation))
        XCTAssertEqual(decide(simulated: true, distance: 300), .deny(.outsideStop))
    }

    func testVisitRecordRetainsTimeStopAndActivationMethod() throws {
        let original = StopVisitRecord(stopID: "hpab-001", activatedAt: now, evidence: .recognizedPlaque)
        let decoded = try JSONDecoder().decode(StopVisitRecord.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded, original)
    }
}
