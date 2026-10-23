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
}
