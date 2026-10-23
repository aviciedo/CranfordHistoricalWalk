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
