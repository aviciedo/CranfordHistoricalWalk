import Foundation

/// Independent reading, listening, physical visits and sketchbook collection.
public struct StopActivities: Codable, Equatable, Sendable {
    public var listenedAt: Date?
    public var readAt: Date?
    public var visitedAt: Date?
    public var plaqueUnlockedAt: Date?
    public var learningCompleted: Bool { listenedAt != nil || readAt != nil }
    // Preserve the v1 on-disk key so existing passport stamps become collected sketches.
    private enum CodingKeys: String, CodingKey {
        case listenedAt, readAt, visitedAt
        case plaqueUnlockedAt = "bonusFoundAt"
    }
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
    public mutating func collectSketch(at stopID: String, date: Date = Date()) {
        var entry = self[stopID]; entry.plaqueUnlockedAt = entry.plaqueUnlockedAt ?? date; entries[stopID] = entry
    }
    public mutating func clearVisits() {
        for id in Array(entries.keys) { entries[id]?.visitedAt = nil }
    }
    /// Upgrade existing saved history without manufacturing story completion.
    public mutating func importVisits(_ visits: [StopVisitRecord]) {
        for visit in visits where visit.evidence != .simulation {
            visited(visit.stopID, at: visit.activatedAt)
            if visit.evidence == .recognizedPlaque { collectSketch(at: visit.stopID, date: visit.activatedAt) }
        }
    }
}
