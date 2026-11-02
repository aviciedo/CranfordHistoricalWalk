import XCTest
@testable import TourCore

final class PlaqueScannerGuidanceTests: XCTestCase {
    private func searching(seconds: TimeInterval = 0) -> PlaqueScannerGuidance.Input {
        PlaqueScannerGuidance.Input(localizationFailed: false, isApplicationActive: true,
            isSessionRunning: true, imageTrackingAvailable: true, isPlaqueAnchored: false,
            isConfirmingPlaque: false, hasVerifiedPlaque: false, hasQualifiedAnchor: false,
            isSignPresented: false, secondsSinceAttempt: seconds)
    }

    func testFailedTrackingOutranksAPausedOrUnstartedCamera() {
        var input = searching()
        input.localizationFailed = true
        input.isApplicationActive = false
        input.isSessionRunning = false
        XCTAssertEqual(PlaqueScannerGuidance.phaseTitle(input), "Scanning stopped")
        XCTAssertEqual(PlaqueScannerGuidance.instruction(input),
                       "Scanning stopped. Try again, or return to the story.")
        input.localizationFailed = false
        XCTAssertEqual(PlaqueScannerGuidance.phaseTitle(input), "Camera starting")
        XCTAssertEqual(PlaqueScannerGuidance.instruction(input), "Scanning paused. Return to the app to continue.")
        input.isApplicationActive = true
        XCTAssertEqual(PlaqueScannerGuidance.instruction(input),
                       "Preparing the camera. You can return to the story at any time.")
    }

    func testUnavailableRecognitionOutranksACardThatLooksAnchored() {
        var input = searching()
        input.imageTrackingAvailable = false
        input.isPlaqueAnchored = true
        input.isConfirmingPlaque = true
        XCTAssertEqual(PlaqueScannerGuidance.phaseTitle(input), "Recognition unavailable")
        XCTAssertEqual(PlaqueScannerGuidance.instruction(input),
                       "Plaque recognition is unavailable. Return to the story or try again.")
    }

    func testAnchoredCardOutranksConfirmationAndReentry() {
        var input = searching()
        input.isPlaqueAnchored = true
        input.isConfirmingPlaque = true
        input.hasVerifiedPlaque = true
        input.hasQualifiedAnchor = true
        XCTAssertEqual(PlaqueScannerGuidance.phaseTitle(input), "Plaque found")
        XCTAssertEqual(PlaqueScannerGuidance.instruction(input), "Move slowly to view the card above the plaque.")
        XCTAssertEqual(PlaqueScannerGuidance.hudHeadline(isPlaqueAnchored: true, isConfirming: true), "Plaque recognized")
        input.isPlaqueAnchored = false
        XCTAssertEqual(PlaqueScannerGuidance.phaseTitle(input), "Hold steady")
        XCTAssertEqual(PlaqueScannerGuidance.instruction(input), "Hold steady while the plaque is confirmed.")
        XCTAssertEqual(PlaqueScannerGuidance.hudHeadline(isPlaqueAnchored: false, isConfirming: true), "Hold steady")
        XCTAssertEqual(PlaqueScannerGuidance.hudHeadline(isPlaqueAnchored: false, isConfirming: false), "Frame this plaque")
    }

    func testVerifiedPlaqueReopensOnlyAfterTheCardWasDismissed() {
        var input = searching(seconds: 30)
        input.hasVerifiedPlaque = true
        input.hasQualifiedAnchor = true
        input.isSignPresented = false
        XCTAssertEqual(PlaqueScannerGuidance.instruction(input),
                       "Look away, then frame the plaque again to reopen its AR card.")
        input.isSignPresented = true
        XCTAssertEqual(PlaqueScannerGuidance.instruction(input), "Frame the plaque again to place its AR card.")
        input.hasQualifiedAnchor = false
        input.isSignPresented = false
        XCTAssertEqual(PlaqueScannerGuidance.instruction(input), "Frame the plaque again to place its AR card.")
        XCTAssertEqual(PlaqueScannerGuidance.phaseTitle(input), "Looking for plaque")
    }

    func testCloserHintStartsAtTwelveSecondsAndDoesNotReplaceAKnownPlaque() {
        XCTAssertEqual(PlaqueScannerGuidance.instruction(searching(seconds: 11.999)),
                       "Frame the entire plaque and some surrounding wall in good light.")
        XCTAssertEqual(PlaqueScannerGuidance.instruction(searching(seconds: 12)),
                       "Move closer until the whole plaque is visible. Hold steady, avoid glare and try better light. You can retry or return to the story.")
        XCTAssertEqual(PlaqueScannerGuidance.instruction(searching(seconds: -1)),
                       "Frame the entire plaque and some surrounding wall in good light.")
        XCTAssertEqual(PlaqueScannerGuidance.instruction(searching(seconds: .nan)),
                       "Frame the entire plaque and some surrounding wall in good light.")
        var verified = searching(seconds: 12)
        verified.hasVerifiedPlaque = true
        XCTAssertEqual(PlaqueScannerGuidance.instruction(verified), "Frame the plaque again to place its AR card.")
    }
}
