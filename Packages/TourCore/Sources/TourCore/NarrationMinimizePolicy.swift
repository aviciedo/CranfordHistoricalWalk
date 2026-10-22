import Foundation

/// When the shared narration player collapses. Scrolling Home downward minimizes it;
/// a downward bounce only moves the baseline and never expands it again.
public enum NarrationMinimizePolicy {
    /// Content must move up by more than this many points. Exactly this distance does not collapse.
    public static let scrollThreshold: Double = 24
    /// A mostly vertical drag must pass this distance. The view's gesture recognizer
    /// still requires 16 points before this decision runs.
    public static let dragThreshold: Double = 20

    public struct ScrollSample: Equatable, Sendable {
        public var baseline: Double?
        public var isMinimized: Bool

        public init(baseline: Double?, isMinimized: Bool) {
            self.baseline = baseline
            self.isMinimized = isMinimized
        }
    }

    public static func scrolled(offset: Double, baseline: Double?, isMinimized: Bool) -> ScrollSample {
        guard let baseline else {
            return ScrollSample(baseline: offset, isMinimized: isMinimized)
        }
        if offset < baseline - scrollThreshold {
            return ScrollSample(baseline: offset, isMinimized: true)
        }
        if offset > baseline {
            return ScrollSample(baseline: offset, isMinimized: isMinimized)
        }
        return ScrollSample(baseline: baseline, isMinimized: isMinimized)
    }

    public enum Drag: Equatable, Sendable {
        case minimize
        case expand
        case ignore
    }

    /// Horizontal drags, and vertical drags that only reach the threshold, leave the player alone.
    public static func drag(width: Double, height: Double) -> Drag {
        guard abs(height) > abs(width) else { return .ignore }
        if height > dragThreshold { return .minimize }
        if height < -dragThreshold { return .expand }
        return .ignore
    }
}
