import Foundation

/// Shared photo index for stop galleries. A stored selection can outlive a shorter gallery.
public enum PhotoGalleryIndex {
    /// Clamp into the photos that exist. An empty gallery stays at zero and does not trap.
    public static func displayed(stored: Int?, count: Int) -> Int {
        min(max(0, stored ?? 0), max(0, count - 1))
    }

    /// Previous and next wrap. The stored value is clamped before wrapping, matching the arrows.
    public static func advanced(stored: Int?, by amount: Int, count: Int) -> Int {
        let current = displayed(stored: stored, count: count)
        guard count > 0 else { return current }
        return (current + amount + count) % count
    }
}
