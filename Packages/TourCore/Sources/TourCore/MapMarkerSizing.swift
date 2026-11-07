import Foundation
#if canImport(CoreGraphics)
// Apple exposes CGRect's Swift geometry API through CoreGraphics; Foundation alone
// happens to supply it on Linux, so Linux tests do not catch a missing Apple import.
import CoreGraphics
#endif

/// Shared screen-space layout for Apple and Google. Canonical coordinates never move:
/// only the artwork does, with a leader back to the site when it needs separating.
public enum MapMarkerSizing {
    public static let width: Double = 100
    public static let height: Double = 80
    public static let badgeCenter = SIMD2<Double>(14, 66)
    public static let maximumOffset: Double = 132
    public static let gap: Double = 10

    /// The tour destination is 50% larger; selection and visit history do not change it.
    public static func artworkScale(baseScale: Double, isActive: Bool) -> Double {
        baseScale * (isActive ? 1.5 : 1)
    }

    /// Reserve a fixed 44pt badge at its geographic anchor, independently of art zoom.
    /// The image remains centered so existing site offsets and leader lines stay truthful.
    public static func canvasWidth(scale: Double) -> Double {
        max(44, width * scale, 2 * abs(width / 2 - badgeCenter.x) * scale + 44)
    }

    public static func canvasHeight(scale: Double) -> Double {
        max(44, height * scale, 2 * abs(height / 2 - badgeCenter.y) * scale + 44)
    }

    public struct Placement: Equatable {
        public let site: SIMD2<Double>
        public let center: SIMD2<Double>
        public let isVisible: Bool
        public let leaderEnd: SIMD2<Double>?
        public let artworkScale: Double
    }

    public struct Layout {
        public let scale: Double
        public let placements: [Placement]
        /// Artwork clips here; visibility and rendering must use the same boundary.
        public let viewport: CGRect
    }

    /// Constant screen dimensions prevent zoom gestures from pulsing the artwork.
    public static func scale(metersPerPoint: Double) -> Double {
        metersPerPoint.isFinite && metersPerPoint > 0 ? 0.64 : 0
    }

    /// Stateful placement shared by both SDKs. During camera motion only projection changes;
    /// collision decisions are retained until the camera has been idle for 200 ms.
    public struct State {
        private var offsets: [String: SIMD2<Double>] = [:]
        private var settledInput: Input?

        private struct Input {
            let ids: [String]
            let points: [SIMD2<Double>]
            let viewport: CGRect
            let active: Set<Int>
            let reserved: [CGRect]
            let valid: Bool

            func matches(_ other: Input) -> Bool {
                ids == other.ids && viewport == other.viewport && active == other.active &&
                reserved == other.reserved && valid == other.valid && points.count == other.points.count &&
                zip(points, other.points).allSatisfy { a, b in
                    abs(a.x - b.x) <= 0.5 && abs(a.y - b.y) <= 0.5
                }
            }
        }

        public init() {}

        public mutating func layout(ids: [String], points: [SIMD2<Double>], metersPerPoint: Double,
                                    viewport: CGRect, activeIndices: Set<Int> = [],
                                    reservedAreas: [CGRect] = [], isMoving: Bool = false) -> Layout {
            precondition(ids.count == points.count && Set(ids).count == ids.count)
            offsets = offsets.filter { ids.contains($0.key) }
            let base = MapMarkerSizing.scale(metersPerPoint: metersPerPoint)
            let valid = base > 0 && viewport.width >= 44 && viewport.height >= 44
            let finite = points.map { valid && $0.x.isFinite && $0.y.isFinite }
            let input = Input(ids: ids, points: points, viewport: viewport,
                              active: activeIndices, reserved: reservedAreas, valid: valid)
            // An impossible-to-pack cluster must not try another arrangement on every
            // idle/model update. Subpixel projection jitter is not a layout change.
            let retainAll = isMoving || settledInput?.matches(input) == true
            if !isMoving { settledInput = input }
            var result: [Int: Placement] = [:]
            var occupied: [CGRect] = []
            // Reserve all unchanged placements first. A collision elsewhere must not move them.
            let order = points.indices.sorted {
                if activeIndices.contains($0) != activeIndices.contains($1) { return activeIndices.contains($0) }
                return $0 < $1
            }
            func rect(_ center: SIMD2<Double>, _ scale: Double) -> CGRect {
                CGRect(x: center.x - width * scale / 2, y: center.y - height * scale / 2,
                       width: width * scale, height: height * scale)
            }
            let badges = points.indices.filter { finite[$0] &&
                viewport.insetBy(dx: -22, dy: -22).contains(CGPoint(x: points[$0].x, y: points[$0].y)) }.map {
                CGRect(x: points[$0].x - 18, y: points[$0].y - 18, width: 36, height: 36)
            }
            func fits(_ box: CGRect) -> Bool {
                !reservedAreas.contains { $0.intersects(box) } &&
                !occupied.contains { $0.insetBy(dx: -gap / 2, dy: -gap / 2).intersects(box) } &&
                !badges.contains { $0.intersects(box) }
            }
            func placement(_ index: Int, _ offset: SIMD2<Double>, _ size: Double) -> Placement {
                let site = points[index], center = site + offset
                let box = rect(center, size)
                let edge = nearestEdge(to: site, of: box)
                // Visibility belongs to the artwork footprint, not the number pin. A
                // pin crossing the inset edge must not blank its still-visible callout.
                let visible = finite[index] && viewport.intersects(box)
                return Placement(site: site, center: center, isVisible: visible,
                                 leaderEnd: visible ? edge : nil, artworkScale: size)
            }
            for index in order {
                let size = artworkScale(baseScale: base, isActive: activeIndices.contains(index))
                let previous = offsets[ids[index]]
                let offset = previous ?? SIMD2(0, -(height * size / 2 + 25))
                let box = rect(points[index] + offset, size)
                // Let retained artwork clip at the edge just like native map markers.
                // Never haul it back into the viewport merely because a pan ended.
                if !finite[index] || !viewport.intersects(box) || retainAll || (previous != nil && fits(box)) {
                    let current = placement(index, offset, size)
                    result[index] = current
                    if current.isVisible { occupied.append(box) }
                    offsets[ids[index]] = offset
                }
            }
            for index in order where result[index] == nil {
                let size = artworkScale(baseScale: base, isActive: activeIndices.contains(index))
                let preferred = offsets[ids[index]] ?? SIMD2(0, -(height * size / 2 + 25))
                let candidates = MapMarkerSizing.offsets.sorted {
                    let a = $0 - preferred, b = $1 - preferred
                    let da = a.x * a.x + a.y * a.y, db = b.x * b.x + b.y * b.y
                    if da != db { return da < db }
                    if $0.y != $1.y { return $0.y < $1.y }
                    return $0.x < $1.x
                }
                let available = candidates.filter {
                    let box = rect(points[index] + $0, size)
                    return viewport.intersects(box) && fits(box)
                }
                // Fully contain new callouts when possible. Existing callouts keep
                // their edge relationship; local collision corrections may clip.
                let chosen = offsets[ids[index]] == nil
                    ? (available.first { viewport.contains(rect(points[index] + $0, size)) } ?? available.first)
                    : available.first
                // A dense cluster must never collapse every illustration. Keep this art at
                // full size and choose the least obstructed local slot; canonical pins remain.
                func penalty(_ offset: SIMD2<Double>) -> Double {
                    let box = rect(points[index] + offset, size)
                    let inside = box.intersection(viewport)
                    let outside = box.width * box.height - (inside.isNull ? 0 : inside.width * inside.height)
                    let overlap = (reservedAreas + occupied + badges).reduce(0.0) { total, other in
                        let area = box.intersection(other)
                        return total + (area.isNull ? 0 : area.width * area.height)
                    }
                    return outside * 20 + overlap
                }
                let offset = chosen ?? candidates.min { penalty($0) < penalty($1) } ?? preferred
                offsets[ids[index]] = offset
                result[index] = placement(index, offset, size)
                occupied.append(rect(points[index] + offset, size))
            }
            return Layout(scale: base, placements: points.indices.compactMap { result[$0] }, viewport: viewport)
        }
    }

    private static let offsets: [SIMD2<Double>] = {
        var values: [SIMD2<Double>] = []
        for x in stride(from: -maximumOffset, through: maximumOffset, by: 12) {
            for y in stride(from: -maximumOffset, through: maximumOffset, by: 12)
                where x * x + y * y <= maximumOffset * maximumOffset { values.append(SIMD2(x, y)) }
        }
        return values
    }()

    public static func layout(points: [SIMD2<Double>], metersPerPoint: Double,
                              viewport: CGRect, activeIndices: Set<Int> = [],
                              reservedAreas: [CGRect] = []) -> Layout {
        var state = State()
        return state.layout(ids: points.indices.map { String($0) }, points: points,
                            metersPerPoint: metersPerPoint, viewport: viewport,
                            activeIndices: activeIndices, reservedAreas: reservedAreas)
    }

    private static func nearestEdge(to site: SIMD2<Double>, of rect: CGRect) -> SIMD2<Double> {
        let x = min(max(site.x, Double(rect.minX)), Double(rect.maxX))
        let y = min(max(site.y, Double(rect.minY)), Double(rect.maxY))
        return SIMD2<Double>(x, y)
    }


}
