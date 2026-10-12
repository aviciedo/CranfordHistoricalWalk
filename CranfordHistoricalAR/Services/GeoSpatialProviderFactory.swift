import Foundation
import TourCore

/// Chooses ARCore Geospatial or Core Location from the current flags, consent, permissions,
/// network and (when the SDK is linked) a cheap device-support probe. Never starts a camera
/// or a second `CLLocationManager`.
@MainActor
enum GeoSpatialProviderFactory {
    static var isSDKLinked: Bool {
        #if canImport(ARCoreGeospatial)
        true
        #else
        false
        #endif
    }

    static func selection(
        configuration: AppConfiguration,
        locationAuthorized: Bool,
        preciseLocation: Bool,
        userConsented: Bool = ARCoreConsentStore.hasAccepted,
        networkAvailable: Bool = NetworkPathMonitor.shared.isSatisfied,
        deviceSupportsGeospatial: Bool = true
    ) -> GeoSpatialSelection {
        GeoSpatialSelector.select(GeoSpatialSelectionInput(
            sdkLinked: isSDKLinked,
            flagEnabled: configuration.arCoreGeospatialEnabled,
            hasAPIKey: configuration.hasARCoreKey,
            userConsented: userConsented,
            deviceSupportsGeospatial: deviceSupportsGeospatial,
            locationAuthorized: locationAuthorized,
            preciseLocation: preciseLocation,
            networkAvailable: networkAvailable
        ))
    }

    @MainActor
    static func make(
        configuration: AppConfiguration,
        locationAuthorized: Bool,
        preciseLocation: Bool,
        userConsented: Bool = ARCoreConsentStore.hasAccepted,
        networkAvailable: Bool = NetworkPathMonitor.shared.isSatisfied
    ) -> any GeoSpatialProvider {
        let chosen = selection(
            configuration: configuration,
            locationAuthorized: locationAuthorized,
            preciseLocation: preciseLocation,
            userConsented: userConsented,
            networkAvailable: networkAvailable
        )
        if chosen.usesARCore {
            return ARCoreGeoSpatialProvider(apiKey: configuration.googleARCoreAPIKey)
        }
        return CoreLocationGeoSpatialProvider(fallbackReason: chosen.fallbackReason)
    }
}
