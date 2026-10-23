import Foundation

/// One shared footprint for each illustration and its number, anchored to the real coordinate.
/// Constrain the whole set together so selecting or visiting a stop never changes its size.
public enum MapMarkerSizing {
    public static let width: Double = 88
    public static let height: Double = 92

    public static func scale(points: [SIMD2<Double>], metersPerPoint: Double) -> Double {
        guard metersPerPoint.isFinite, metersPerPoint > 0 else { return 0 }
        // Grow more slowly than the geography, leaving more space between stops as we zoom in.
        var result = min(1.4, sqrt(2.5 / metersPerPoint))
        let finite = points.filter { $0.x.isFinite && $0.y.isFinite }
        for i in finite.indices {
            for j in finite.indices where j > i {
                let delta = finite[i] - finite[j]
                let separation = max(abs(delta.x) / width, abs(delta.y) / height)
                // Bounding rectangles remain separate, with 12% breathing room. No lower
                // size clamp: it would reintroduce overlapping artwork when zooming out.
                result = min(result, separation * 0.88)
            }
        }
        return result
    }
}
