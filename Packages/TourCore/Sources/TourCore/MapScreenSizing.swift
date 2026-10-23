/// Destination content gets its complete measured height before the map receives space.
/// These sizes describe the Map content viewport, excluding the title, player and tabs.
public enum MapScreenSizing {
    public static let minimumMapHeight: Double = 160
    public static let maximumMapHeight: Double = 400
    public static let compactControlsThreshold: Double = 240
    public static let sectionSpacing: Double = 16
    public static let bottomSpacing: Double = 16

    public struct Metrics: Equatable, Sendable {
        public let mapHeight: Double
        public let destinationHeight: Double
        public let gap: Double
        public let contentHeight: Double
        public let requiresScrolling: Bool
    }

    public static func metrics(availableHeight: Double, destinationHeight: Double) -> Metrics {
        guard availableHeight.isFinite, availableHeight > 0 else {
            return Metrics(mapHeight: 0, destinationHeight: 0, gap: 0, contentHeight: 0, requiresScrolling: false)
        }
        let destination = destinationHeight.isFinite ? max(0, destinationHeight) : 0
        let gap = destination > 0 ? sectionSpacing : 0
        let remaining = availableHeight - destination - gap - bottomSpacing
        let map = max(minimumMapHeight, min(maximumMapHeight, remaining))
        let content = map + gap + destination + bottomSpacing
        return Metrics(mapHeight: map, destinationHeight: destination, gap: gap,
                       contentHeight: content, requiresScrolling: content > availableHeight + 0.5)
    }
}
