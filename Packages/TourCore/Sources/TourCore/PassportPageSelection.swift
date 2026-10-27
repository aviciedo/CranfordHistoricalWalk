import Foundation

/// Which passport leaf is showing, and when a new stamp may animate.
/// The saved bonus ledger remains the only collection record.
public struct PassportPageSelection: Equatable, Sendable {
    public var pageIndex = 0
    public var hasSelectedInitialPage = false

    public init() {}

    /// Before the visitor turns a page, open the requested stop. An unknown id starts at the first leaf.
    public func currentIndex(stopIDs: [String], initialStopID: String) -> Int {
        if hasSelectedInitialPage {
            return min(pageIndex, max(0, stopIDs.count - 1))
        }
        return stopIDs.firstIndex(of: initialStopID) ?? 0
    }

    /// One-shot. An empty catalog does not lock the page, so a later load can still open the requested stop.
    public mutating func selectInitialPage(stopIDs: [String], initialStopID: String) {
        guard !hasSelectedInitialPage, !stopIDs.isEmpty else { return }
        pageIndex = stopIDs.firstIndex(of: initialStopID) ?? 0
        hasSelectedInitialPage = true
    }

    /// Arrow taps and page curls share this write. The displayed index is clamped on read.
    public mutating func choose(_ index: Int) {
        pageIndex = index
        hasSelectedInitialPage = true
    }

    public mutating func clampStoredIndex(stopCount: Int) {
        pageIndex = min(pageIndex, max(0, stopCount - 1))
    }

    /// A celebration holds the book only when that stop's bonus is already saved.
    public static func isAwaitingStampReveal(animatedStopID: String?, bonusIsSaved: Bool, hasStamped: Bool) -> Bool {
        animatedStopID != nil && bonusIsSaved && !hasStamped
    }

    /// Other collected leaves stay visible. The new stamp appears only after its animation.
    public static func shouldRevealStamp(stopID: String, animatedStopID: String?, hasStamped: Bool) -> Bool {
        stopID != animatedStopID || hasStamped
    }

    /// Approved art only. A new plaque page uses the seal fallback rather than another site's stamp.
    public static func stampAssetName(for stopID: String) -> String? {
        switch stopID {
        case "hpab-001": return "passport-stamp-mill"
        case "hpab-002": return "passport-stamp-greystone"
        default: return nil
        }
    }
}
