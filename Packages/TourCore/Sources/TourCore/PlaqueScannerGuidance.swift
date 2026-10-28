import Foundation

/// Scanner HUD copy. A dead camera or failed localization outranks a saved plaque so the
/// screen never says the plaque is found while scanning has stopped. The closer-hint
/// clock belongs to the current attempt; retrying the scanner starts it over.
public struct PlaqueScannerGuidance: Equatable, Sendable {
    public static let recognitionTimeout: TimeInterval = 12
    public var title: String
    public var instruction: String

    public static func current(
        sessionRunning: Bool,
        imageTrackingAvailable: Bool,
        localizationFailed: Bool,
        plaqueVerified: Bool,
        bonusAccessible: Bool,
        attemptStartedAt: Date,
        now: Date
    ) -> PlaqueScannerGuidance {
        if !sessionRunning {
            return PlaqueScannerGuidance(
                title: "Camera starting",
                instruction: "Preparing the camera. You can return to the story at any time.")
        }
        if !imageTrackingAvailable {
            return PlaqueScannerGuidance(
                title: "Recognition unavailable",
                instruction: "Plaque recognition is unavailable. Return to the story or try again.")
        }
        if localizationFailed {
            return PlaqueScannerGuidance(
                title: "Scanning stopped",
                instruction: "Scanning stopped. Try again, or return to the story.")
        }
        if plaqueVerified {
            return PlaqueScannerGuidance(
                title: "Plaque found",
                instruction: bonusAccessible
                    ? "Your bonus is unlocked."
                    : "Your bonus is saved. Point at the plaque to place it in AR.")
        }
        if now.timeIntervalSince(attemptStartedAt) >= recognitionTimeout {
            return PlaqueScannerGuidance(
                title: "Looking for plaque",
                instruction: "Move closer until the whole plaque is visible. Hold steady, avoid glare and try better light. You can retry or return to the story.")
        }
        return PlaqueScannerGuidance(
            title: "Looking for plaque",
            instruction: "Frame the entire plaque and some surrounding wall in good light.")
    }
}
