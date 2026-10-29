import XCTest
@testable import TourCore

final class StopActivityTests: XCTestCase {
    func testExistingSavedPlaqueUnlockMigratesToPassportStampWithoutLosingDate() throws {
        let old = Data(#"{"entries":{"mill":{"bonusFoundAt":1234,"visitedAt":1200}}}"#.utf8)
        var ledger = try JSONDecoder().decode(StopActivityLedger.self, from: old)
        XCTAssertEqual(ledger["mill"].plaqueUnlockedAt, Date(timeIntervalSinceReferenceDate: 1234))
        ledger.collectSketch(at: "mill", date: Date())
        XCTAssertEqual(ledger["mill"].plaqueUnlockedAt, Date(timeIntervalSinceReferenceDate: 1234), "Repeat recognition keeps the original stamp date")
        let saved = try JSONEncoder().encode(ledger)
        XCTAssertEqual(try JSONDecoder().decode(StopActivityLedger.self, from: saved), ledger)
        XCTAssertTrue(String(decoding: saved, as: UTF8.self).contains("bonusFoundAt"), "Preserve the legacy on-disk key")
    }
    func testListeningAndReadingEachCompleteLearningWithoutVisitOrBonus() {
        var ledger = StopActivityLedger()
        ledger.listened(to: "mill")
        ledger.read("park")
        for id in ["mill", "park"] {
            XCTAssertTrue(ledger[id].learningCompleted)
            XCTAssertNil(ledger[id].visitedAt)
            XCTAssertNil(ledger[id].plaqueUnlockedAt)
        }
        ledger.read("mill")
        XCTAssertNotNil(ledger["mill"].listenedAt)
        XCTAssertNotNil(ledger["mill"].readAt)
    }
    func testVisitAndBonusDoNotManufactureLearning() {
        var ledger = StopActivityLedger()
        ledger.visited("mill")
        ledger.collectSketch(at: "park")
        XCTAssertFalse(ledger["mill"].learningCompleted)
        XCTAssertNil(ledger["mill"].plaqueUnlockedAt)
        XCTAssertFalse(ledger["park"].learningCompleted)
        XCTAssertNil(ledger["park"].visitedAt)
    }
    func testClearingVisitsPreservesLearningAndBonusAndCodableRoundTrip() throws {
        var ledger = StopActivityLedger()
        ledger.listened(to: "mill")
        ledger.read("park")
        ledger.visited("mill")
        ledger.collectSketch(at: "mill")
        ledger.clearVisits()
        XCTAssertTrue(ledger["mill"].learningCompleted)
        XCTAssertNotNil(ledger["mill"].plaqueUnlockedAt)
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
        XCTAssertNotNil(ledger["mill"].plaqueUnlockedAt)
        XCTAssertFalse(ledger["mill"].learningCompleted)
        XCTAssertNotNil(ledger["park"].visitedAt)
        XCTAssertNil(ledger["park"].plaqueUnlockedAt)
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
