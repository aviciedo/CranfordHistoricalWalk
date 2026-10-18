import Foundation
import GoogleMaps

/// Registers the Maps SDK API key exactly once, before any `GMSMapView` is created.
@MainActor
enum GoogleMapsBootstrap {
    private(set) static var isConfigured = false

    @discardableResult
    static func configure(with configuration: AppConfiguration) -> Bool {
        guard !isConfigured else { return true }
        guard configuration.hasGoogleMapsKey else { return false }
        isConfigured = GMSServices.provideAPIKey(configuration.googleMapsAPIKey)
        return isConfigured
    }

    static var sdkVersion: String { GMSServices.sdkVersion() }
}
