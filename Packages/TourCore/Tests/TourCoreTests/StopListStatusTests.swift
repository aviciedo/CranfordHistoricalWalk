import XCTest
@testable import TourCore

final class StopListStatusTests: XCTestCase {
    func testSavedVisitOrItineraryCompletionSaysVisitedAndNothingElse() {
        XCTAssertEqual(StopListStatus.labels(hasSavedVisit: true, itineraryCompleted: false, hasUnlockedBonus: false),
                       ["Visited"])
        XCTAssertEqual(StopListStatus.labels(hasSavedVisit: false, itineraryCompleted: true, hasUnlockedBonus: false),
                       ["Visited"])
        XCTAssertEqual(StopListStatus.labels(hasSavedVisit: false, itineraryCompleted: false, hasUnlockedBonus: false), [])
    }

    func testBonusStaysASeparateLineAndNeverImpliesAVisitByItself() {
        XCTAssertEqual(StopListStatus.labels(hasSavedVisit: false, itineraryCompleted: false, hasUnlockedBonus: true),
                       ["On-site bonus unlocked"])
        XCTAssertEqual(StopListStatus.labels(hasSavedVisit: true, itineraryCompleted: true, hasUnlockedBonus: true),
                       ["Visited", "On-site bonus unlocked"])
    }
}
