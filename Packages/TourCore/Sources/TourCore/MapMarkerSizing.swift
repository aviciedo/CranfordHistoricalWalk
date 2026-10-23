import Foundation

/// Shared screen-space layout for Apple and Google. Canonical coordinates never move:
/// only the artwork does, with a leader back to the site when it needs separating.
public enum MapMarkerSizing {
    public static let width: Double = 100
    public static let height: Double = 80
    public static let badgeCenter = SIMD2<Double>(14, 66)
    public static let maximumOffset: Double = 132
    public static let gap: Double = 10

    public struct Placement: Equatable {
        public let site: SIMD2<Double>
        public let center: SIMD2<Double>
        public let isVisible: Bool
        public let leaderEnd: SIMD2<Double>?
    }

    public struct Layout {
        public let scale: Double
        public let placements: [Placement]
    }

    /// Zoom determines the nominal size; nearby sites no longer shrink the whole tour.
    public static func scale(metersPerPoint: Double) -> Double {
        guard metersPerPoint.isFinite, metersPerPoint > 0 else { return 0 }
        return min(1.3, max(0.72, sqrt(3.2 / metersPerPoint)))
    }

    // Stable ordering prevents changes of selection or dictionary order from moving landmarks.
    // Callers provide stops sorted by tour order, then ID.
    private static let offsets: [SIMD2<Double>] = {
        var values: [SIMD2<Double>] = []
        for x in stride(from: -maximumOffset, through: maximumOffset, by: 12) {
            for y in stride(from: -maximumOffset, through: maximumOffset, by: 12) {
                if x * x + y * y <= maximumOffset * maximumOffset { values.append(SIMD2(x, y)) }
            }
        }
        return values.sorted {
            let a = $0.x * $0.x + $0.y * $0.y
            let b = $1.x * $1.x + $1.y * $1.y
            if a != b { return a < b }
            if $0.y != $1.y { return $0.y < $1.y }
            return $0.x < $1.x
        }
    }()

    public static func layout(points: [SIMD2<Double>], metersPerPoint: Double,
                              viewport: CGRect, reservedAreas: [CGRect] = []) -> Layout {
        let nominal = scale(metersPerPoint: metersPerPoint)
        guard nominal > 0, viewport.width >= 44, viewport.height >= 44 else {
            return Layout(scale: 0, placements: points.map {
                Placement(site: $0, center: $0, isVisible: false, leaderEnd: nil)
            })
        }
        let visible = points.map { p in p.x.isFinite && p.y.isFinite && viewport.contains(CGPoint(x: p.x, y: p.y)) }
        var size = nominal
        // Only exceptionally tight viewports/dense clusters reduce the common size, after
        // exhausting bounded offsets. The 44pt targets participate in collision testing.
        for _ in 0..<16 {
            var rectangles: [CGRect] = []
            var placements: [Placement] = []
            var fits = true
            let w = max(44, width * size), h = max(44, height * size)
            let naturalOffset = (SIMD2(width / 2, height / 2) - badgeCenter) * size
            for index in points.indices {
                let site = points[index]
                let preferred = site + naturalOffset
                guard visible[index] else {
                    placements.append(Placement(site: site, center: preferred, isVisible: false, leaderEnd: nil))
                    continue
                }
                var chosen: CGRect?
                for offset in offsets {
                    let center = preferred + offset
                    let rect = CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)
                    guard viewport.contains(rect), !reservedAreas.contains(where: { $0.intersects(rect) }),
                          !rectangles.contains(where: { $0.insetBy(dx: -gap, dy: -gap).intersects(rect) }) else { continue }
                    // Keep true locations uncovered so a later leader never starts beneath
                    // another illustration (including coincident sites in a dense cluster).
                    let coversAnotherSite = points.indices.contains { other in
                        other != index && visible[other] && rect.insetBy(dx: -3, dy: -3)
                            .contains(CGPoint(x: points[other].x, y: points[other].y))
                    }
                    guard !coversAnotherSite else { continue }
                    let edge = nearestEdge(to: site, of: rect)
                    guard !rectangles.contains(where: { segment(from: site, to: edge, intersects: $0) }),
                          !placements.contains(where: { previous in
                              guard let end = previous.leaderEnd else { return false }
                              return segment(from: previous.site, to: end, intersects: rect)
                          }) else { continue }
                    chosen = rect
                    break
                }
                guard let rect = chosen else { fits = false; break }
                rectangles.append(rect)
                let center = SIMD2(Double(rect.midX), Double(rect.midY))
                let edge = nearestEdge(to: site, of: rect)
                let delta = edge - site
                let end: SIMD2<Double>? = delta.x * delta.x + delta.y * delta.y > 36 ? edge : nil
                placements.append(Placement(site: site, center: center, isVisible: true, leaderEnd: end))
            }
            if fits { return Layout(scale: size, placements: placements) }
            size *= 0.9
        }
        // A viewport too small to fit even five 44pt controls cannot safely show them all.
        // Keep the positions truthful rather than emitting overlapping targets.
        return Layout(scale: 0, placements: points.map {
            Placement(site: $0, center: $0, isVisible: false, leaderEnd: nil)
        })
    }

    private static func nearestEdge(to site: SIMD2<Double>, of rect: CGRect) -> SIMD2<Double> {
        SIMD2(min(max(site.x, rect.minX), rect.maxX), min(max(site.y, rect.minY), rect.maxY))
    }

    /// Slab intersection, with a little breathing room so leaders do not graze other art.
    private static func segment(from start: SIMD2<Double>, to end: SIMD2<Double>, intersects rect: CGRect) -> Bool {
        let box = rect.insetBy(dx: -2, dy: -2)
        let low = SIMD2<Double>(box.minX, box.minY), high = SIMD2<Double>(box.maxX, box.maxY)
        let direction = end - start
        var entry = 0.0, exit = 1.0
        for axis in 0..<2 {
            if abs(direction[axis]) < 0.000001 {
                if start[axis] < low[axis] || start[axis] > high[axis] { return false }
            } else {
                let a = (low[axis] - start[axis]) / direction[axis]
                let b = (high[axis] - start[axis]) / direction[axis]
                entry = max(entry, min(a, b))
                exit = min(exit, max(a, b))
                if entry > exit { return false }
            }
        }
        return entry <= exit
    }

}
