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
        XCTAssertLessThan(abs(offset.x), 0.1, "Card remains approximately centered on the plaque")
        XCTAssertLessThan(offset.z, 0, "Negative image Z places the extra above the plaque")
        XCTAssertGreaterThan(offset.y, 0, "Card sits off the wall")
        XCTAssertNotEqual(layout, WindowBonusLayout())
    }

    func testGreystoneDefaultFitsPillarAndLeavesPlaqueVisible() {
        let layout = WindowBonusLayout.abovePlaque
        // From the photos: the pillar is about 1.1 close-up reference widths wide,
        // and the plaque's top is about 0.22 reference widths above the frame center.
        XCTAssertLessThan(layout.width, 1.1)
        XCTAssertGreaterThan(layout.up - layout.height / 2, 0.22)
        XCTAssertLessThan(layout.up + layout.height / 2, 1.1)
        XCTAssertEqual(layout.width / layout.height, 720.0 / 470.0, accuracy: 0.02,
                       "Keep the bonus texture close to its natural aspect ratio")
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

    func testSwitchingStopsRestoresThatSitesStoryAndPlaqueProgress() {
        var memory = StopDiscoveryMemory()
        var mill = memory.transition(to: "hpab-001", saving: StopDiscovery())
        mill.finishStory()
        mill.beginDiscovery()
        XCTAssertTrue(mill.recognizePlaque(isMatching: true, trackingReady: true, isSimulated: false))

        var park = memory.transition(to: "hpab-002", saving: mill)
        XCTAssertFalse(park.hasFinishedStory)
        XCTAssertFalse(park.hasVerifiedPlaque)
        park.finishStory()

        let restoredMill = memory.transition(to: "hpab-001", saving: park)
        XCTAssertTrue(restoredMill.hasVerifiedPlaque)
        XCTAssertEqual(restoredMill.stage, .unlocked)
        let restoredPark = memory.transition(to: "hpab-002", saving: restoredMill)
        XCTAssertTrue(restoredPark.hasFinishedStory)
        XCTAssertFalse(restoredPark.hasVerifiedPlaque)
        XCTAssertEqual(restoredPark.stage, .readyForDiscovery)
    }

    func testSameStopAndEmptyTargetKeepOrStoreTheActiveDiscovery() {
        var memory = StopDiscoveryMemory()
        var current = memory.transition(to: "hpab-001", saving: StopDiscovery())
        current.arrive()
        let again = memory.transition(to: "hpab-001", saving: current)
        XCTAssertTrue(again.hasArrived)
        XCTAssertTrue(again.hasOfferedArrivalStory)

        let cleared = memory.transition(to: nil, saving: again)
        XCTAssertEqual(cleared, StopDiscovery())
        let restored = memory.transition(to: "hpab-001", saving: cleared)
        XCTAssertTrue(restored.hasArrived)
    }

    func testResetDropsSavedDiscoveryBeforeTheWalkStartsAgain() {
        var memory = StopDiscoveryMemory()
        var current = memory.transition(to: "hpab-001", saving: StopDiscovery())
        current.finishStory()
        memory.reset()
        let restarted = memory.transition(to: "hpab-001", saving: current)
        XCTAssertFalse(restarted.hasFinishedStory)
        XCTAssertEqual(restarted, StopDiscovery())
        XCTAssertTrue(memory.byStopID.isEmpty)
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
