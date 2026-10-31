import XCTest
@testable import TourCore

final class TourProgressionDecisionTests: XCTestCase {
    func testEveryAdvanceGateHasAnIndependentExplanation() {
        func decision(_ blocked: TourProgressionDecision.Blocker? = nil) -> TourProgressionDecision {
            TourProgressionDecision(walking: blocked != .walkStopped, mapVisible: blocked != .mapNotVisible,
                exploring: blocked == .exploring, arActive: blocked == .arActive,
                visitConfirmed: blocked != .visitIncomplete, held: blocked == .departureHeld,
                hasNextStop: blocked != .noNextStop, hasDestination: blocked != .noDestination)
        }
        XCTAssertTrue(decision().canAdvance)
        for reason in [TourProgressionDecision.Blocker.walkStopped, .mapNotVisible, .exploring, .arActive,
                       .visitIncomplete, .departureHeld, .noNextStop, .noDestination] {
            XCTAssertEqual(decision(reason).advanceBlockers, [reason])
            XCTAssertFalse(decision(reason).canAdvance)
        }
        XCTAssertTrue(decision(.visitIncomplete).canNavigateAutomatically)
    }

    func testDiagnosticTraceIsBoundedThrottledAndSerializable() throws {
        var trace = ProgressionDiagnostics(capacity: 3)
        let now = Date(timeIntervalSince1970: 1000)
        for second in 0..<20 {
            trace.record(stopID: "stop-1", trigger: "location", blockers: [.visitIncomplete],
                accuracy: .nan, distance: .infinity, nearSeconds: Double(second), now: now.addingTimeInterval(Double(second)))
        }
        XCTAssertEqual(trace.events.count, 3)
        XCTAssertEqual(trace.events.map(\.sequence), [2, 3, 4])
        trace.record(stopID: "stop-1", trigger: "advanced", blockers: [], nearSeconds: 180,
                     now: now.addingTimeInterval(19))
        XCTAssertEqual(trace.events.last?.trigger, "advanced", "Transitions bypass GPS sampling throttle")
        XCTAssertFalse(trace.exportJSON.contains("latitude"))
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        XCTAssertEqual(try decoder.decode([ProgressionDiagnostics.Event].self, from: Data(trace.exportJSON.utf8)), trace.events)
    }
}
