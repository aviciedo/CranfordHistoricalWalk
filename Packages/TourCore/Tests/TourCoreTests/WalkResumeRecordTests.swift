import Foundation
import XCTest
@testable import TourCore

final class WalkResumeRecordTests: XCTestCase {
    func testDestinationAndRealVisitsSurviveRoundTripIndependently() throws {
        var progress = TourProgress(stopIDs: ["mill", "park", "river"])
        progress.start()
        progress.markCurrentStopVisited()
        progress.recordWalked(meters: 123)
        progress.advanceCurrentStop()
        let saved = WalkResumeRecord(progress: progress)
        let restored = try JSONDecoder().decode(WalkResumeRecord.self, from: JSONEncoder().encode(saved))
        XCTAssertTrue(restored.isValid(for: progress.stopIDs))
        XCTAssertEqual(restored.progress.currentStopID, "park")
        XCTAssertEqual(restored.progress.completedStopIDs, ["mill"])
        XCTAssertEqual(restored.progress.walkedMeters, 123)
        XCTAssertEqual(restored, saved)
    }

    func testCatalogChangesAndNotStartedRecordsAreRejected() {
        var progress = TourProgress(stopIDs: ["mill", "park"])
        XCTAssertFalse(WalkResumeRecord(progress: progress).isValid(for: progress.stopIDs))
        progress.start()
        let record = WalkResumeRecord(progress: progress)
        XCTAssertFalse(record.isValid(for: ["park", "mill"]))
        XCTAssertFalse(record.isValid(for: ["mill"]))
        XCTAssertFalse(record.isValid(for: ["mill", "mill"]))
        var newer = record
        newer.version = 9
        XCTAssertFalse(newer.isValid(for: progress.stopIDs))
    }

    func testInvalidStoredPositionAndDistanceAreRejected() throws {
        var progress = TourProgress(stopIDs: ["mill", "park"])
        progress.start()
        let data = try JSONEncoder().encode(WalkResumeRecord(progress: progress))
        for (key, value) in [("currentIndex", 99), ("walkedMeters", -5)] {
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            var stored = try XCTUnwrap(object["progress"] as? [String: Any])
            stored[key] = value
            object["progress"] = stored
            let record = try JSONDecoder().decode(WalkResumeRecord.self, from: JSONSerialization.data(withJSONObject: object))
            XCTAssertFalse(record.isValid(for: progress.stopIDs))
        }
    }

    func testCompletedSummarySurvivesWithoutNetworkOrInventingVisits() throws {
        var progress = TourProgress(stopIDs: ["mill", "park"])
        progress.start()
        progress.advanceCurrentStop()
        progress.advanceCurrentStop()
        let summary = TourSummary(stopCount: 2, totalDistanceMeters: 650, totalWalkingSeconds: 480,
            totalVisitSeconds: 0, isFromWalkingRoutes: true, pendingLegCount: 0)
        let saved = WalkResumeRecord(progress: progress, completionSummary: summary)
        let restored = try JSONDecoder().decode(WalkResumeRecord.self, from: JSONEncoder().encode(saved))
        XCTAssertTrue(restored.isValid(for: progress.stopIDs))
        XCTAssertEqual(restored.progress.phase, .complete)
        XCTAssertEqual(restored.progress.completedCount, 0)
        XCTAssertEqual(restored.completionSummary, summary)
    }

    func testCorruptResumeCannotRestoreAnotherStopOrAFalseCompletion() throws {
        var progress = TourProgress(stopIDs: ["mill", "park"])
        progress.start()
        let started = WalkResumeRecord(progress: progress)
        let ids = progress.stopIDs
        XCTAssertTrue(started.isValid(for: ids))

        let duplicateVisits = try edited(started) { $0["completedStopIDs"] = ["mill", "mill"] }
        XCTAssertFalse(duplicateVisits.isValid(for: ids))
        let foreignVisit = try edited(started) { $0["completedStopIDs"] = ["other"] }
        XCTAssertFalse(foreignVisit.isValid(for: ids))
        let missingStart = try edited(started) { $0["startedAt"] = NSNull() }
        XCTAssertFalse(missingStart.isValid(for: ids))
        let endedWhileWalking = try edited(started) { stored in
            stored["startedAt"] = 1_000.0
            stored["completedAt"] = 1_010.0
        }
        XCTAssertFalse(endedWhileWalking.isValid(for: ids))
        XCTAssertFalse(started.isValid(for: []))

        progress.advanceCurrentStop()
        progress.advanceCurrentStop()
        let summary = TourSummary(stopCount: 2, totalDistanceMeters: 650, totalWalkingSeconds: 480,
            totalVisitSeconds: 90, isFromWalkingRoutes: true, pendingLegCount: 0)
        let completed = WalkResumeRecord(progress: progress, completionSummary: summary)
        XCTAssertTrue(completed.isValid(for: ids))
        XCTAssertFalse(try edited(completed) { $0["currentIndex"] = 0 }.isValid(for: ids))
        XCTAssertFalse(try edited(completed) { $0.removeValue(forKey: "completedAt") }.isValid(for: ids))
        let endedFirst = try edited(completed) { stored in
            stored["startedAt"] = 1_000.0
            stored["completedAt"] = 999.0
        }
        XCTAssertFalse(endedFirst.isValid(for: ids))

        for (key, value) in [("stopCount", 9), ("totalDistanceMeters", -1), ("totalWalkingSeconds", -1),
                             ("totalVisitSeconds", -1), ("pendingLegCount", -1)] as [(String, Any)] {
            let invalid = try editedSummary(completed) { $0[key] = value }
            XCTAssertFalse(invalid.isValid(for: ids), key)
        }
    }

    private func edited(_ record: WalkResumeRecord, _ edit: (inout [String: Any]) -> Void) throws -> WalkResumeRecord {
        let data = try JSONEncoder().encode(record)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var stored = try XCTUnwrap(object["progress"] as? [String: Any])
        edit(&stored)
        object["progress"] = stored
        return try JSONDecoder().decode(WalkResumeRecord.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private func editedSummary(_ record: WalkResumeRecord, _ edit: (inout [String: Any]) -> Void) throws -> WalkResumeRecord {
        let data = try JSONEncoder().encode(record)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var summary = try XCTUnwrap(object["completionSummary"] as? [String: Any])
        edit(&summary)
        object["completionSummary"] = summary
        return try JSONDecoder().decode(WalkResumeRecord.self, from: JSONSerialization.data(withJSONObject: object))
    }
}
