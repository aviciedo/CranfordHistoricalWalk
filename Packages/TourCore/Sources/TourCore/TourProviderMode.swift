import Foundation

/// Launch-scoped testing policy. Release builds always resolve to the configured default.
public enum TourProviderMode: String, CaseIterable, Sendable {
    case automatic
    case googleOnly
    case appleOnly

    public enum MapBackend: Equatable, Sendable { case google, apple, unavailable }

    public var title: String {
        switch self {
        case .automatic: return "Google + Apple fallback"
        case .googleOnly: return "Google only"
        case .appleOnly: return "Apple only"
        }
    }

    public var allowsNativeARFallback: Bool { self != .googleOnly }

    public func mapBackend(googleConfigured: Bool) -> MapBackend {
        if self == .appleOnly { return .apple }
        if googleConfigured { return .google }
        return self == .googleOnly ? .unavailable : .apple
    }

    public static func launchMode(storedValue: String?, developerEnabled: Bool) -> Self {
        guard developerEnabled, let storedValue, let mode = Self(rawValue: storedValue) else { return .automatic }
        return mode
    }
}
