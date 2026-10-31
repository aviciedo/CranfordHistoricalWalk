import Foundation

/// Caps reliable compass updates at 5 Hz. An unreliable sample always passes and moves the clock.
/// Stopping the location stream must clear the clock so the next heading is not suppressed.
public struct HeadingPublicationGate: Sendable {
    public private(set) var lastPublication: Date?
    public init() {}

    public mutating func reset() { lastPublication = nil }

    public mutating func shouldPublish(isReliable: Bool, timestamp: Date) -> Bool {
        if isReliable, let lastPublication, timestamp.timeIntervalSince(lastPublication) < 0.2 {
            return false
        }
        lastPublication = timestamp
        return true
    }
}
