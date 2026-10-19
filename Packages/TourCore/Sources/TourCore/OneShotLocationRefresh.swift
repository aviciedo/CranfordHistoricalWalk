import Foundation

/// Tracks the pause/resume around `CLLocationManager.requestLocation()`.
/// Continuous updates have to stop first: a one-shot request is ignored while they are active.
/// The manager itself stays in the app service; this only decides which transition is legal.
public struct OneShotLocationRefresh: Equatable, Sendable {
    public private(set) var isRunning: Bool
    public private(set) var isRequestingFreshLocation: Bool

    public init() {
        isRunning = false
        isRequestingFreshLocation = false
    }

    /// `true` when continuous updates were stopped and should start now.
    public mutating func startUpdating() -> Bool {
        guard !isRunning else { return false }
        isRunning = true
        return true
    }

    public enum FreshLocationRequest: Equatable, Sendable {
        case needsAuthorization
        case beginOneShot
    }

    /// Does not arm the one-shot. The service must stop continuous updates first, then
    /// call `armOneShot()` before `requestLocation()`, so a callback from the stop
    /// cannot resume updates and cause the one-shot to be ignored.
    public mutating func requestFreshLocation(isAuthorized: Bool) -> FreshLocationRequest {
        guard isAuthorized else { return .needsAuthorization }
        return .beginOneShot
    }

    public mutating func armOneShot() {
        isRequestingFreshLocation = true
    }

    public enum OneShotFinish: Equatable, Sendable {
        /// This callback is not the answer to a one-shot request.
        case ignored
        /// The one-shot ended while continuous updates were already off, so they stay off.
        case finishedIdle
        /// The one-shot ended and continuous updates must start again.
        case resumeContinuousUpdates
    }

    /// Location and failure callbacks both finish the one-shot. An empty or invalid
    /// batch still finishes it; otherwise live updates would stay paused.
    public mutating func finishOneShot() -> OneShotFinish {
        guard isRequestingFreshLocation else { return .ignored }
        isRequestingFreshLocation = false
        return isRunning ? .resumeContinuousUpdates : .finishedIdle
    }

    /// `true` when continuous updates were running and must be stopped.
    /// Cancels an in-flight one-shot so its later callback cannot restart updates.
    public mutating func stopUpdating() -> Bool {
        isRequestingFreshLocation = false
        guard isRunning else { return false }
        isRunning = false
        return true
    }
}
