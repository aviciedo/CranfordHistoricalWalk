import Foundation

/// iOS client identity for Google Maps / Routes / ARCore API-key restrictions.
///
/// Restricted iOS keys require `X-Ios-Bundle-Identifier` (and a matching `CFBundleIdentifier`).
/// An empty or unexpanded value is sent to Google as `<empty>` and the request is blocked.
public enum GoogleAPIClientIdentity {
    public static let expectedIOSBundleIdentifier = "com.cranford.historicalar"
    public static let iosBundleIdentifierHeader = "X-Ios-Bundle-Identifier"

    /// Never returns empty or an unexpanded `$(VAR)`. Falls back to the shipping bundle id.
    public static func resolvedIOSBundleIdentifier(_ raw: String?) -> String {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty || trimmed.hasPrefix("$(") {
            return expectedIOSBundleIdentifier
        }
        return trimmed
    }

    public static func isBlockedClientMessage(_ message: String?) -> Bool {
        guard let message else { return false }
        let lower = message.lowercased()
        return lower.contains("are blocked") || (lower.contains("ios client") && lower.contains("blocked"))
    }

    /// Actionable copy for Cloud Console when Routes/Maps reject the iOS client. Does not include keys.
    public static func userFacingRoutesError(
        code: Int?,
        status: String?,
        message: String?,
        bundleIdentifier: String = expectedIOSBundleIdentifier
    ) -> String {
        let id = resolvedIOSBundleIdentifier(bundleIdentifier)
        let text = message ?? ""
        let lower = text.lowercased()
        if isBlockedClientMessage(text) || lower.contains("<empty>") {
            return "Google blocked walking directions because the iOS bundle id on the request was missing or empty. This app sends \(id). In Google Cloud Console: enable the Routes API, restrict the API key to iOS apps with bundle ID \(id) (not blank), then rebuild. The last known route is kept."
        }
        if lower.contains("has not been used") || lower.contains("is disabled") || lower.contains("service_disabled") {
            return "The Routes API is not enabled on this Google Cloud project. Enable “Routes API” (not the legacy Directions API), restrict the key to iOS bundle ID \(id), then retry. The last known route is kept."
        }
        if !text.isEmpty { return text }
        let codeText = code.map { "HTTP \($0)" } ?? "Routes API"
        let statusText = status.map { " \($0)" } ?? ""
        return "\(codeText)\(statusText): walking directions were refused. Enable Routes API and restrict the key to iOS bundle ID \(id)."
    }
}
