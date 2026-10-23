import XCTest
@testable import TourCore

final class StopActivityTests: XCTestCase {
    func testListeningAndReadingEachCompleteLearningWithoutVisitOrBonus() {
        var ledger = StopActivityLedger()
        ledger.listened(to: "mill")
        ledger.read("park")
        for id in ["mill", "park"] {
            XCTAssertTrue(ledger[id].learningCompleted)
            XCTAssertNil(ledger[id].visitedAt)
            XCTAssertNil(ledger[id].bonusFoundAt)
        }
        ledger.read("mill")
        XCTAssertNotNil(ledger["mill"].listenedAt)
        XCTAssertNotNil(ledger["mill"].readAt)
    }
    func testVisitAndBonusDoNotManufactureLearning() {
        var ledger = StopActivityLedger()
        ledger.visited("mill")
        ledger.foundBonus(at: "park")
        XCTAssertFalse(ledger["mill"].learningCompleted)
        XCTAssertNil(ledger["mill"].bonusFoundAt)
        XCTAssertFalse(ledger["park"].learningCompleted)
        XCTAssertNil(ledger["park"].visitedAt)
    }
    func testClearingVisitsPreservesLearningAndBonusAndCodableRoundTrip() throws {
        var ledger = StopActivityLedger()
        ledger.listened(to: "mill")
        ledger.read("park")
        ledger.visited("mill")
        ledger.foundBonus(at: "mill")
        ledger.clearVisits()
        XCTAssertTrue(ledger["mill"].learningCompleted)
        XCTAssertNotNil(ledger["mill"].bonusFoundAt)
        XCTAssertNil(ledger["mill"].visitedAt)
        XCTAssertEqual(try JSONDecoder().decode(StopActivityLedger.self, from: JSONEncoder().encode(ledger)), ledger)
    }
    func testLegacyMigrationDoesNotInventLearningAndRejectsPractice() {
        var ledger = StopActivityLedger()
        ledger.importVisits([
            StopVisitRecord(stopID: "mill", activatedAt: Date(), evidence: .recognizedPlaque),
            StopVisitRecord(stopID: "park", activatedAt: Date(), evidence: .onSiteARMarker),
            StopVisitRecord(stopID: "practice", activatedAt: Date(), evidence: .simulation)
        ])
        XCTAssertNotNil(ledger["mill"].visitedAt, "A recognized plaque is still a physical visit")
        XCTAssertNotNil(ledger["mill"].bonusFoundAt)
        XCTAssertFalse(ledger["mill"].learningCompleted)
        XCTAssertNotNil(ledger["park"].visitedAt)
        XCTAssertNil(ledger["park"].bonusFoundAt)
        XCTAssertEqual(ledger["practice"], StopActivities())
    }
    func testEarlierActivityTimeSurvivesALaterRepeat() {
        var ledger = StopActivityLedger()
        let first = Date(timeIntervalSince1970: 1_700_000_000)
        let later = first.addingTimeInterval(3_600)
        ledger.listened(to: "mill", at: first)
        ledger.read("mill", at: first)
        ledger.visited("mill", at: first)
        ledger.foundBonus(at: "mill", date: first)
        ledger.listened(to: "mill", at: later)
        ledger.read("mill", at: later)
        ledger.visited("mill", at: later)
        ledger.foundBonus(at: "mill", date: later)
        XCTAssertEqual(ledger["mill"].listenedAt, first)
        XCTAssertEqual(ledger["mill"].readAt, first)
        XCTAssertEqual(ledger["mill"].visitedAt, first)
        XCTAssertEqual(ledger["mill"].bonusFoundAt, first)

        ledger.importVisits([
            StopVisitRecord(stopID: "mill", activatedAt: later, evidence: .recognizedPlaque)
        ])
        XCTAssertEqual(ledger["mill"].visitedAt, first, "Re-importing history must not move the original visit")
        XCTAssertEqual(ledger["mill"].bonusFoundAt, first)
    }

    func testSkippingAnItineraryStopIsNotAVisit() {
        var walk = TourProgress(stopIDs: ["mill", "park"])
        walk.start()
        XCTAssertEqual(walk.advanceCurrentStop(), "park")
        XCTAssertFalse(walk.isCompleted("mill"))
        walk.markCurrentStopVisited()
        walk.advanceCurrentStop()
        XCTAssertEqual(walk.completedStopIDs, ["park"])
        XCTAssertEqual(walk.phase, .complete)
    }
}
