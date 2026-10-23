import Foundation

/// Independent accomplishments. None of the three activities implies either of the others.
public struct StopActivities: Codable, Equatable, Sendable {
    public var listenedAt: Date?
    public var readAt: Date?
    public var visitedAt: Date?
    public var bonusFoundAt: Date?
    public var learningCompleted: Bool { listenedAt != nil || readAt != nil }
    public init() {}
}

public struct StopActivityLedger: Codable, Equatable, Sendable {
    private var entries: [String: StopActivities] = [:]
    public init() {}
    public subscript(stopID: String) -> StopActivities { entries[stopID] ?? StopActivities() }
    public mutating func listened(to stopID: String, at date: Date = Date()) {
        var entry = self[stopID]; entry.listenedAt = entry.listenedAt ?? date; entries[stopID] = entry
    }
    public mutating func read(_ stopID: String, at date: Date = Date()) {
        var entry = self[stopID]; entry.readAt = entry.readAt ?? date; entries[stopID] = entry
    }
    public mutating func visited(_ stopID: String, at date: Date = Date()) {
        var entry = self[stopID]; entry.visitedAt = entry.visitedAt ?? date; entries[stopID] = entry
    }
    public mutating func foundBonus(at stopID: String, date: Date = Date()) {
        var entry = self[stopID]; entry.bonusFoundAt = entry.bonusFoundAt ?? date; entries[stopID] = entry
    }
    public mutating func clearVisits() {
        for id in Array(entries.keys) { entries[id]?.visitedAt = nil }
    }
    /// Upgrade existing saved history without manufacturing story completion.
    public mutating func importVisits(_ visits: [StopVisitRecord]) {
        for visit in visits where visit.evidence != .simulation {
            visited(visit.stopID, at: visit.activatedAt)
            if visit.evidence == .recognizedPlaque { foundBonus(at: visit.stopID, date: visit.activatedAt) }
        }
    }
}
