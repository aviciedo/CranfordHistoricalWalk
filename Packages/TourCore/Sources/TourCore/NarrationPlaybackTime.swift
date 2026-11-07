import Foundation

/// Elapsed/total labels and scrub positions for the shared narration transport.
public enum NarrationPlaybackTime {
    public static func text(_ seconds: TimeInterval?) -> String {
        guard let seconds, seconds.isFinite,
              let value = Int(exactly: max(0, seconds).rounded(.down)) else { return "--:--" }
        let remainder = String(format: "%02d", value % 60)
        if value >= 3600 {
            return "\(value / 3600):\(String(format: "%02d", value / 60 % 60)):\(remainder)"
        }
        return "\(value / 60):\(remainder)"
    }

    /// Fraction of the seek rail under a finger. A zero-width or non-finite rail
    /// does not invent a position past either end of the recording.
    public static func scrubFraction(locationX: Double, width: Double) -> Double? {
        guard width.isFinite, width > 0, locationX.isFinite else { return nil }
        return min(1, max(0, locationX / width))
    }

    /// Visible fill. A live scrub replaces playback progress and stays inside 0...1.
    public static func railProgress(scrubFraction: Double?, playbackProgress: Double) -> Double {
        min(1, max(0, scrubFraction ?? playbackProgress))
    }

    /// Preview time while dragging. Without a known duration, keep the player's elapsed time.
    public static func displayedElapsed(scrubFraction: Double?, duration: TimeInterval?,
                                        fallbackElapsed: TimeInterval) -> TimeInterval {
        guard let scrubFraction, let duration else { return fallbackElapsed }
        return scrubFraction * duration
    }
}
