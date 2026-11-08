import Foundation

/// First-run acceptance of Google's Geospatial data-processing notice.
/// Keys stay on-device; this is not an API credential.
enum ARCoreConsentStore {
    static let defaultsKey = GeospatialLaunchPolicy.consentDefaultsKey

    static var hasAccepted: Bool {
        GeospatialLaunchPolicy.hasAccepted()
    }

    static func accept() {
        GeospatialLaunchPolicy.accept()
    }

    static func decline() {
        GeospatialLaunchPolicy.decline()
    }

    static func resetForTests(_ defaults: UserDefaults = .standard) {
        GeospatialLaunchPolicy.reset(defaults)
    }
}
