import Foundation

/// Skip math for the narration transport. Playback stays in the app; this only clamps the target.
public enum NarrationSeek {
    /// New position after skipping `delta` seconds, clamped to `0...duration`.
    public static func position(afterSkipping delta: TimeInterval, from elapsed: TimeInterval, duration: TimeInterval) -> TimeInterval {
        min(max(elapsed + delta, 0), duration)
    }
}
