import XCTest
@testable import TourCore

final class PassportPageSelectionTests: XCTestCase {
    private let pages = ["hpab-001", "hpab-002"]

    func testRequestedLeafOpensAndAnUnknownIdStartsAtTheFirstPage() {
        var selection = PassportPageSelection()
        XCTAssertEqual(selection.currentIndex(stopIDs: pages, initialStopID: "hpab-002"), 1)
        XCTAssertEqual(selection.currentIndex(stopIDs: pages, initialStopID: "missing"), 0)
        XCTAssertEqual(selection.currentIndex(stopIDs: pages, initialStopID: ""), 0)
        XCTAssertEqual(selection.currentIndex(stopIDs: [], initialStopID: "hpab-002"), 0)
        selection.selectInitialPage(stopIDs: [], initialStopID: "hpab-002")
        XCTAssertFalse(selection.hasSelectedInitialPage, "An empty book must not lock away a later request")
        selection.selectInitialPage(stopIDs: pages, initialStopID: "hpab-002")
        XCTAssertEqual(selection.currentIndex(stopIDs: pages, initialStopID: "hpab-001"), 1)
        selection.selectInitialPage(stopIDs: pages, initialStopID: "hpab-001")
        XCTAssertEqual(selection.pageIndex, 1, "The first selection wins over a later open")
    }

    func testAnIndexPastTheLastPageDisplaysTheLastLeaf() {
        var selection = PassportPageSelection()
        selection.selectInitialPage(stopIDs: pages, initialStopID: "hpab-001")
        selection.choose(0)
        XCTAssertEqual(selection.currentIndex(stopIDs: pages, initialStopID: "hpab-002"), 0)
        selection.choose(1)
        XCTAssertEqual(selection.currentIndex(stopIDs: pages, initialStopID: "hpab-001"), 1)
        selection.choose(8)
        XCTAssertEqual(selection.currentIndex(stopIDs: pages, initialStopID: "hpab-001"), 1)
        selection.clampStoredIndex(stopCount: pages.count)
        XCTAssertEqual(selection.pageIndex, 1)
        selection.clampStoredIndex(stopCount: 1)
        XCTAssertEqual(selection.currentIndex(stopIDs: ["hpab-001"], initialStopID: "hpab-002"), 0)
        selection.clampStoredIndex(stopCount: 0)
        XCTAssertEqual(selection.pageIndex, 0)
    }

    func testCelebrationHoldsOnlyASavedNewStampAndDoesNotHideOtherLeaves() {
        XCTAssertFalse(PassportPageSelection.isAwaitingStampReveal(animatedStopID: nil, bonusIsSaved: true, hasStamped: false))
        XCTAssertFalse(PassportPageSelection.isAwaitingStampReveal(animatedStopID: "hpab-001", bonusIsSaved: false, hasStamped: false))
        XCTAssertTrue(PassportPageSelection.isAwaitingStampReveal(animatedStopID: "hpab-001", bonusIsSaved: true, hasStamped: false))
        XCTAssertFalse(PassportPageSelection.isAwaitingStampReveal(animatedStopID: "hpab-001", bonusIsSaved: true, hasStamped: true))
        XCTAssertFalse(PassportPageSelection.shouldRevealStamp(stopID: "hpab-001", animatedStopID: "hpab-001", hasStamped: false))
        XCTAssertTrue(PassportPageSelection.shouldRevealStamp(stopID: "hpab-001", animatedStopID: "hpab-001", hasStamped: true))
        XCTAssertTrue(PassportPageSelection.shouldRevealStamp(stopID: "hpab-002", animatedStopID: "hpab-001", hasStamped: false))
        XCTAssertTrue(PassportPageSelection.shouldRevealStamp(stopID: "hpab-003", animatedStopID: nil, hasStamped: false))
    }

    func testStampArtIsSiteSpecificAndDoesNotBorrowAnotherLandmark() {
        XCTAssertEqual(PassportPageSelection.stampAssetName(for: "hpab-001"), "passport-stamp-mill")
        XCTAssertEqual(PassportPageSelection.stampAssetName(for: "hpab-002"), "passport-stamp-greystone")
        XCTAssertNil(PassportPageSelection.stampAssetName(for: "hpab-003"))
        XCTAssertNil(PassportPageSelection.stampAssetName(for: ""))
        XCTAssertNil(PassportPageSelection.stampAssetName(for: "hpab-001 "))
    }
}
