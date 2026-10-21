import Foundation

/// Which location problem the tour should show. The app keeps the user-facing copy.
public enum LocationGuidance {
    public enum Permission: Equatable, Sendable {
        case notDetermined
        case denied
        case restricted
        case authorized
    }

    public enum Failure: Equatable, Sendable {
        case denied
        case locationUnknown
        case network
        case other(String)
    }

    public enum Issue: Equatable, Sendable {
        case permissionNotDetermined
        case permissionDenied
        case permissionRestricted
        case reducedAccuracy
        case waitingForSignal
        case poorAccuracy(meters: Double)
        case failure(String)
    }

    public static let networkFailureMessage = "Location needs a network connection right now."

    /// Same precedence as the tour's location banner: permission first, then a failure that
    /// arrived before any fix, then approximate location, then a weak but precise fix.
    public static func issue(
        permission: Permission,
        isPrecise: Bool,
        hasLocation: Bool,
        horizontalAccuracy: Double?,
        failure: Failure?,
        poorAccuracyMeters: Double
    ) -> Issue? {
        switch permission {
        case .notDetermined:
            return .permissionNotDetermined
        case .denied:
            return .permissionDenied
        case .restricted:
            return .permissionRestricted
        case .authorized:
            if let failure, !hasLocation {
                switch failure {
                case .denied: return .permissionDenied
                case .locationUnknown: return .waitingForSignal
                case .network: return .failure(networkFailureMessage)
                case .other(let text): return .failure(text)
                }
            } else if !isPrecise {
                return .reducedAccuracy
            } else if let horizontalAccuracy, hasLocation, horizontalAccuracy > poorAccuracyMeters {
                return .poorAccuracy(meters: horizontalAccuracy)
            } else if hasLocation {
                return nil
            } else {
                return .waitingForSignal
            }
        }
    }
}
