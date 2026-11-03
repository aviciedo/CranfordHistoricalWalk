import Foundation

/// Launch-scoped testing policy. Release builds always resolve to the configured default.
public enum TourProviderMode: String, CaseIterable, Sendable {
    case automatic
    case googleOnly
    case appleOnly

    public enum MapBackend: Equatable, Sendable { case google, apple, unavailable }

    public enum WalkingDirectionsPlan: Equatable, Sendable {
        case apple
        case googleOnly
        case googleWithAppleFallback
        case googleUnavailable
    }

    /// `passthrough` keeps the ordinary HUD. `suppressed` is a usable Google fix with nothing to say.
    public enum StrictGoogleARStatus: Equatable, Sendable {
        case passthrough
        case suppressed
        case text(String)
    }

    public static let googleOnlyDirectionsUnavailable = "Google-only walking directions require a valid Routes API key. Apple fallback is disabled."

    public var title: String {
        switch self {
        case .automatic: return "Google + Apple fallback"
        case .googleOnly: return "Google only"
        case .appleOnly: return "Apple only"
        }
    }

    public var allowsNativeARFallback: Bool { self != .googleOnly }

    /// Apple-only must not initialize the Google Maps SDK. The other modes still may.
    public var initializesGoogleMapsSDK: Bool { self != .appleOnly }

    /// The launch flag that decides whether walking AR asks for ARCore consent.
    public func requestsARCoreGeospatial(plistEnabled: Bool) -> Bool {
        switch self {
        case .appleOnly: return false
        case .googleOnly: return true
        case .automatic: return plistEnabled
        }
    }

    public func mapBackend(googleConfigured: Bool) -> MapBackend {
        if self == .appleOnly { return .apple }
        if googleConfigured { return .google }
        return self == .googleOnly ? .unavailable : .apple
    }

    public func mapBackendTitle(googleConfigured: Bool) -> String {
        switch mapBackend(googleConfigured: googleConfigured) {
        case .google: return "Google Maps"
        case .apple: return "Apple Maps"
        case .unavailable: return "Google unavailable; fallback disabled"
        }
    }

    /// Routes-key and maps-key are separate. Strict Google can route without a maps key,
    /// and the default mode must not treat a routes key alone as permission to call Google.
    public func walkingDirectionsPlan(hasRoutesKey: Bool, hasMapsKey: Bool) -> WalkingDirectionsPlan {
        if self == .appleOnly { return .apple }
        guard hasRoutesKey, self == .googleOnly || hasMapsKey else {
            return self == .googleOnly ? .googleUnavailable : .apple
        }
        return self == .googleOnly ? .googleOnly : .googleWithAppleFallback
    }

    public static func launchMode(storedValue: String?, developerEnabled: Bool) -> Self {
        guard developerEnabled, let storedValue, let mode = Self(rawValue: storedValue) else { return .automatic }
        return mode
    }

    public static func developerGoogleOnlyUnavailable(_ reason: GeoSpatialFallbackReason) -> String {
        "Google-only AR unavailable (\(reason.rawValue)); Apple positioning fallback is disabled."
    }

    /// Plaque scanning keeps its own sentences in every provider mode. A usable Google fix
    /// outranks a leftover failure reason. That reason outranks a tracking failure, which
    /// outranks the waiting sentence. Limited tracking is not a failure message.
    public static func strictGoogleARStatus(
        isPlaqueScanner: Bool,
        allowsNativeFallback: Bool,
        isUsable: Bool,
        navigationNotice: String?,
        coverageMessage: String?,
        fallbackReason: GeoSpatialFallbackReason?,
        failureMessage: String?,
        interruptionMessage: String?
    ) -> StrictGoogleARStatus {
        guard !isPlaqueScanner, !allowsNativeFallback else { return .passthrough }
        if isUsable {
            if let navigationNotice { return .text(navigationNotice) }
            if let coverageMessage { return .text(coverageMessage) }
            return .suppressed
        }
        if let fallbackReason {
            return .text("Google-only AR is unavailable (\(fallbackReason.rawValue)). Check ARCore setup, consent and location. Apple positioning fallback is disabled.")
        }
        if let failureMessage { return .text(failureMessage) }
        if let interruptionMessage { return .text(interruptionMessage) }
        return .text("Google-only AR is waiting for localization. Apple positioning fallback is disabled.")
    }
}
