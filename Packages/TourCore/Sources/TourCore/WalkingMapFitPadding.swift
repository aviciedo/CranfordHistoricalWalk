import Foundation

/// Padding for a walking-map bounds fit. The right inset keeps the destination
/// illustration clear of the recenter control. Apple shrinks only the vertical
/// insets on a short viewport so padding cannot consume the whole fit.
public struct MapFitInsets: Equatable, Sendable {
    public var top: Double
    public var left: Double
    public var bottom: Double
    public var right: Double

    public init(top: Double, left: Double, bottom: Double, right: Double) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }
}

public enum WalkingMapFitPadding {
    public static let preferred = MapFitInsets(top: 40, left: 40, bottom: 56, right: 96)

    public static func insets(mapHeight: Double) -> MapFitInsets {
        MapFitInsets(
            top: min(preferred.top, mapHeight * 0.2),
            left: preferred.left,
            bottom: min(preferred.bottom, mapHeight * 0.3),
            right: preferred.right
        )
    }
}
