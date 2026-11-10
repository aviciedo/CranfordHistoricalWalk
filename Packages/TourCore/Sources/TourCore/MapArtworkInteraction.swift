import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// One illustrated callout in screen space. The map view supplies frames; this type
/// does not know about UIKit buttons or gesture recognizers.
public struct MapArtworkTarget: Equatable {
    public var id: String
    public var frame: CGRect
    public var zPosition: CGFloat
    public var isHidden: Bool

    public init(id: String, frame: CGRect, zPosition: CGFloat, isHidden: Bool) {
        self.id = id
        self.frame = frame
        self.zPosition = zPosition
        self.isHidden = isHidden
    }
}

/// Shared hit testing for Apple and Google artwork overlays.
public enum MapArtworkHitTesting {
    /// A tap selects the topmost visible illustration inside the clip.
    /// Number-badge rectangles and anything outside the clip are map hits, not artwork.
    public static func artworkID(at point: CGPoint, clip: CGRect, badgeTargets: [CGRect],
                                 artwork: [MapArtworkTarget]) -> String? {
        guard clip.contains(point), !badgeTargets.contains(where: { $0.contains(point) }) else { return nil }
        return artwork.sorted { $0.zPosition > $1.zPosition }.first {
            !$0.isHidden && $0.frame.contains(point)
        }?.id
    }
}

/// Badge holes punched out of the artwork mask.
public enum MapArtworkMask {
    /// Inset each 44pt number target, union overlaps, then clip to the artwork viewport.
    /// Overlapping holes must become one region: an even-odd mask would otherwise
    /// cancel the intersection and paint the illustration back over the number.
    public static func badgeCutouts(_ targets: [CGRect], clippedTo clip: CGRect) -> [CGRect] {
        var holes: [CGRect] = []
        for target in targets {
            var hole = target.insetBy(dx: 4, dy: 4)
            var index = 0
            while index < holes.count {
                if holes[index].intersects(hole) {
                    hole = hole.union(holes.remove(at: index))
                    index = 0
                } else {
                    index += 1
                }
            }
            holes.append(hole)
        }
        return holes.compactMap { rect in
            let clipped = rect.intersection(clip)
            return clipped.isNull ? nil : clipped
        }
    }
}
