import XCTest
@testable import TourCore

final class TourProgressTests: XCTestCase {
    let ids = ["a", "b", "c"]

    func testLifecycle() {
        var p = TourProgress(stopIDs: ids)
        XCTAssertEqual(p.phase, .notStarted)
        XCTAssertNil(p.currentStopID)

        p.start()
        XCTAssertEqual(p.phase, .inProgress)
        XCTAssertEqual(p.currentStopID, "a")
        XCTAssertEqual(p.nextStopID, "b")
        XCTAssertEqual(Array(p.remainingStopIDs), ["a", "b", "c"])

        XCTAssertEqual(p.completeCurrentStop(), "b")
        XCTAssertTrue(p.isCompleted("a"))
        XCTAssertEqual(p.previousCompletedStopID, "a")
        XCTAssertEqual(p.currentStopID, "b")
        XCTAssertEqual(p.nextStopID, "c")

        XCTAssertEqual(p.completeCurrentStop(), "c")
        XCTAssertNil(p.nextStopID)
        XCTAssertNil(p.completeCurrentStop())
        XCTAssertEqual(p.phase, .complete)
        XCTAssertEqual(p.completedCount, 3)
        XCTAssertNil(p.currentStopID)
        XCTAssertNotNil(p.completedAt)
    }

    func testMarkVisitedDoesNotAdvanceAndPanelExcludesCurrent() {
        var p = TourProgress(stopIDs: ids)
        p.start()
        XCTAssertFalse(p.isCurrentStopVisited)
        XCTAssertTrue(p.markCurrentStopVisited())
        XCTAssertFalse(p.markCurrentStopVisited(), "second mark is a no-op")
        XCTAssertTrue(p.isCompleted("a"))
        XCTAssertTrue(p.isCurrentStopVisited)
        XCTAssertEqual(p.currentStopID, "a", "marker changes but the destination stays until the sign is closed")
        XCTAssertNil(p.previousCompletedStopID, "the current stop must not show up as the previous one")
        XCTAssertEqual(p.completedCount, 1)

        XCTAssertEqual(p.completeCurrentStop(), "b")
        XCTAssertEqual(p.completedCount, 1, "advancing after a mark does not double-count")
        XCTAssertEqual(p.previousCompletedStopID, "a")
        XCTAssertFalse(p.isCurrentStopVisited)
    }

    func testCompleteBeforeStartIsNoOp() {
        var p = TourProgress(stopIDs: ids)
        XCTAssertNil(p.completeCurrentStop())
        XCTAssertEqual(p.phase, .notStarted)
    }

    func testJumpToIndexClearsLaterCompletions() {
        var p = TourProgress(stopIDs: ids)
        p.start()
        p.completeCurrentStop()
        p.completeCurrentStop()
        XCTAssertEqual(p.currentStopID, "c")
        p.jump(toIndex: 1)
        XCTAssertEqual(p.currentStopID, "b")
        XCTAssertTrue(p.isCompleted("a"))
        XCTAssertFalse(p.isCompleted("b"))
    }

    func testJumpFromCompleteReopensTour() {
        var p = TourProgress(stopIDs: ids)
        p.start()
        while p.completeCurrentStop() != nil {}
        XCTAssertEqual(p.phase, .complete)
        p.jump(toIndex: 2)
        XCTAssertEqual(p.phase, .inProgress)
        XCTAssertEqual(p.currentStopID, "c")
        XCTAssertEqual(p.completedCount, 2)
    }

    func testWalkedMetersOnlyWhileInProgress() {
        var p = TourProgress(stopIDs: ids)
        p.recordWalked(meters: 10)
        XCTAssertEqual(p.walkedMeters, 0)
        p.start()
        p.recordWalked(meters: 10)
        p.recordWalked(meters: -5)
        p.recordWalked(meters: .nan)
        XCTAssertEqual(p.walkedMeters, 10)
    }

    func testResetAndCodable() throws {
        var p = TourProgress(stopIDs: ids)
        p.start()
        p.completeCurrentStop()
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(TourProgress.self, from: data)
        XCTAssertEqual(decoded, p)
        p.reset()
        XCTAssertEqual(p, TourProgress(stopIDs: ids))
    }
}
