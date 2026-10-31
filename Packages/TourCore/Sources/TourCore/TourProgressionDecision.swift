import Foundation

/// A single explanation of the existing automatic-navigation gates, without side effects.
public struct TourProgressionDecision: Equatable, Sendable {
    public enum Blocker: String, Codable, Sendable {
        case walkStopped, mapNotVisible, exploring, arActive
        case visitIncomplete, departureHeld, noNextStop, noDestination
    }
    public let navigationBlockers: [Blocker]
    public let advanceBlockers: [Blocker]
    public var canNavigateAutomatically: Bool { navigationBlockers.isEmpty }
    public var canAdvance: Bool { advanceBlockers.isEmpty }

    public init(walking: Bool, mapVisible: Bool, exploring: Bool, arActive: Bool,
                visitConfirmed: Bool, held: Bool, hasNextStop: Bool, hasDestination: Bool) {
        var navigation: [Blocker] = []
        if !walking { navigation.append(.walkStopped) }
        if !mapVisible { navigation.append(.mapNotVisible) }
        if exploring { navigation.append(.exploring) }
        if arActive { navigation.append(.arActive) }
        navigationBlockers = navigation
        var advancement = navigation
        if !visitConfirmed { advancement.append(.visitIncomplete) }
        if held { advancement.append(.departureHeld) }
        if !hasNextStop { advancement.append(.noNextStop) }
        if !hasDestination { advancement.append(.noDestination) }
        advanceBlockers = advancement
    }
}

/// Bounded, local diagnostic snapshots. No coordinates, device IDs or network transport.
/// The native app only creates this trace in Developer Mode builds.
public struct ProgressionDiagnostics: Sendable {
    public struct Event: Codable, Equatable, Sendable {
        public let sequence: Int
        public let date: Date
        public let stopID: String?
        public let trigger: String
        public let blockers: [TourProgressionDecision.Blocker]
        public let accuracyMeters: Double?
        public let distanceMeters: Double?
        public let fixAgeSeconds: Double?
        public let nearSeconds: Double
    }
    public private(set) var events: [Event] = []
    private var sequence = 0
    public let capacity: Int
    public init(capacity: Int = 120) { self.capacity = max(1, min(600, capacity)) }

    public mutating func record(stopID: String?, trigger: String, blockers: [TourProgressionDecision.Blocker],
                                accuracy: Double? = nil, distance: Double? = nil, fixAge: Double? = nil,
                                nearSeconds: Double, now: Date = Date()) {
        // Sample unchanged GPS status at most every five seconds, but never lose a transition.
        if let last = events.last, last.stopID == stopID, last.trigger == trigger,
           last.blockers == blockers, now >= last.date, now.timeIntervalSince(last.date) < 5 { return }
        func finite(_ value: Double?) -> Double? { value.flatMap { $0.isFinite ? $0 : nil } }
        sequence += 1
        events.append(Event(sequence: sequence, date: now, stopID: stopID, trigger: trigger,
            blockers: blockers, accuracyMeters: finite(accuracy), distanceMeters: finite(distance),
            fixAgeSeconds: finite(fixAge), nearSeconds: finite(nearSeconds) ?? 0))
        if events.count > capacity { events.removeFirst(events.count - capacity) }
    }

    public var exportJSON: String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(events)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }
}
