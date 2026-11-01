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
        XCTAssertNil(trace.events.last { $0.trigger == "location" }?.accuracyMeters)
        XCTAssertNil(trace.events.last { $0.trigger == "location" }?.distanceMeters)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        XCTAssertEqual(try decoder.decode([ProgressionDiagnostics.Event].self, from: Data(trace.exportJSON.utf8)), trace.events)
    }

    func testDiagnosticCapacityClampsAndKeepsTransitionsInsideTheSampleInterval() {
        XCTAssertEqual(ProgressionDiagnostics(capacity: 0).capacity, 1)
        XCTAssertEqual(ProgressionDiagnostics(capacity: -4).capacity, 1)
        XCTAssertEqual(ProgressionDiagnostics(capacity: 600).capacity, 600)
        XCTAssertEqual(ProgressionDiagnostics(capacity: 601).capacity, 600)

        var trace = ProgressionDiagnostics(capacity: 1)
        let start = Date(timeIntervalSince1970: 5_000)
        trace.record(stopID: "stop-1", trigger: "location", blockers: [.visitIncomplete],
            accuracy: .nan, distance: .infinity, fixAge: -.infinity, nearSeconds: .nan, now: start)
        XCTAssertEqual(trace.events.count, 1)
        XCTAssertNil(trace.events[0].accuracyMeters)
        XCTAssertNil(trace.events[0].distanceMeters)
        XCTAssertNil(trace.events[0].fixAgeSeconds)
        XCTAssertEqual(trace.events[0].nearSeconds, 0)
        trace.record(stopID: "stop-1", trigger: "location", blockers: [.visitIncomplete],
            nearSeconds: 1, now: start.addingTimeInterval(4.999))
        XCTAssertEqual(trace.events.count, 1, "Unchanged GPS status inside five seconds is dropped")
        trace.record(stopID: "stop-1", trigger: "advanced", blockers: [], nearSeconds: 1, now: start.addingTimeInterval(4.999))
        XCTAssertEqual(trace.events.map(\.trigger), ["advanced"], "A same-timestamp transition replaces the sampled row")

        var clock = ProgressionDiagnostics()
        clock.record(stopID: "stop-1", trigger: "location", blockers: [.visitIncomplete], nearSeconds: 0, now: start)
        clock.record(stopID: "stop-1", trigger: "location", blockers: [.visitIncomplete], nearSeconds: 1,
            now: start.addingTimeInterval(5))
        XCTAssertEqual(clock.events.count, 2)
        clock.record(stopID: "stop-1", trigger: "location", blockers: [.visitIncomplete], nearSeconds: 1,
            now: start.addingTimeInterval(4))
        XCTAssertEqual(clock.events.count, 3, "A backwards clock is recorded")
        clock.record(stopID: "stop-2", trigger: "location", blockers: [.visitIncomplete], nearSeconds: 1,
            now: start.addingTimeInterval(4.1))
        clock.record(stopID: "stop-2", trigger: "location", blockers: [.arActive], nearSeconds: 1,
            now: start.addingTimeInterval(4.2))
        clock.record(stopID: "stop-2", trigger: "held", blockers: [.arActive], nearSeconds: 1,
            now: start.addingTimeInterval(4.3))
        XCTAssertEqual(clock.events.suffix(3).map(\.stopID), ["stop-2", "stop-2", "stop-2"])
        XCTAssertEqual(clock.events.suffix(3).map(\.trigger), ["location", "location", "held"])
        XCTAssertEqual(clock.events.suffix(2).map(\.blockers), [[.arActive], [.arActive]])
    }
}
