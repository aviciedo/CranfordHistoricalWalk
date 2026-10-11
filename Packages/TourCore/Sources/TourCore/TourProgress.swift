import Foundation

public enum TourPhase: String, Sendable, Equatable, Codable {
    case notStarted
    case inProgress
    case complete
}

/// Serializable progress through the ordered list of stops. Owned by `TourViewModel`.
public struct TourProgress: Sendable, Equatable, Codable {
    public private(set) var stopIDs: [String]
    public private(set) var completedStopIDs: [String]
    public private(set) var currentIndex: Int
    public private(set) var phase: TourPhase
    public private(set) var startedAt: Date?
    public private(set) var completedAt: Date?
    /// Meters actually walked, accumulated from location updates during the tour.
    public private(set) var walkedMeters: Double

    public init(stopIDs: [String]) {
        self.stopIDs = stopIDs
        self.completedStopIDs = []
        self.currentIndex = 0
        self.phase = .notStarted
        self.walkedMeters = 0
    }

    public var currentStopID: String? {
        guard phase == .inProgress, stopIDs.indices.contains(currentIndex) else { return nil }
        return stopIDs[currentIndex]
    }

    public var nextStopID: String? {
        let next = currentIndex + 1
        guard phase == .inProgress, stopIDs.indices.contains(next) else { return nil }
        return stopIDs[next]
    }

    /// Most recently visited stop other than the current one (the "CURRENT ✓" line of the panel).
    /// The current stop can itself be marked visited while its sign is open; it is excluded so the
    /// panel never lists the same stop twice.
    public var previousCompletedStopID: String? {
        completedStopIDs.last { $0 != currentStopID }
    }

    /// True once the current stop's sign has been displayed, before the tour has moved on.
    public var isCurrentStopVisited: Bool {
        guard let current = currentStopID else { return false }
        return completedStopIDs.contains(current)
    }
    public var totalStops: Int { stopIDs.count }
    public var completedCount: Int { completedStopIDs.count }
    public var remainingStopIDs: ArraySlice<String> {
        guard phase == .inProgress, stopIDs.indices.contains(currentIndex) else { return [] }
        return stopIDs[currentIndex...]
    }

    public func isCompleted(_ stopID: String) -> Bool { completedStopIDs.contains(stopID) }

    public var elapsed: TimeInterval? {
        guard let startedAt else { return nil }
        return (completedAt ?? Date()).timeIntervalSince(startedAt)
    }

    // MARK: Mutations

    public mutating func start(at date: Date = Date()) {
        guard phase == .notStarted, !stopIDs.isEmpty else { return }
        phase = .inProgress
        currentIndex = 0
        completedStopIDs = []
        walkedMeters = 0
        startedAt = date
        completedAt = nil
    }

    /// Marks the current stop visited without advancing (spec §11: the marker changes as soon as
    /// the sign has been displayed; the panel advances when the user is done with the sign).
    /// Returns true if the stop was newly marked.
    @discardableResult
    public mutating func markCurrentStopVisited() -> Bool {
        guard phase == .inProgress, let current = currentStopID, !completedStopIDs.contains(current) else { return false }
        completedStopIDs.append(current)
        return true
    }

    /// Marks the current stop visited and advances. Returns the new current stop, or `nil` when done.
    @discardableResult
    public mutating func completeCurrentStop(at date: Date = Date()) -> String? {
        guard phase == .inProgress, currentStopID != nil else { return nil }
        markCurrentStopVisited()
        if stopIDs.indices.contains(currentIndex + 1) {
            currentIndex += 1
            return stopIDs[currentIndex]
        }
        phase = .complete
        completedAt = date
        return nil
    }

    /// Developer tool: jump directly to a stop, marking skipped stops neither complete nor current.
    public mutating func jump(toIndex index: Int) {
        guard stopIDs.indices.contains(index) else { return }
        if phase == .notStarted { start() }
        if phase == .complete { phase = .inProgress; completedAt = nil }
        currentIndex = index
        completedStopIDs.removeAll { stopIDs.firstIndex(of: $0).map { $0 >= index } ?? true }
    }

    public mutating func recordWalked(meters: Double) {
        guard phase == .inProgress, meters.isFinite, meters > 0 else { return }
        walkedMeters += meters
    }

    public mutating func reset() {
        self = TourProgress(stopIDs: stopIDs)
    }
}
