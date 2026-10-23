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
        XCTAssertNotNil(ledger["mill"].bonusFoundAt)
        XCTAssertFalse(ledger["mill"].learningCompleted)
        XCTAssertNotNil(ledger["park"].visitedAt)
        XCTAssertNil(ledger["park"].bonusFoundAt)
        XCTAssertEqual(ledger["practice"], StopActivities())
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
