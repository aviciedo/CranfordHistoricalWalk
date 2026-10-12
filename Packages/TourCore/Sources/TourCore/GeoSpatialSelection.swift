import Foundation

/// How much to trust geographic placement of AR content (spec §15, §21).
public enum GeoLocalizationQuality: Equatable, Sendable {
    /// No fix, no tracking, or the provider is not attached.
    case unavailable
    /// Fix exists but accuracy is poor (> 25 m GPS-class, or heading error > 30°).
    case poor
    /// Typical outdoor GPS + compass, or Geospatial without VPS.
    case fair
    /// VPS-grade (~5 m / 5°) or very good GPS.
    case good

    public var isUsable: Bool { self == .fair || self == .good }
}

/// Which geographic localizer is driving AR content.
public enum GeoSpatialBackend: String, Sendable, Equatable {
    case arCoreGeospatial
    case coreLocation
}

/// Why Geospatial was not used (or was abandoned). `nil` on the happy path.
public enum GeoSpatialFallbackReason: String, Sendable, Equatable {
    case flagDisabled
    case sdkNotLinked
    case missingAPIKey
    case missingUserConsent
    case deviceUnsupported
    case locationPermissionDenied
    case preciseLocationRequired
    case networkUnavailable
    case sessionConfigurationFailed
    case earthNotAuthorized
    case earthResourceExhausted
    case earthInternalError
    case localizationTimedOut
    case geospatialUnavailable

    public var userMessage: String {
        switch self {
        case .flagDisabled:
            return "ARCore Geospatial is off. Positioning uses GPS and compass, which is less precise."
        case .sdkNotLinked:
            return "ARCore Geospatial is not linked in this build. Positioning uses GPS and compass."
        case .missingAPIKey:
            return "No ARCore API key is configured. Positioning uses GPS and compass."
        case .missingUserConsent:
            return "ARCore data processing was not accepted. Positioning uses GPS and compass."
        case .deviceUnsupported:
            return "This device does not support ARCore Geospatial. Positioning uses GPS and compass."
        case .locationPermissionDenied:
            return "Location permission is required for Geospatial AR. Positioning uses GPS and compass when location is available."
        case .preciseLocationRequired:
            return "Precise location is required for Geospatial AR. Positioning uses GPS and compass at reduced accuracy."
        case .networkUnavailable:
            return "A network connection is required for Geospatial localization. Positioning uses GPS and compass."
        case .sessionConfigurationFailed:
            return "ARCore Geospatial could not start. Positioning uses GPS and compass."
        case .earthNotAuthorized:
            return "ARCore API authorization failed. Check the Cloud key and that the ARCore API is enabled. Positioning uses GPS and compass."
        case .earthResourceExhausted:
            return "ARCore API quota is exhausted. Positioning uses GPS and compass."
        case .earthInternalError:
            return "ARCore Geospatial hit an internal error. Positioning uses GPS and compass."
        case .localizationTimedOut:
            return "Geospatial localization did not become ready. Positioning uses GPS and compass."
        case .geospatialUnavailable:
            return "AR positioning is temporarily unavailable. Continue walking and try again."
        }
    }
}

public struct GeoSpatialSelectionInput: Equatable, Sendable {
    public var sdkLinked: Bool
    public var flagEnabled: Bool
    public var hasAPIKey: Bool
    public var userConsented: Bool
    public var deviceSupportsGeospatial: Bool
    public var locationAuthorized: Bool
    public var preciseLocation: Bool
    public var networkAvailable: Bool

    public init(
        sdkLinked: Bool,
        flagEnabled: Bool,
        hasAPIKey: Bool,
        userConsented: Bool,
        deviceSupportsGeospatial: Bool,
        locationAuthorized: Bool,
        preciseLocation: Bool,
        networkAvailable: Bool
    ) {
        self.sdkLinked = sdkLinked
        self.flagEnabled = flagEnabled
        self.hasAPIKey = hasAPIKey
        self.userConsented = userConsented
        self.deviceSupportsGeospatial = deviceSupportsGeospatial
        self.locationAuthorized = locationAuthorized
        self.preciseLocation = preciseLocation
        self.networkAvailable = networkAvailable
    }
}

public struct GeoSpatialSelection: Equatable, Sendable {
    public var backend: GeoSpatialBackend
    public var fallbackReason: GeoSpatialFallbackReason?

    public init(backend: GeoSpatialBackend, fallbackReason: GeoSpatialFallbackReason? = nil) {
        self.backend = backend
        self.fallbackReason = fallbackReason
    }

    public var usesARCore: Bool { backend == .arCoreGeospatial }
    public var reducedAccuracyMessage: String? { fallbackReason?.userMessage }
}

/// Visual Positioning System coverage at a coordinate (maps `GARVPSAvailability`).
public enum VPSCoverage: String, Sendable, Equatable {
    case unknown
    case available
    case unavailable
    case errorNetwork
    case errorNotAuthorized
    case errorResourceExhausted
    case errorInternal

    public var reducesAccuracy: Bool {
        switch self {
        case .available, .unknown: return false
        case .unavailable, .errorNetwork, .errorNotAuthorized, .errorResourceExhausted, .errorInternal: return true
        }
    }

    public var userMessage: String? {
        switch self {
        case .unknown: return nil
        case .available: return nil
        case .unavailable:
            return "Street-level Visual Positioning is not available here. Geospatial accuracy will be closer to ordinary GPS."
        case .errorNetwork:
            return "Could not check Visual Positioning coverage (network). Geospatial accuracy may be reduced."
        case .errorNotAuthorized:
            return "Could not check Visual Positioning coverage (ARCore API authorization)."
        case .errorResourceExhausted:
            return "Could not check Visual Positioning coverage (ARCore API quota)."
        case .errorInternal:
            return "Could not check Visual Positioning coverage."
        }
    }
}

public enum GeoSpatialSelector {
    /// Typical VPS-grade numbers published by Google for Geospatial under usual conditions.
    public static let vpsHorizontalMeters: Double = 5
    public static let vpsYawDegrees: Double = 5
    /// Seconds to wait for Earth tracking before falling back to Core Location.
    public static let localizationTimeout: TimeInterval = 12

    public static func select(_ input: GeoSpatialSelectionInput) -> GeoSpatialSelection {
        if !input.flagEnabled {
            return GeoSpatialSelection(backend: .coreLocation, fallbackReason: input.sdkLinked ? .flagDisabled : .sdkNotLinked)
        }
        if !input.sdkLinked {
            return GeoSpatialSelection(backend: .coreLocation, fallbackReason: .sdkNotLinked)
        }
        if !input.hasAPIKey {
            return GeoSpatialSelection(backend: .coreLocation, fallbackReason: .missingAPIKey)
        }
        if !input.userConsented {
            return GeoSpatialSelection(backend: .coreLocation, fallbackReason: .missingUserConsent)
        }
        if !input.deviceSupportsGeospatial {
            return GeoSpatialSelection(backend: .coreLocation, fallbackReason: .deviceUnsupported)
        }
        if !input.locationAuthorized {
            return GeoSpatialSelection(backend: .coreLocation, fallbackReason: .locationPermissionDenied)
        }
        if !input.preciseLocation {
            return GeoSpatialSelection(backend: .coreLocation, fallbackReason: .preciseLocationRequired)
        }
        if !input.networkAvailable {
            return GeoSpatialSelection(backend: .coreLocation, fallbackReason: .networkUnavailable)
        }
        return GeoSpatialSelection(backend: .arCoreGeospatial)
    }

    /// Maps horizontal (meters) and yaw (degrees) uncertainty onto the four quality buckets.
    /// Negative yaw means “unknown / invalid” (Core Location headingAccuracy convention).
    public static func quality(horizontalAccuracy: Double, yawAccuracy: Double) -> GeoLocalizationQuality {
        guard horizontalAccuracy >= 0 else { return .unavailable }
        if yawAccuracy < 0 {
            if horizontalAccuracy > 25 { return .poor }
            if horizontalAccuracy <= 8 { return .good }
            return .fair
        }
        let yaw = yawAccuracy
        if horizontalAccuracy > 25 || yaw > 30 {
            return .poor
        }
        if horizontalAccuracy <= vpsHorizontalMeters && yaw <= vpsYawDegrees {
            return .good
        }
        if horizontalAccuracy <= 8 && yaw <= 12 {
            return .good
        }
        return .fair
    }

    public static func fallbackReason(fromEarthStateCode code: Int) -> GeoSpatialFallbackReason? {
        // GAREarthStateEnabled = 0, ErrorInternal = -1, ErrorNotAuthorized = -2, ErrorResourceExhausted = -3
        switch code {
        case 0: return nil
        case -2: return .earthNotAuthorized
        case -3: return .earthResourceExhausted
        default: return .earthInternalError
        }
    }

    public static func coverage(fromVPSAvailabilityCode code: Int) -> VPSCoverage {
        // GARVPSAvailabilityUnknown = 0, Available = 1, Unavailable = 2,
        // ErrorInternal = -1, ErrorNetworkConnection = -2, ErrorNotAuthorized = -3, ErrorResourceExhausted = -4
        switch code {
        case 1: return .available
        case 2: return .unavailable
        case -2: return .errorNetwork
        case -3: return .errorNotAuthorized
        case -4: return .errorResourceExhausted
        case -1: return .errorInternal
        default: return .unknown
        }
    }
}
