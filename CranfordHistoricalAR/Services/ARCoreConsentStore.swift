import Foundation

/// First-run acceptance of Google's Geospatial data-processing notice.
/// Keys stay on-device; this is not an API credential.
enum ARCoreConsentStore {
    static let defaultsKey = "arcoreGeospatialConsentAccepted"

    static var hasAccepted: Bool {
        UserDefaults.standard.bool(forKey: defaultsKey)
    }

    static func accept() {
        UserDefaults.standard.set(true, forKey: defaultsKey)
    }

    static func resetForTests(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: defaultsKey)
    }
}
