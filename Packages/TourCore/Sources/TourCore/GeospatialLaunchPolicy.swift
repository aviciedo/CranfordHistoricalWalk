import Foundation

/// Launch rules for ARCore Geospatial now that the shipped flag defaults to on.
/// Consent, the provider mode, and the Apple fallback stay in one place so a
/// later edit cannot start a Google camera session without the disclosure,
/// or skip the Apple fallback when that disclosure is declined.
public enum GeospatialLaunchPolicy {
    /// Existing installs store acceptance under this key. Renaming it would
    /// show the disclosure again, or forget a decline that was never recorded.
    public static let consentDefaultsKey = "arcoreGeospatialConsentAccepted"

    /// Only the literal `1` requests Geospatial. `true`, `01`, and empty stay off.
    public static func plistRequestsGeospatial(_ raw: String) -> Bool {
        raw.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
    }

    /// Apple-only wins over the default-on flag. Google-only forces the request
    /// even when a local Secrets override left the plist off.
    public static func requestsGeospatial(plistEnabled: Bool, mode: TourProviderMode) -> Bool {
        switch mode {
        case .appleOnly: return false
        case .googleOnly: return true
        case .automatic: return plistEnabled
        }
    }

    /// Show the disclosure before any camera session when Geospatial is requested
    /// and this install has not accepted it.
    public static func shouldPresentConsent(requestsGeospatial: Bool, alreadyAccepted: Bool) -> Bool {
        requestsGeospatial && !alreadyAccepted
    }

    public static func hasAccepted(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: consentDefaultsKey)
    }

    public static func accept(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: consentDefaultsKey)
    }

    /// Decline does not write. The next AR entry asks again, and no acceptance is stored.
    public static func decline(defaults: UserDefaults = .standard) {
        _ = defaults
    }

    public static func reset(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: consentDefaultsKey)
    }
}

/// Which positioning object the factory should construct. Google-only failures
/// stay on an unavailable ARCore identity so Apple positioning cannot start.
public enum GeospatialSessionChoice: Equatable, Sendable {
    case arCore
    case coreLocation(GeoSpatialFallbackReason?)
    case googleUnavailable(GeoSpatialFallbackReason)
}

public enum GeospatialSessionResolver {
    public static func resolve(
        mode: TourProviderMode,
        geospatialRequested: Bool,
        sdkLinked: Bool,
        hasAPIKey: Bool,
        userConsented: Bool,
        deviceSupportsGeospatial: Bool = true,
        locationAuthorized: Bool,
        preciseLocation: Bool,
        networkAvailable: Bool
    ) -> GeospatialSessionChoice {
        if mode == .appleOnly {
            return .coreLocation(nil)
        }
        let chosen = GeoSpatialSelector.select(GeoSpatialSelectionInput(
            sdkLinked: sdkLinked,
            flagEnabled: mode == .googleOnly || geospatialRequested,
            hasAPIKey: hasAPIKey,
            userConsented: userConsented,
            deviceSupportsGeospatial: deviceSupportsGeospatial,
            locationAuthorized: locationAuthorized,
            preciseLocation: preciseLocation,
            networkAvailable: networkAvailable
        ))
        if mode == .googleOnly {
            if let reason = chosen.fallbackReason {
                return .googleUnavailable(reason)
            }
            return .arCore
        }
        if chosen.usesARCore {
            return .arCore
        }
        return .coreLocation(chosen.fallbackReason)
    }

    public static func selection(for choice: GeospatialSessionChoice) -> GeoSpatialSelection {
        switch choice {
        case .arCore:
            return GeoSpatialSelection(backend: .arCoreGeospatial)
        case .coreLocation(let reason):
            return GeoSpatialSelection(backend: .coreLocation, fallbackReason: reason)
        case .googleUnavailable(let reason):
            return GeoSpatialSelection(backend: .arCoreGeospatial, fallbackReason: reason)
        }
    }
}
