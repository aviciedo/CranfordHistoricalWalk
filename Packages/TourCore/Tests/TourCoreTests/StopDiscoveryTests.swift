import XCTest
@testable import TourCore

final class StopDiscoveryTests: XCTestCase {
    func testPlaqueReferencesCannotUnlockEachOthersStops() {
        let mill = SignPlacementPolicy.millReferenceImageName
        let park = SignPlacementPolicy.parkReferenceImageName
        XCTAssertTrue(SignPlacementPolicy.matchesReference(park, expectedName: park))
        XCTAssertFalse(SignPlacementPolicy.matchesReference(mill, expectedName: park))
        XCTAssertFalse(SignPlacementPolicy.matchesReference(park, expectedName: mill))
        XCTAssertFalse(SignPlacementPolicy.matchesReference(nil, expectedName: park))
        XCTAssertFalse(SignPlacementPolicy.matchesReference(park, expectedName: nil))
        XCTAssertFalse(SignPlacementPolicy.matchesReference("", expectedName: ""))
        XCTAssertTrue(SignPlacementPolicy.discoveryHint(referenceImageName: park).contains("Cranford Park"))
        XCTAssertFalse(SignPlacementPolicy.discoveryHint(referenceImageName: park).contains("doors"))
    }

    func testGreystoneBonusIsAbovePlaqueRatherThanAtMillWindows() throws {
        let layout = WindowBonusLayout.abovePlaque
        let offset = try XCTUnwrap(layout.translation(plaqueWidthMeters: SignPlacementPolicy.assumedParkReferenceWidthMeters))
        XCTAssertEqual(offset.x, 0)
        XCTAssertLessThan(offset.z, 0, "Negative image Z places the extra above the plaque")
        XCTAssertGreaterThan(offset.y, 0, "Card sits off the wall")
        XCTAssertNotEqual(layout, WindowBonusLayout())
    }

    func testArrivalOffersStoryOnceWithoutRecordingOrStartingNarration() {
        var discovery = StopDiscovery()
        XCTAssertTrue(discovery.arrive())
        XCTAssertEqual(discovery.stage, .story)
        XCTAssertFalse(discovery.hasVerifiedPlaque)
        XCTAssertFalse(discovery.hasFinishedStory)
        XCTAssertFalse(discovery.arrive(), "Repeated fixes cannot reopen a dismissed reading screen")
    }

    func testRecognitionBeforeReadingAndExplicitDiscoveryCannotUnlock() {
        var discovery = StopDiscovery()
        discovery.arrive()
        XCTAssertFalse(discovery.beginDiscovery())
        XCTAssertFalse(discovery.recognizePlaque(isMatching: true, trackingReady: true, isSimulated: false))
        discovery.narrationStarted()
        XCTAssertEqual(discovery.stage, .listening)
        XCTAssertFalse(discovery.hasVerifiedPlaque)
        discovery.finishStory()
        XCTAssertTrue(discovery.canContinue)
        XCTAssertTrue(discovery.canOfferDiscovery)
        XCTAssertFalse(discovery.recognizePlaque(isMatching: true, trackingReady: true, isSimulated: false))
    }

    func testOptionalDiscoveryDoesNotPreventContinuingAfterReading() {
        var discovery = StopDiscovery()
        discovery.openStory()
        discovery.finishStory()
        XCTAssertEqual(discovery.stage, .readyForDiscovery)
        XCTAssertTrue(discovery.canContinue)
        XCTAssertFalse(discovery.hasVerifiedPlaque)
    }

    func testNarrationCompletionAloneDoesNotUnlockTheBonus() {
        var discovery = StopDiscovery()
        discovery.arrive()
        discovery.narrationStarted()
        discovery.finishStory()
        XCTAssertFalse(discovery.hasVerifiedPlaque)
        XCTAssertTrue(discovery.beginDiscovery())
        XCTAssertFalse(discovery.recognizePlaque(isMatching: false, trackingReady: true, isSimulated: false))
        XCTAssertFalse(discovery.recognizePlaque(isMatching: true, trackingReady: false, isSimulated: false))
        XCTAssertTrue(discovery.recognizePlaque(isMatching: true, trackingReady: true, isSimulated: false))
        XCTAssertEqual(discovery.stage, .unlocked)
        XCTAssertTrue(discovery.hasVerifiedPlaque)
        XCTAssertFalse(discovery.isPracticeUnlock)
        XCTAssertFalse(discovery.recognizePlaque(isMatching: true, trackingReady: true, isSimulated: false))
        discovery.finishStory()
        discovery.openStory()
        XCTAssertEqual(discovery.stage, .unlocked)
    }

    func testPracticeAndTourResetRemainDistinctFromRealVerification() {
        var discovery = StopDiscovery()
        discovery.finishStory()
        discovery.beginDiscovery()
        XCTAssertTrue(discovery.recognizePlaque(isMatching: true, trackingReady: true, isSimulated: true))
        XCTAssertTrue(discovery.isPracticeUnlock)
        discovery = StopDiscovery()
        XCTAssertFalse(discovery.hasVerifiedPlaque)
        XCTAssertFalse(discovery.canContinue)
        XCTAssertTrue(discovery.arrive())
    }

    func testWindowPlacementMovesRightAndUpAndScalesWithPlaque() throws {
        let layout = WindowBonusLayout()
        let small = try XCTUnwrap(layout.dimensions(plaqueWidthMeters: 0.18))
        let large = try XCTUnwrap(layout.dimensions(plaqueWidthMeters: 0.36))
        XCTAssertEqual(large.width, small.width * 2, accuracy: 0.0001)
        XCTAssertEqual(large.height, small.height * 2, accuracy: 0.0001)
        let offset = try XCTUnwrap(layout.translation(plaqueWidthMeters: 0.18))
        XCTAssertGreaterThan(offset.x, 0)
        XCTAssertLessThan(offset.z, 0)
        XCTAssertGreaterThan(offset.y, 0)
        for invalid in [Double.nan, .infinity, 0, -1] {
            XCTAssertNil(layout.dimensions(plaqueWidthMeters: invalid))
        }
        XCTAssertNil(WindowBonusLayout(width: -1).translation(plaqueWidthMeters: 0.18))
    }
}
