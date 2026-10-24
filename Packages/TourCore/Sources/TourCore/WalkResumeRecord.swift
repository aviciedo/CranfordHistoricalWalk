import Foundation

/// Device-local itinerary context. Restoring this never constitutes a visit or permission grant.
public struct WalkResumeRecord: Codable, Equatable, Sendable {
    public var catalogIdentity: TourCatalogIdentity?
    public var sessionID: UUID?
    public var version: Int
    public var progress: TourProgress
    public var completionSummary: TourSummary?

    public init(progress: TourProgress, completionSummary: TourSummary? = nil, catalogIdentity: TourCatalogIdentity? = nil, sessionID: UUID? = nil) {
        self.catalogIdentity = catalogIdentity
        self.sessionID = sessionID
        version = 1
        self.progress = progress
        self.completionSummary = completionSummary
    }

    public func isValid(for identity: TourCatalogIdentity, stopIDs: [String]) -> Bool {
        guard identity.isValid, (catalogIdentity ?? .legacy) == identity else { return false }
        return isValid(for: stopIDs)
    }

    /// Reject changed catalogs and malformed positions rather than routing to an unrelated stop.
    public func isValid(for stopIDs: [String]) -> Bool {
        guard version == 1, !stopIDs.isEmpty, Set(stopIDs).count == stopIDs.count,
              progress.stopIDs == stopIDs, stopIDs.indices.contains(progress.currentIndex),
              Set(progress.completedStopIDs).count == progress.completedStopIDs.count,
              Set(progress.completedStopIDs).isSubset(of: Set(stopIDs)),
              progress.walkedMeters.isFinite, progress.walkedMeters >= 0 else { return false }
        guard progress.phase != .notStarted, let start = progress.startedAt,
              start.timeIntervalSince1970.isFinite else { return false }
        if progress.phase == .complete {
            guard progress.currentIndex == stopIDs.count - 1,
                  let end = progress.completedAt, end >= start else { return false }
        } else if progress.completedAt != nil { return false }
        if let summary = completionSummary {
            guard summary.stopCount == stopIDs.count, summary.totalDistanceMeters.isFinite,
                  summary.totalDistanceMeters >= 0, summary.totalWalkingSeconds.isFinite,
                  summary.totalWalkingSeconds >= 0, summary.totalVisitSeconds.isFinite,
                  summary.totalVisitSeconds >= 0, summary.pendingLegCount >= 0 else { return false }
        }
        return true
    }
}
