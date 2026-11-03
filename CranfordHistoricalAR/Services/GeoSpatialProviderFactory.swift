import Foundation
import ARKit
import simd
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
        networkAvailable: Bool? = nil,
        deviceSupportsGeospatial: Bool = true,
        mode: TourProviderMode = .automatic
    ) -> GeoSpatialSelection {
        GeoSpatialSelector.select(GeoSpatialSelectionInput(
            sdkLinked: isSDKLinked,
            flagEnabled: configuration.arCoreGeospatialEnabled,
            hasAPIKey: configuration.hasARCoreKey,
            userConsented: userConsented,
            deviceSupportsGeospatial: deviceSupportsGeospatial,
            locationAuthorized: locationAuthorized,
            preciseLocation: preciseLocation,
            networkAvailable: networkAvailable ?? NetworkPathMonitor.shared.isSatisfied
        ), mode: mode)
    }

    @MainActor
    static func make(
        configuration: AppConfiguration,
        locationAuthorized: Bool,
        preciseLocation: Bool,
        userConsented: Bool = ARCoreConsentStore.hasAccepted,
        networkAvailable: Bool? = nil,
        mode: TourProviderMode = .automatic
    ) -> any GeoSpatialProvider {
        let chosen = selection(
            configuration: configuration,
            locationAuthorized: locationAuthorized,
            preciseLocation: preciseLocation,
            userConsented: userConsented,
            networkAvailable: networkAvailable,
            mode: mode
        )
        if mode == .googleOnly, let reason = chosen.fallbackReason {
            return UnavailableGoogleGeoSpatialProvider(reason: reason)
        }
        if chosen.usesARCore {
            return ARCoreGeoSpatialProvider(apiKey: configuration.googleARCoreAPIKey)
        }
        return CoreLocationGeoSpatialProvider(fallbackReason: chosen.fallbackReason)
    }
}

/// No Google camera data is sent when authorization/consent prerequisites fail.
/// Keeping an explicitly unavailable Google provider prevents a silent native fallback.
@MainActor
private final class UnavailableGoogleGeoSpatialProvider: GeoSpatialProvider {
    let displayName = "Google ARCore unavailable"
    let backend: GeoSpatialBackend = .arCoreGeospatial
    let quality: GeoLocalizationQuality = .unavailable
    let pose: GeoPose? = nil
    let preferredWorldAlignment: ARConfiguration.WorldAlignment = .gravity
    let fallbackReason: GeoSpatialFallbackReason?
    let vpsCoverage: VPSCoverage = .unknown

    init(reason: GeoSpatialFallbackReason) { fallbackReason = reason }
    func attach(session: ARSession) {}
    func detach() {}
    func update(cameraTransform: simd_float4x4, trackingState: ARCamera.TrackingState, timestamp: TimeInterval) {}
    func update(frame: ARFrame) {}
    func update(location: LocationSample?, heading: HeadingSample?) {}
    func worldPosition(for coordinate: GeoCoordinate, altitude: Double?, heightBelowCamera: Float) -> SIMD3<Float>? { nil }
    func worldDirection(forBearing bearing: Double) -> SIMD3<Float>? { nil }
}
