import XCTest
@testable import TourCore

final class PlaqueScannerGuidanceTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 5_000)

    private func guidance(
        sessionRunning: Bool = true,
        imageTrackingAvailable: Bool = true,
        localizationFailed: Bool = false,
        plaqueVerified: Bool = false,
        bonusAccessible: Bool = false,
        elapsed: TimeInterval = 0
    ) -> PlaqueScannerGuidance {
        PlaqueScannerGuidance.current(
            sessionRunning: sessionRunning,
            imageTrackingAvailable: imageTrackingAvailable,
            localizationFailed: localizationFailed,
            plaqueVerified: plaqueVerified,
            bonusAccessible: bonusAccessible,
            attemptStartedAt: start,
            now: start.addingTimeInterval(elapsed))
    }

    func testDeadCameraOutranksTrackingFailureAndAVerifiedPlaque() {
        let starting = guidance(sessionRunning: false, imageTrackingAvailable: false,
                                localizationFailed: true, plaqueVerified: true, bonusAccessible: true, elapsed: 30)
        XCTAssertEqual(starting.title, "Camera starting")
        XCTAssertEqual(starting.instruction, "Preparing the camera. You can return to the story at any time.")

        let unavailable = guidance(imageTrackingAvailable: false, localizationFailed: true,
                                   plaqueVerified: true, bonusAccessible: true, elapsed: 30)
        XCTAssertEqual(unavailable.title, "Recognition unavailable")
        XCTAssertEqual(unavailable.instruction, "Plaque recognition is unavailable. Return to the story or try again.")

        let stopped = guidance(localizationFailed: true, plaqueVerified: true, bonusAccessible: true, elapsed: 30)
        XCTAssertEqual(stopped.title, "Scanning stopped")
        XCTAssertEqual(stopped.instruction, "Scanning stopped. Try again, or return to the story.")
    }

    func testVerifiedPlaqueReportsBonusAccessAndIgnoresTheSearchTimeout() {
        let saved = guidance(plaqueVerified: true, elapsed: 12)
        XCTAssertEqual(saved.title, "Plaque found")
        XCTAssertEqual(saved.instruction, "Your bonus is saved. Point at the plaque to place it in AR.")
        XCTAssertEqual(guidance(plaqueVerified: true, bonusAccessible: true).instruction, "Your bonus is unlocked.")
    }

    func testSearchHintChangesOnlyAfterTwelveSecondsOfThisAttempt() {
        let framing = "Frame the entire plaque and some surrounding wall in good light."
        let closer = "Move closer until the whole plaque is visible. Hold steady, avoid glare and try better light. You can retry or return to the story."
        XCTAssertEqual(guidance(elapsed: 11.999).title, "Looking for plaque")
        XCTAssertEqual(guidance(elapsed: 11.999).instruction, framing)
        XCTAssertEqual(guidance(elapsed: 12).instruction, closer)
        XCTAssertEqual(guidance(elapsed: -1).instruction, framing, "A retry resets the attempt clock")
    }
}
