import Foundation

/// Row status on the Stops list. A passport stamp or a story is not a status.
public enum StopListStatus {
    /// Stamp and story times stay in the signature so neither can become a second row status
    /// without changing this decision.
    public static func labels(visitedAt: Date?, plaqueUnlockedAt _: Date?, listenedAt _: Date?,
                              readAt _: Date?, isItineraryComplete: Bool) -> [String] {
        if visitedAt != nil || isItineraryComplete { return ["Visited"] }
        return []
    }
}
