import Foundation

/// Scanner HUD copy. Failed tracking outranks a paused app, and a paused app outranks
/// a camera that has not started. Confirmation and re-entry never replace a card that
/// is already anchored on the plaque.
public enum PlaqueScannerGuidance {
    public struct Input: Equatable, Sendable {
        public var localizationFailed: Bool
        public var isApplicationActive: Bool
        public var isSessionRunning: Bool
        public var imageTrackingAvailable: Bool
        public var isPlaqueAnchored: Bool
        public var isConfirmingPlaque: Bool
        public var hasVerifiedPlaque: Bool
        public var hasQualifiedAnchor: Bool
        public var isSignPresented: Bool
        public var secondsSinceAttempt: TimeInterval

        public init(localizationFailed: Bool, isApplicationActive: Bool, isSessionRunning: Bool,
                    imageTrackingAvailable: Bool, isPlaqueAnchored: Bool, isConfirmingPlaque: Bool,
                    hasVerifiedPlaque: Bool, hasQualifiedAnchor: Bool, isSignPresented: Bool,
                    secondsSinceAttempt: TimeInterval) {
            self.localizationFailed = localizationFailed
            self.isApplicationActive = isApplicationActive
            self.isSessionRunning = isSessionRunning
            self.imageTrackingAvailable = imageTrackingAvailable
            self.isPlaqueAnchored = isPlaqueAnchored
            self.isConfirmingPlaque = isConfirmingPlaque
            self.hasVerifiedPlaque = hasVerifiedPlaque
            self.hasQualifiedAnchor = hasQualifiedAnchor
            self.isSignPresented = isSignPresented
            self.secondsSinceAttempt = secondsSinceAttempt
        }
    }

    public static func phaseTitle(_ input: Input) -> String {
        if input.localizationFailed { return "Scanning stopped" }
        guard input.isSessionRunning else { return "Camera starting" }
        guard input.imageTrackingAvailable else { return "Recognition unavailable" }
        if input.isPlaqueAnchored { return "Plaque found" }
        return input.isConfirmingPlaque ? "Hold steady" : "Looking for plaque"
    }

    public static func instruction(_ input: Input) -> String {
        if input.localizationFailed { return "Scanning stopped. Try again, or return to the story." }
        guard input.isApplicationActive else { return "Scanning paused. Return to the app to continue." }
        guard input.isSessionRunning else { return "Preparing the camera. You can return to the story at any time." }
        guard input.imageTrackingAvailable else { return "Plaque recognition is unavailable. Return to the story or try again." }
        if input.isPlaqueAnchored { return "Move slowly to view the card above the plaque." }
        if input.isConfirmingPlaque { return "Hold steady while the plaque is confirmed." }
        if input.hasVerifiedPlaque {
            if input.hasQualifiedAnchor && !input.isSignPresented {
                return "Look away, then frame the plaque again to reopen its AR card."
            }
            return "Frame the plaque again to place its AR card."
        }
        if input.secondsSinceAttempt >= 12 {
            return "Move closer until the whole plaque is visible. Hold steady, avoid glare and try better light. You can retry or return to the story."
        }
        return "Frame the entire plaque and some surrounding wall in good light."
    }

    public static func hudHeadline(isPlaqueAnchored: Bool, isConfirming: Bool) -> String {
        if isPlaqueAnchored { return "Plaque recognized" }
        return isConfirming ? "Hold steady" : "Frame this plaque"
    }
}
