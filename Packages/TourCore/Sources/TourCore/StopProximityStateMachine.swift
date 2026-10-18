import Foundation

/// Lifecycle of the AR sign for one stop (spec §9).
public enum StopProximityState: String, Sendable, Equatable, Codable {
    /// Far away; navigation arrows point here.
    case approaching
    /// Inside the arrival radius but the sign has not been shown yet (one update tick, or when
    /// the AR view is not open so the sign cannot be rendered).
    case nearby
    /// Sign is visible. Entered automatically on arrival or manually by the user.
    case signPresented
    /// User closed the sign (or walked away). Will not auto-reopen until they leave and come back.
    case signDismissed
    /// Stop has been visited and the tour has moved on.
    case completed
}

public enum StopProximityEvent: Sendable, Equatable {
    case distanceUpdated(meters: Double)
    case userOpenedSign
    case userClosedSign
    case signWasPresented
    case markCompleted
    case reset
}

public enum StopProximityEffect: Sendable, Equatable {
    case presentSign
    case dismissSign
    case stopCompleted
}

/// Pure state machine with hysteresis: opens at `arrivalRadius`, closes beyond `departureRadius`.
/// `departureRadius` > `arrivalRadius` prevents flapping when the user hovers on the boundary.
public struct StopProximityStateMachine: Sendable, Equatable {
    public private(set) var state: StopProximityState
    public let arrivalRadius: Double
    public let departureRadius: Double
    /// Set once the user explicitly dismissed; prevents auto-reopen until they leave the departure radius.
    public private(set) var hasManuallyDismissed: Bool
    /// Arrival/presentation history only. A recorded visit requires separate marker activation.
    public private(set) var hasPresentedSign: Bool
    public private(set) var lastDistance: Double?

    public init(arrivalRadius: Double, departureRadius: Double, state: StopProximityState = .approaching) {
        precondition(departureRadius >= arrivalRadius, "departureRadius must be >= arrivalRadius for hysteresis")
        self.arrivalRadius = arrivalRadius
        self.departureRadius = departureRadius
        self.state = state
        self.hasManuallyDismissed = false
        self.hasPresentedSign = false
        self.lastDistance = nil
    }

    public init(stop: HistoricalStop, state: StopProximityState = .approaching) {
        self.init(arrivalRadius: stop.arrivalRadius, departureRadius: stop.effectiveDepartureRadius, state: state)
    }

    public var isWithinArrivalRadius: Bool {
        guard let d = lastDistance else { return false }
        return d <= arrivalRadius
    }

    @discardableResult
    public mutating func handle(_ event: StopProximityEvent) -> [StopProximityEffect] {
        switch (state, event) {
        case (_, .reset):
            self = StopProximityStateMachine(arrivalRadius: arrivalRadius, departureRadius: departureRadius)
            return []

        case (.completed, .markCompleted):
            return []
        case (_, .markCompleted):
            let wasShowing = state == .signPresented
            state = .completed
            return wasShowing ? [.dismissSign, .stopCompleted] : [.stopCompleted]

        case (.completed, _):
            return []

        case (_, .distanceUpdated(let meters)):
            lastDistance = meters
            return handleDistance(meters)

        case (.signPresented, .userOpenedSign):
            return []
        case (_, .userOpenedSign):
            state = .signPresented
            hasPresentedSign = true
            hasManuallyDismissed = false
            return [.presentSign]

        case (.signPresented, .userClosedSign):
            state = .signDismissed
            hasManuallyDismissed = true
            return [.dismissSign]
        case (_, .userClosedSign):
            return []

        case (.nearby, .signWasPresented):
            state = .signPresented
            hasPresentedSign = true
            return []
        case (_, .signWasPresented):
            return []
        }
    }

    private mutating func handleDistance(_ meters: Double) -> [StopProximityEffect] {
        switch state {
        case .approaching:
            if meters <= arrivalRadius {
                state = .signPresented
                hasPresentedSign = true
                return [.presentSign]
            }
            return []

        case .nearby:
            if meters > departureRadius {
                state = .approaching
                return []
            }
            if meters <= arrivalRadius {
                state = .signPresented
                hasPresentedSign = true
                return [.presentSign]
            }
            return []

        case .signPresented:
            if meters > departureRadius {
                state = .signDismissed
                return [.dismissSign]
            }
            return []

        case .signDismissed:
            // Hysteresis: leaving the departure radius re-arms automatic presentation.
            if meters > departureRadius {
                state = .approaching
                hasManuallyDismissed = false
            }
            return []

        case .completed:
            return []
        }
    }
}
