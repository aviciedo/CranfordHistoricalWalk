import Foundation

/// Compact navigation keeps a small physical gap above the home indicator. Screens
/// receive the recovered height through the same shared shell, not individual offsets.
public enum AppFooterSizing {
    public static func bottomClearance(safeAreaBottom: Double) -> Double {
        guard safeAreaBottom.isFinite, safeAreaBottom > 0 else { return 0 }
        return min(safeAreaBottom, max(12, safeAreaBottom - 18))
    }
}
