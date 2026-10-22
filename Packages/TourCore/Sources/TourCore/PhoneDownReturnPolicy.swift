import Foundation

public struct PhoneDownReturnState: Equatable, Sendable {
    public var phoneWasRaised = false
    public var horizontalSince: Date?

    public init() {}
}

/// Leaving AR by laying the phone flat. The phone must be raised first, then held
/// screen-up and level for two seconds. Opening the camera already flat does not exit.
public enum PhoneDownReturnPolicy {
    public static func shouldReturnToMap(
        _ state: inout PhoneDownReturnState,
        x: Double, y: Double, z: Double,
        isLeaving: Bool,
        now: Date
    ) -> Bool {
        guard !isLeaving else { return false }
        let screenUpHorizontal = z < -0.92 && abs(x) < 0.35 && abs(y) < 0.35
        if abs(z) < 0.70 {
            state.phoneWasRaised = true
            state.horizontalSince = nil
        } else if state.phoneWasRaised && screenUpHorizontal {
            if let since = state.horizontalSince {
                if now.timeIntervalSince(since) >= 2 {
                    return true
                }
            } else {
                state.horizontalSince = now
            }
        } else {
            state.horizontalSince = nil
        }
        return false
    }
}
