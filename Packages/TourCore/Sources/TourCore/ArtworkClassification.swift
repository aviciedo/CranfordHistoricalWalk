import Foundation

public enum ArtworkKind: Equatable, Sendable {
    case photograph
    case illustration
}

/// How a stop image is labeled. A placeholder must stay visibly marked; a photo-based
/// illustration is not a placeholder just because its file name says "illustration".
public struct ArtworkClassification: Equatable, Sendable {
    public var kind: ArtworkKind
    public var isPlaceholder: Bool

    public init(kind: ArtworkKind, isPlaceholder: Bool) {
        self.kind = kind
        self.isPlaceholder = isPlaceholder
    }

    /// Local asset names containing "illustration" are drawings. Names that start with
    /// "placeholder", and every image of a sample stop, must be labeled as stand-ins.
    public static func localAsset(named name: String, isSample: Bool) -> ArtworkClassification {
        let normalized = name.lowercased()
        return ArtworkClassification(
            kind: normalized.contains("illustration") ? .illustration : .photograph,
            isPlaceholder: isSample || normalized.hasPrefix("placeholder")
        )
    }

    /// Remote photographs and illustrations are placeholders only when the stop itself is sample data.
    public static func remote(kind: ArtworkKind, isSample: Bool) -> ArtworkClassification {
        ArtworkClassification(kind: kind, isPlaceholder: isSample)
    }

    /// Only ordinary web and file URLs are fetched. Anything else is treated as no image.
    public static func allowsDownload(scheme: String?, isFileURL: Bool) -> Bool {
        scheme == "https" || scheme == "http" || isFileURL
    }

    public static func acceptsHTTPStatus(_ statusCode: Int) -> Bool {
        (200..<300).contains(statusCode)
    }

    /// Failed lookups stay suppressed until this interval has elapsed, then they may be tried again.
    public static let failureRetryInterval: TimeInterval = 120

    public static func shouldSuppressRetry(failedAt: Date, now: Date, interval: TimeInterval = failureRetryInterval) -> Bool {
        now.timeIntervalSince(failedAt) < interval
    }
}
