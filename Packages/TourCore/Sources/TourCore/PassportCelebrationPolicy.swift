import Foundation

/// How long the scanner keeps a saved stamp on screen, and when that overlay may dismiss itself.
/// The overlay never creates, consumes, or replaces the pending passport event.
public enum PassportCelebrationPolicy {
    public static let autoDismissMilliseconds = 2400
    public static let voiceOverAutoDismissMilliseconds = 4500

    public static func autoDismissMilliseconds(voiceOverRunning: Bool) -> Int {
        voiceOverRunning ? voiceOverAutoDismissMilliseconds : autoDismissMilliseconds
    }

    /// The timer starts only while the scene is active and this stop's stamp is already saved.
    public static func scheduledStopID(sceneIsActive: Bool, pendingStopID: String?, stampIsSaved: Bool) -> String? {
        guard sceneIsActive, stampIsSaved, let pendingStopID else { return nil }
        return pendingStopID
    }

    /// Dismiss only for the same pending stop. A newer plaque, or a scene that is no longer
    /// active, must not finish the previous timer. The award itself is not checked again.
    public static func shouldFinishAutoDismiss(sceneIsActive: Bool, pendingStopID: String?,
                                               scheduledStopID: String) -> Bool {
        sceneIsActive && pendingStopID == scheduledStopID
    }
}
