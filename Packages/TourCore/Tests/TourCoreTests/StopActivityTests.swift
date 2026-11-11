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
    func testSketchResetSurvivesPersistenceAndLegacyVisitImportButAllowsNewCollection() throws {
        let visit = StopVisitRecord(stopID: "mill", activatedAt: Date(timeIntervalSince1970: 100), evidence: .recognizedPlaque)
        var ledger = StopActivityLedger()
        ledger.importVisits([visit])
        ledger.read("mill"); ledger.listened(to: "mill")
        let before = ledger["mill"]
        ledger.clearSketches()
        ledger = try JSONDecoder().decode(StopActivityLedger.self, from: JSONEncoder().encode(ledger))
        ledger.importVisits([visit])
        XCTAssertNil(ledger["mill"].plaqueUnlockedAt, "Legacy visits must not silently undo the developer reset")
        XCTAssertEqual(ledger["mill"].visitedAt, before.visitedAt)
        XCTAssertEqual(ledger["mill"].readAt, before.readAt)
        XCTAssertEqual(ledger["mill"].listenedAt, before.listenedAt)
        let newDate = Date(timeIntervalSince1970: 200)
        ledger.collectSketch(at: "mill", date: newDate)
        ledger.importVisits([visit])
        XCTAssertEqual(ledger["mill"].plaqueUnlockedAt, newDate)
    }

    func testSketchSuppressionIsPerStopAndAnEmptyResetDoesNotBlockNewAwards() throws {
        let saved = Data(#"{"entries":{"mill":{"visitedAt":100,"listenedAt":40},"church":{"visitedAt":120,"readAt":50}},"resetSketchStopIDs":["mill","church","future"]}"#.utf8)
        var ledger = try JSONDecoder().decode(StopActivityLedger.self, from: saved)
        func visit(_ id: String, _ seconds: Double, _ evidence: StopVisitEvidence) -> StopVisitRecord {
            StopVisitRecord(stopID: id, activatedAt: Date(timeIntervalSinceReferenceDate: seconds), evidence: evidence)
        }
        ledger.importVisits([
            visit("mill", 100, .recognizedPlaque),
            visit("church", 80, .recognizedPlaque),
            visit("park", 110, .recognizedPlaque),
            visit("future", 90, .recognizedPlaque),
            visit("river", 70, .onSiteARMarker),
            visit("practice", 60, .simulation)
        ])
        XCTAssertNil(ledger["mill"].plaqueUnlockedAt, "A saved reset must survive the next launch import")
        XCTAssertEqual(ledger["mill"].visitedAt, Date(timeIntervalSinceReferenceDate: 100))
        XCTAssertEqual(ledger["mill"].listenedAt, Date(timeIntervalSinceReferenceDate: 40))
        XCTAssertNil(ledger["church"].plaqueUnlockedAt)
        XCTAssertEqual(ledger["church"].visitedAt, Date(timeIntervalSinceReferenceDate: 120))
        XCTAssertEqual(ledger["church"].readAt, Date(timeIntervalSinceReferenceDate: 50))
        XCTAssertNil(ledger["future"].plaqueUnlockedAt, "Suppression applies even when that stop has no ledger row yet")
        XCTAssertEqual(ledger["future"].visitedAt, Date(timeIntervalSinceReferenceDate: 90))
        XCTAssertEqual(ledger["park"].plaqueUnlockedAt, Date(timeIntervalSinceReferenceDate: 110))
        XCTAssertEqual(ledger["river"].visitedAt, Date(timeIntervalSinceReferenceDate: 70))
        XCTAssertNil(ledger["river"].plaqueUnlockedAt)
        XCTAssertEqual(ledger["practice"], StopActivities())

        ledger.importVisits([visit("park", 1, .recognizedPlaque)])
        XCTAssertEqual(ledger["park"].plaqueUnlockedAt, Date(timeIntervalSinceReferenceDate: 110),
                       "Importing another stop must not rewrite an existing award")
        ledger.collectSketch(at: "mill", date: Date(timeIntervalSinceReferenceDate: 200))
        ledger.collectSketch(at: "future", date: Date(timeIntervalSinceReferenceDate: 300))
        ledger.importVisits([visit("mill", 100, .recognizedPlaque), visit("future", 90, .recognizedPlaque),
                             visit("church", 80, .recognizedPlaque)])
        XCTAssertEqual(ledger["mill"].plaqueUnlockedAt, Date(timeIntervalSinceReferenceDate: 200))
        XCTAssertEqual(ledger["future"].plaqueUnlockedAt, Date(timeIntervalSinceReferenceDate: 300))
        XCTAssertNil(ledger["church"].plaqueUnlockedAt, "Recollecting one stop must not lift another stop's suppression")
        XCTAssertEqual(ledger["park"].plaqueUnlockedAt, Date(timeIntervalSinceReferenceDate: 110))

        ledger.clearSketches()
        ledger = try JSONDecoder().decode(StopActivityLedger.self, from: JSONEncoder().encode(ledger))
        ledger.importVisits([
            visit("mill", 100, .recognizedPlaque), visit("park", 110, .recognizedPlaque),
            visit("future", 90, .recognizedPlaque), visit("hotel", 140, .recognizedPlaque)
        ])
        XCTAssertNil(ledger["mill"].plaqueUnlockedAt)
        XCTAssertNil(ledger["park"].plaqueUnlockedAt)
        XCTAssertNil(ledger["future"].plaqueUnlockedAt)
        XCTAssertEqual(ledger["hotel"].plaqueUnlockedAt, Date(timeIntervalSinceReferenceDate: 140),
                       "A later reset suppresses stops that now have rows, not stops that appear afterwards")
        XCTAssertEqual(ledger["church"].readAt, Date(timeIntervalSinceReferenceDate: 50))
        XCTAssertEqual(ledger["mill"].listenedAt, Date(timeIntervalSinceReferenceDate: 40))

        var empty = StopActivityLedger()
        empty.clearSketches()
        empty = try JSONDecoder().decode(StopActivityLedger.self, from: JSONEncoder().encode(empty))
        empty.importVisits([visit("park", 110, .recognizedPlaque)])
        XCTAssertEqual(empty["park"].plaqueUnlockedAt, Date(timeIntervalSinceReferenceDate: 110),
                       "Clearing a ledger with no rows must not become a global sketch block")
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
