import Foundation
import TourCore

@MainActor
protocol StopVisitStore: AnyObject {
    func records() -> [StopVisitRecord]
    func record(_ visit: StopVisitRecord)
    #if DEVELOPER_MENU
    func removeAll()
    #endif
}

/// Latest real activation per stop, stored only on this device. No location trail or photos.
@MainActor
final class LocalStopVisitStore: StopVisitStore {
    private let defaults: UserDefaults
    private let key = "cranford.stop-visits.v1"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func records() -> [StopVisitRecord] {
        guard let data = defaults.data(forKey: key),
              let records = try? JSONDecoder().decode([StopVisitRecord].self, from: data) else { return [] }
        return records.filter { $0.evidence != .simulation }
    }

    func record(_ visit: StopVisitRecord) {
        guard visit.evidence != .simulation else { return }
        var visits = records().filter { $0.stopID != visit.stopID }
        visits.append(visit)
        guard let data = try? JSONEncoder().encode(visits) else { return }
        defaults.set(data, forKey: key)
    }

    #if DEVELOPER_MENU
    func removeAll() {
        defaults.removeObject(forKey: key)
    }
    #endif
}

@MainActor
final class InMemoryStopVisitStore: StopVisitStore {
    private var visits: [StopVisitRecord] = []
    func records() -> [StopVisitRecord] { visits }
    func record(_ visit: StopVisitRecord) {
        guard visit.evidence != .simulation else { return }
        visits.removeAll { $0.stopID == visit.stopID }
        visits.append(visit)
    }

    #if DEVELOPER_MENU
    func removeAll() { visits.removeAll() }
    #endif
}


/// Separate persistence from the legacy visit history; browsing never writes a visit.
@MainActor
protocol StopActivityStore: AnyObject {
    func load() -> StopActivityLedger
    func save(_ ledger: StopActivityLedger)
}

@MainActor
final class LocalStopActivityStore: StopActivityStore {
    private let defaults: UserDefaults
    private let key = "cranford.stop-activities.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load() -> StopActivityLedger {
        guard let data = defaults.data(forKey: key),
              let ledger = try? JSONDecoder().decode(StopActivityLedger.self, from: data) else { return StopActivityLedger() }
        return ledger
    }
    func save(_ ledger: StopActivityLedger) {
        guard let data = try? JSONEncoder().encode(ledger) else { return }
        defaults.set(data, forKey: key)
    }
}

@MainActor
final class InMemoryStopActivityStore: StopActivityStore {
    private var ledger = StopActivityLedger()
    func load() -> StopActivityLedger { ledger }
    func save(_ ledger: StopActivityLedger) { self.ledger = ledger }
}

/// Durable recording context is independent of physical visits and learning completion.
struct NarrationBookmark: Codable, Equatable, Sendable {
    var sourceID: String
    var elapsed: Double
}

struct NarrationResumeState: Codable, Equatable, Sendable {
    var lastStoryID: String? = nil
    var bookmarks: [String: NarrationBookmark] = [:]

    /// Reject corrupt/non-finite positions rather than poisoning the player's seek state.
    func sanitized() -> NarrationResumeState {
        var result = self
        result.bookmarks = bookmarks.filter {
            !$0.key.isEmpty && !$0.value.sourceID.isEmpty && $0.value.elapsed.isFinite && $0.value.elapsed >= 0
        }
        if let id = result.lastStoryID, result.bookmarks[id] == nil { result.lastStoryID = nil }
        return result
    }
}

@MainActor
protocol NarrationResumeStore: AnyObject {
    func load() -> NarrationResumeState
    func save(_ state: NarrationResumeState)
}

@MainActor
final class LocalNarrationResumeStore: NarrationResumeStore {
    private let defaults: UserDefaults
    private let key = "cranford.narration-resume.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load() -> NarrationResumeState {
        guard let data = defaults.data(forKey: key),
              let state = try? JSONDecoder().decode(NarrationResumeState.self, from: data) else { return NarrationResumeState() }
        return state.sanitized()
    }
    func save(_ state: NarrationResumeState) {
        guard let data = try? JSONEncoder().encode(state.sanitized()) else { return }
        defaults.set(data, forKey: key)
    }
}

@MainActor
final class InMemoryNarrationResumeStore: NarrationResumeStore {
    private var state = NarrationResumeState()
    func load() -> NarrationResumeState { state }
    func save(_ state: NarrationResumeState) { self.state = state.sanitized() }
}
