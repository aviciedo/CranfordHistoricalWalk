import Foundation

public enum NarrationVoicePreference: String, Codable, Sendable {
    case systemDefault
    case warmMaleEnglish
}

/// Metadata only. The iOS player supplies voices reported by AVFoundation at runtime.
public struct SpeechVoiceOption: Equatable, Sendable {
    public enum Quality: Int, Sendable { case standard, enhanced, premium }
    public var identifier: String
    public var language: String
    public var isMale: Bool
    public var quality: Quality
    public var isNovelty: Bool
    public var isPersonal: Bool

    public init(identifier: String, language: String, isMale: Bool, quality: Quality, isNovelty: Bool = false, isPersonal: Bool = false) {
        self.identifier = identifier
        self.language = language
        self.isMale = isMale
        self.quality = quality
        self.isNovelty = isNovelty
        self.isPersonal = isPersonal
    }
}

public enum NarrationVoiceSelection {
    /// Prefer natural-quality English male voices; prefer US English at equal quality.
    /// Never silently substitute a female or non-English voice for a requested male voice.
    public static func maleEnglishVoice(from voices: [SpeechVoiceOption]) -> SpeechVoiceOption? {
        func language(_ voice: SpeechVoiceOption) -> String {
            voice.language.replacingOccurrences(of: "_", with: "-").lowercased()
        }
        return voices.filter {
            let locale = language($0)
            return $0.isMale && !$0.isNovelty && !$0.isPersonal && (locale == "en" || locale.hasPrefix("en-"))
        }.sorted {
            if $0.quality != $1.quality { return $0.quality.rawValue > $1.quality.rawValue }
            let leftUS = language($0) == "en-us", rightUS = language($1) == "en-us"
            if leftUS != rightUS { return leftUS }
            return $0.identifier < $1.identifier
        }.first
    }
}
