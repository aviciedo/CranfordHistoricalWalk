import Foundation

/// Build-time configuration read from Info.plist, which is populated from Config/*.xcconfig.
/// API keys are never hard-coded; the iOS bundle id fallback is the shipping identifier.
struct AppConfiguration: Sendable, Equatable {
    enum DirectionsProvider: String, Sendable {
        case routes
        case legacy
    }

    var googleMapsAPIKey: String
    var googleRoutesAPIKey: String
    var googleARCoreAPIKey: String
    var directionsProvider: DirectionsProvider
    var arCoreGeospatialEnabled: Bool

    var hasGoogleMapsKey: Bool { AppConfiguration.looksLikeKey(googleMapsAPIKey) }
    var hasRoutesKey: Bool { AppConfiguration.looksLikeKey(googleRoutesAPIKey) }
    var hasARCoreKey: Bool { AppConfiguration.looksLikeKey(googleARCoreAPIKey) }

    static let expectedBundleIdentifier = GoogleAPIClientIdentity.expectedIOSBundleIdentifier

    /// Bundle id sent on every Google iOS request. Never empty — an empty `CFBundleIdentifier`
    /// (unexpanded `$(PRODUCT_BUNDLE_IDENTIFIER)`) is what Google reports as `<empty>`.
    static func iosBundleIdentifier(from bundle: Bundle = .main) -> String {
        let raw = bundle.bundleIdentifier
            ?? (bundle.object(forInfoDictionaryKey: kCFBundleIdentifierKey as String) as? String)
            ?? (bundle.infoDictionary?["CFBundleIdentifier"] as? String)
        return GoogleAPIClientIdentity.resolvedIOSBundleIdentifier(raw)
    }

    static func fromMainBundle() -> AppConfiguration {
        from(bundle: .main)
    }

    static func from(bundle: Bundle) -> AppConfiguration {
        func string(_ key: String) -> String {
            (bundle.object(forInfoDictionaryKey: key) as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        let routes = string("GoogleRoutesAPIKey")
        let arcore = string("GoogleARCoreAPIKey")
        return AppConfiguration(
            googleMapsAPIKey: string("GoogleMapsAPIKey"),
            googleRoutesAPIKey: routes,
            googleARCoreAPIKey: AppConfiguration.looksLikeKey(arcore) ? arcore : routes,
            directionsProvider: DirectionsProvider(rawValue: string("DirectionsProvider").lowercased()) ?? .routes,
            arCoreGeospatialEnabled: string("EnableARCoreGeospatial") == "1"
        )
    }

    /// Treats the template placeholder and unexpanded `$(VAR)` as "no key".
    static func looksLikeKey(_ value: String) -> Bool {
        !value.isEmpty && !value.hasPrefix("$(") && !value.contains("your-")
    }

    static let empty = AppConfiguration(googleMapsAPIKey: "", googleRoutesAPIKey: "", googleARCoreAPIKey: "", directionsProvider: .routes, arCoreGeospatialEnabled: false)
}
