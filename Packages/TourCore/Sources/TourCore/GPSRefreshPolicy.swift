import Foundation

/// Decides when a developer GPS refresh may tell the user a new device fix arrived.
/// The wait itself lives in the app; this is the acceptance rule that wait uses.
public enum GPSRefreshPolicy {
    public struct Fix: Equatable, Sendable {
        public var timestamp: Date
        public var isSimulated: Bool
        /// Meters. Core Location uses a negative value for an invalid coordinate.
        public var horizontalAccuracy: Double

        public init(timestamp: Date, isSimulated: Bool, horizontalAccuracy: Double) {
            self.timestamp = timestamp
            self.isSimulated = isSimulated
            self.horizontalAccuracy = horizontalAccuracy
        }
    }

    public enum Tick: Equatable, Sendable {
        case keepWaiting
        case stoppedBecauseSimulating
        case receivedFreshFix
    }

    /// Simulation wins over a sample that would otherwise look fresh, matching the
    /// order of the developer refresh loop.
    public static func tick(isSimulating: Bool, fix: Fix?, requestedAt: Date) -> Tick {
        if isSimulating { return .stoppedBecauseSimulating }
        if isFreshDeviceFix(fix, requestedAt: requestedAt) { return .receivedFreshFix }
        return .keepWaiting
    }

    /// A fix counts only when it is stamped at or after the request, came from the
    /// device rather than the simulator, and reports a finite accuracy of zero or more.
    public static func isFreshDeviceFix(_ fix: Fix?, requestedAt: Date) -> Bool {
        guard let fix else { return false }
        return fix.timestamp >= requestedAt
            && !fix.isSimulated
            && fix.horizontalAccuracy.isFinite
            && fix.horizontalAccuracy >= 0
    }
}
