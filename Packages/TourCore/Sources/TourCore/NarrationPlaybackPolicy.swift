import Foundation

/// Audio-session interruption decisions. Playback stays in the app; this only says whether
/// to pause, resume, or leave the transport alone.
public enum NarrationInterruptionPolicy {
    /// `AVAudioSession.InterruptionType.began`.
    public static let beganType: UInt = 1
    /// `AVAudioSession.InterruptionType.ended`.
    public static let endedType: UInt = 0
    /// `AVAudioSession.InterruptionOptions.shouldResume`.
    public static let shouldResumeOption: UInt = 1

    public enum Decision: Equatable, Sendable {
        /// Remember whether narration was playing, and pause only when it was.
        case began(pausePlayback: Bool)
        /// Clear the remembered flag. Resume only when it had been playing and the system says to.
        case ended(resumePlayback: Bool)
        /// Missing or unknown interruption type. Leave playback and the remembered flag unchanged.
        case ignore
    }

    public static func decision(
        typeRaw: UInt?,
        optionsRaw: UInt?,
        isPlaying: Bool,
        wasPlayingBefore: Bool
    ) -> Decision {
        switch typeRaw {
        case beganType?:
            return .began(pausePlayback: isPlaying)
        case endedType?:
            let options = optionsRaw ?? 0
            let shouldResume = wasPlayingBefore && (options & shouldResumeOption) == shouldResumeOption
            return .ended(resumePlayback: shouldResume)
        default:
            return .ignore
        }
    }
}

/// Speech progress uses UTF-16 code units because that is what AVFoundation reports.
public enum NarrationSpeechProgress {
    /// `nil` when there is no text, so the caller leaves the previous progress alone.
    /// Values above the text clamp to 1. Values below 0 are preserved.
    public static func fraction(characterEndUTF16: Int, utf16Length: Int) -> Double? {
        guard utf16Length > 0 else { return nil }
        return min(Double(characterEndUTF16) / Double(utf16Length), 1)
    }
}
