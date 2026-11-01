import XCTest
@testable import TourCore

final class PlaqueRecognitionEvidenceTests: XCTestCase {
    private let id = UUID()
    private let references: Set<String> = ["mill", "park"]
    private func sample(_ time: Double, id: UUID? = nil, name: String? = "mill",
                        tracked: Bool = true, normalTracking: Bool = true,
                        position: SIMD3<Double> = [0, 1, -2],
                        normal: SIMD3<Double> = [0, 0, 1]) -> PlaqueRecognitionEvidence.Observation {
        .init(anchorID: id ?? self.id, referenceName: name, isTracked: tracked,
              cameraTrackingNormal: normalTracking, position: position, surfaceNormal: normal, timestamp: time)
    }
    private func qualify(_ gate: inout PlaqueRecognitionEvidence, start: Double = 0) {
        for t in [start, start + 0.25, start + 0.5] {
            _ = gate.observe(sample(t), at: t, supportedReferences: references)
        }
        XCTAssertTrue(gate.isConfirmed)
    }

    func testRecognitionRequiresContinuousDistinctFramesAndMinimumTime() {
        var gate = PlaqueRecognitionEvidence()
        XCTAssertFalse(gate.observe(sample(0), at: 0, supportedReferences: references))
        for now in [0.1, 0.2, 0.3] {
            XCTAssertFalse(gate.observe(sample(0), at: now, supportedReferences: references))
        }
        XCTAssertFalse(gate.observe(sample(0.25), at: 0.25, supportedReferences: references))
        XCTAssertTrue(gate.observe(sample(0.5), at: 0.5, supportedReferences: references))
        XCTAssertTrue(gate.observe(sample(0.5), at: 0.6, supportedReferences: references))
    }

    func testUnknownUntrackedLimitedAndStaleEvidenceNeverConfirms() {
        for invalid in [sample(0.5, name: nil), sample(0.5, name: "unrelated"),
                        sample(0.5, tracked: false), sample(0.5, normalTracking: false),
                        sample(-1), sample(.nan), sample(0.5, position: [.infinity, 0, 0]),
                        sample(0.5, normal: .zero)] {
            var gate = PlaqueRecognitionEvidence()
            qualify(&gate)
            XCTAssertFalse(gate.observe(invalid, at: 0.5, supportedReferences: references))
            XCTAssertFalse(gate.isConfirmed)
        }
        var gate = PlaqueRecognitionEvidence()
        XCTAssertFalse(gate.observe(sample(0), at: 1, supportedReferences: references))
        XCTAssertFalse(gate.observe(sample(1), at: 0, supportedReferences: references))
    }

    func testDifferentTargetsAndAnchorIdentitiesCannotPoolConfirmationTime() {
        var gate = PlaqueRecognitionEvidence()
        _ = gate.observe(sample(0), at: 0, supportedReferences: references)
        _ = gate.observe(sample(0.25), at: 0.25, supportedReferences: references)
        XCTAssertFalse(gate.observe(sample(0.5, name: "park"), at: 0.5, supportedReferences: references))
        XCTAssertEqual(gate.referenceName, "park")
        let nextID = UUID()
        XCTAssertFalse(gate.observe(sample(0.75, id: nextID, name: "park"), at: 0.75, supportedReferences: references))
        XCTAssertEqual(gate.anchorID, nextID)
        XCTAssertFalse(gate.isConfirmed)
    }

    func testTrackingLossAndInterruptionRequireFreshConfirmation() {
        var gate = PlaqueRecognitionEvidence()
        qualify(&gate)
        gate.lose(anchorID: UUID())
        XCTAssertTrue(gate.isConfirmed)
        gate.lose(anchorID: id)
        XCTAssertFalse(gate.isConfirmed)
        XCTAssertFalse(gate.observe(sample(0.6), at: 0.6, supportedReferences: references))
        gate.reset() // Camera pause/session interruption uses this exact operation.
        qualify(&gate, start: 10)
    }

    func testVisibilityGapAndPoseJumpsBreakPendingOrConfirmedLock() {
        var gate = PlaqueRecognitionEvidence()
        qualify(&gate)
        XCTAssertFalse(gate.observe(sample(1), at: 1, supportedReferences: references))
        qualify(&gate, start: 2)
        XCTAssertFalse(gate.observe(sample(2.6, position: [1, 1, -2]), at: 2.6, supportedReferences: references))
        qualify(&gate, start: 3)
        XCTAssertFalse(gate.observe(sample(3.6, normal: [1, 0, 0]), at: 3.6, supportedReferences: references))
    }

    func testSlowDriftIsComparedWithTheStartOfTheLockRatherThanEachFrame() {
        var gate = PlaqueRecognitionEvidence()
        for i in 0...5 {
            let t = Double(i) / 10
            XCTAssertFalse(gate.observe(sample(t, position: [Double(i) * 0.04, 1, -2]),
                at: t, supportedReferences: references))
        }
    }

    func testMinorJitterAndDelayedFreshCallbacksCanStillConfirm() {
        var gate = PlaqueRecognitionEvidence()
        for (t, x) in [(0.0, 0.0), (0.25, 0.02)] {
            XCTAssertFalse(gate.observe(sample(t, position: [x, 1, -2]),
                at: t + 0.1, supportedReferences: references))
        }
        XCTAssertTrue(gate.observe(sample(0.5, position: [-0.02, 1, -2]),
            at: 0.6, supportedReferences: references))
        XCTAssertFalse(gate.observe(sample(0.4), at: 0.6, supportedReferences: references))
        XCTAssertTrue(gate.isConfirmed, "An old callback cannot rewrite the current lock")
    }
}
