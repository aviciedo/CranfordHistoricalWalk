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

    func testArrivalOffersStoryOnceWithoutRecordingOrStartingNarration() {
        var discovery = StopDiscovery()
        XCTAssertTrue(discovery.arrive())
        XCTAssertEqual(discovery.stage, .story)
        XCTAssertFalse(discovery.hasVerifiedPlaque)
        XCTAssertFalse(discovery.hasFinishedStory)
        XCTAssertFalse(discovery.arrive(), "Repeated fixes cannot reopen a dismissed reading screen")
    }

    func testDiscoveryDoesNotRequireLearningButStillRequiresExplicitSearchAndTrackedMatch() {
        var discovery = StopDiscovery()
        XCTAssertFalse(discovery.recognizePlaque(isMatching: true, trackingReady: true, isSimulated: false))
        XCTAssertTrue(discovery.canOfferDiscovery)
        XCTAssertTrue(discovery.beginDiscovery())
        XCTAssertFalse(discovery.hasFinishedStory)
        XCTAssertFalse(discovery.recognizePlaque(isMatching: false, trackingReady: true, isSimulated: false))
        XCTAssertFalse(discovery.recognizePlaque(isMatching: true, trackingReady: false, isSimulated: false))
        XCTAssertTrue(discovery.recognizePlaque(isMatching: true, trackingReady: true, isSimulated: false))
        XCTAssertTrue(discovery.hasVerifiedPlaque)
        XCTAssertFalse(discovery.hasFinishedStory)
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

}
