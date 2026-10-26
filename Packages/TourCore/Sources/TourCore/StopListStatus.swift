import Foundation

/// Stops-list accomplishments. Reading and listening stay off this list so they
/// cannot be mistaken for a physical visit or an on-site bonus.
public enum StopListStatus {
    public static let visited = "Visited"
    public static let bonusUnlocked = "On-site bonus unlocked"

    public static func labels(hasSavedVisit: Bool, itineraryCompleted: Bool, hasUnlockedBonus: Bool) -> [String] {
        var labels: [String] = []
        if hasSavedVisit || itineraryCompleted { labels.append(visited) }
        if hasUnlockedBonus { labels.append(bonusUnlocked) }
        return labels
    }
}
