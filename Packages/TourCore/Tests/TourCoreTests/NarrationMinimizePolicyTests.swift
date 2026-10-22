import XCTest
@testable import TourCore

final class NarrationMinimizePolicyTests: XCTestCase {
    func testFirstScrollSampleOnlyRecordsABaseline() {
        XCTAssertEqual(NarrationMinimizePolicy.scrollThreshold, 24)
        let sample = NarrationMinimizePolicy.scrolled(offset: 120, baseline: nil, isMinimized: false)
        XCTAssertEqual(sample, .init(baseline: 120, isMinimized: false))
        let alreadyHidden = NarrationMinimizePolicy.scrolled(offset: 40, baseline: nil, isMinimized: true)
        XCTAssertEqual(alreadyHidden, .init(baseline: 40, isMinimized: true))
    }

    func testScrollMinimizesOnlyAfterMoreThanTwentyFourPointsAndDoesNotAccumulate() {
        let baseline = NarrationMinimizePolicy.scrolled(offset: 200, baseline: nil, isMinimized: false)
        let exact = NarrationMinimizePolicy.scrolled(offset: 176, baseline: baseline.baseline, isMinimized: false)
        XCTAssertEqual(exact, .init(baseline: 200, isMinimized: false))

        let shortStep = NarrationMinimizePolicy.scrolled(offset: 190, baseline: baseline.baseline, isMinimized: false)
        XCTAssertEqual(shortStep.baseline, 200)
        XCTAssertFalse(shortStep.isMinimized)
        // A second short step still measures from the original baseline.
        let secondShortStep = NarrationMinimizePolicy.scrolled(offset: 180, baseline: shortStep.baseline, isMinimized: shortStep.isMinimized)
        XCTAssertEqual(secondShortStep, .init(baseline: 200, isMinimized: false))

        let collapse = NarrationMinimizePolicy.scrolled(offset: 175.9, baseline: 200, isMinimized: false)
        XCTAssertEqual(collapse, .init(baseline: 175.9, isMinimized: true))
    }

    func testDownwardScrollRebasesWithoutExpandingThePlayer() {
        let expanded = NarrationMinimizePolicy.scrolled(offset: 210, baseline: 200, isMinimized: false)
        XCTAssertEqual(expanded, .init(baseline: 210, isMinimized: false))

        let stillHidden = NarrationMinimizePolicy.scrolled(offset: 240, baseline: 200, isMinimized: true)
        XCTAssertEqual(stillHidden, .init(baseline: 240, isMinimized: true))

        let unchanged = NarrationMinimizePolicy.scrolled(offset: 200, baseline: 200, isMinimized: true)
        XCTAssertEqual(unchanged, .init(baseline: 200, isMinimized: true))
    }

    func testDragRequiresAMostlyVerticalMovePastTheThreshold() {
        XCTAssertEqual(NarrationMinimizePolicy.dragThreshold, 20)
        XCTAssertEqual(NarrationMinimizePolicy.drag(width: 0, height: 20), .ignore)
        XCTAssertEqual(NarrationMinimizePolicy.drag(width: 0, height: 20.1), .minimize)
        XCTAssertEqual(NarrationMinimizePolicy.drag(width: 0, height: -20), .ignore)
        XCTAssertEqual(NarrationMinimizePolicy.drag(width: 0, height: -20.1), .expand)
        XCTAssertEqual(NarrationMinimizePolicy.drag(width: 30, height: 30), .ignore)
        XCTAssertEqual(NarrationMinimizePolicy.drag(width: -29.9, height: 30), .minimize)
        XCTAssertEqual(NarrationMinimizePolicy.drag(width: 29, height: -30), .expand)
        XCTAssertEqual(NarrationMinimizePolicy.drag(width: 40, height: 10), .ignore)
        XCTAssertEqual(NarrationMinimizePolicy.drag(width: 0, height: 0), .ignore)
    }
}
