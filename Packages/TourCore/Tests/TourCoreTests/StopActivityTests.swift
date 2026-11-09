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

    func testSketchResetBlocksOnlyResetStopsAndKeepsANewerCollection() throws {
        let mill = StopVisitRecord(stopID: "mill", activatedAt: Date(timeIntervalSince1970: 100), evidence: .recognizedPlaque)
        let park = StopVisitRecord(stopID: "park", activatedAt: Date(timeIntervalSince1970: 150), evidence: .recognizedPlaque)
        let practice = StopVisitRecord(stopID: "practice", activatedAt: Date(timeIntervalSince1970: 160), evidence: .simulation)
        var ledger = StopActivityLedger()
        ledger.importVisits([mill, park, practice])
        ledger.read("church")
        ledger.clearSketches()

        let hotel = StopVisitRecord(stopID: "hotel", activatedAt: Date(timeIntervalSince1970: 180), evidence: .recognizedPlaque)
        ledger.importVisits([mill, park, practice, hotel])
        XCTAssertNil(ledger["mill"].plaqueUnlockedAt)
        XCTAssertNil(ledger["park"].plaqueUnlockedAt)
        XCTAssertNil(ledger["practice"].plaqueUnlockedAt)
        XCTAssertEqual(ledger["mill"].visitedAt, mill.activatedAt)
        XCTAssertNotNil(ledger["church"].readAt)
        XCTAssertEqual(ledger["hotel"].plaqueUnlockedAt, hotel.activatedAt,
                       "A stop that was not in the ledger must still unlock from its recognized visit")

        let collected = Date(timeIntervalSince1970: 300)
        ledger.collectSketch(at: "mill", date: collected)
        let saved = try JSONEncoder().encode(ledger)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: saved) as? [String: Any])
        let reset = try XCTUnwrap(object["resetSketchStopIDs"] as? [String])
        XCTAssertTrue(reset.contains("park"))
        XCTAssertTrue(reset.contains("church"))
        XCTAssertFalse(reset.contains("mill"), "Collecting again must clear that stop from the saved reset list")
        XCTAssertFalse(reset.contains("hotel"))

        ledger = try JSONDecoder().decode(StopActivityLedger.self, from: saved)
        ledger.importVisits([mill, hotel])
        XCTAssertEqual(ledger["mill"].plaqueUnlockedAt, collected,
                       "The older recognized visit must not replace the sketch collected after reset")
        XCTAssertEqual(ledger["hotel"].plaqueUnlockedAt, hotel.activatedAt)
        XCTAssertNil(ledger["park"].plaqueUnlockedAt)
        XCTAssertNotNil(ledger["church"].readAt)
    }

    func testLedgerSavedBeforeSketchResetStillAwardsRecognizedVisits() throws {
        let old = Data(#"{"entries":{"mill":{"visitedAt":100,"readAt":90}}}"#.utf8)
        var ledger = try JSONDecoder().decode(StopActivityLedger.self, from: old)
        let visit = StopVisitRecord(stopID: "mill", activatedAt: Date(timeIntervalSince1970: 100), evidence: .recognizedPlaque)
        ledger.importVisits([visit])
        XCTAssertEqual(ledger["mill"].plaqueUnlockedAt, visit.activatedAt)
        XCTAssertEqual(ledger["mill"].visitedAt, Date(timeIntervalSinceReferenceDate: 100))
        XCTAssertEqual(ledger["mill"].readAt, Date(timeIntervalSinceReferenceDate: 90))
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
