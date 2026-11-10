import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import TourCore

final class MapMarkerSizingTests: XCTestCase {
    private let viewport = CGRect(x: 10, y: 10, width: 370, height: 590)
    private let points: [SIMD2<Double>] = [[205, 430], [232, 383], [40, 60], [190, 366], [168, 320]]
    private let ids = ["mill", "greystone", "river", "church", "hotel"]

    func testFixedHierarchyAtEveryZoomAndActiveStop() {
        for zoom in [0.01, 2.5, 10, 100] {
            for active in points.indices {
                let layout = MapMarkerSizing.layout(points: points, metersPerPoint: zoom,
                    viewport: viewport, activeIndices: [active])
                XCTAssertEqual(layout.scale, 0.64)
                XCTAssertTrue(layout.placements.allSatisfy(\.isVisible))
                for (index, placement) in layout.placements.enumerated() {
                    XCTAssertEqual(placement.artworkScale * 100, index == active ? 96 : 64, accuracy: 0.001)
                    XCTAssertEqual(placement.site, points[index])
                }
            }
        }
    }

    func testGestureRetainsOffsetsThroughPanPinchAndRotation() {
        var state = MapMarkerSizing.State()
        let initial = state.layout(ids: ids, points: points, metersPerPoint: 4, viewport: viewport, activeIndices: [0])
        for frame in 0..<120 {
            let angle = Double(frame) / 100
            let zoom = 0.5 + Double(frame) / 90
            let projected = points.map { p -> SIMD2<Double> in
                let d = (p - SIMD2(190, 290)) * zoom
                return SIMD2(d.x * cos(angle) - d.y * sin(angle) + 190,
                             d.x * sin(angle) + d.y * cos(angle) + 290)
            }
            let moving = state.layout(ids: ids, points: projected, metersPerPoint: 4 / zoom,
                viewport: viewport, activeIndices: [0], isMoving: true)
            for index in points.indices {
                XCTAssertEqual(moving.placements[index].center.x - projected[index].x,
                               initial.placements[index].center.x - points[index].x, accuracy: 0.00001)
                XCTAssertEqual(moving.placements[index].center.y - projected[index].y,
                               initial.placements[index].center.y - points[index].y, accuracy: 0.00001)
                XCTAssertEqual(moving.placements[index].artworkScale, initial.placements[index].artworkScale)
            }
        }
    }

    func testIdleLayoutIsStableAndChangingActiveStopDoesNotMoveDistantArtwork() {
        var state = MapMarkerSizing.State()
        let first = state.layout(ids: ids, points: points, metersPerPoint: 4, viewport: viewport, activeIndices: [0])
        let second = state.layout(ids: ids, points: points, metersPerPoint: 4, viewport: viewport, activeIndices: [0])
        XCTAssertEqual(first.placements, second.placements)
        let changed = state.layout(ids: ids, points: points, metersPerPoint: 4, viewport: viewport, activeIndices: [4])
        XCTAssertEqual(first.placements[2].center, changed.placements[2].center)
    }

    func testDenseClusterNeverShrinksOrHidesWholeTour() {
        let cluster = Array(repeating: SIMD2<Double>(190, 290), count: 5)
        let layout = MapMarkerSizing.layout(points: cluster, metersPerPoint: 5,
            viewport: viewport, activeIndices: [0])
        XCTAssertTrue(layout.placements.allSatisfy(\.isVisible))
        XCTAssertEqual(layout.scale, 0.64)
        for placement in layout.placements {
            XCTAssertEqual(placement.site, cluster[0])
            let delta = placement.center - placement.site
            XCTAssertLessThanOrEqual(delta.x * delta.x + delta.y * delta.y, pow(132, 2) + 0.001)
        }
    }

    func testIndependentSiteAndControlsRemainUncovered() {
        let controls = CGRect(x: 310, y: 396, width: 68, height: 196)
        let layout = MapMarkerSizing.layout(points: points, metersPerPoint: 4,
            viewport: viewport, activeIndices: [0], reservedAreas: [controls])
        for placement in layout.placements {
            let rect = rectangle(placement)
            XCTAssertTrue(viewport.contains(rect))
            XCTAssertFalse(rect.intersects(controls))
            for site in points {
                XCTAssertFalse(rect.intersects(CGRect(x: site.x - 18, y: site.y - 18, width: 36, height: 36)))
            }
        }
    }

    func testStableIDsSurviveOrderingChangesAndOffscreenReturn() {
        var state = MapMarkerSizing.State()
        let first = state.layout(ids: ids, points: points, metersPerPoint: 4, viewport: viewport)
        let reverse = state.layout(ids: ids.reversed(), points: points.reversed(), metersPerPoint: 4,
            viewport: viewport, isMoving: true)
        XCTAssertEqual(first.placements, reverse.placements.reversed())
        let outside = state.layout(ids: ids, points: points.map { $0 + SIMD2(1000, 1000) },
            metersPerPoint: 4, viewport: viewport, isMoving: true)
        XCTAssertTrue(outside.placements.allSatisfy { !$0.isVisible })
        let returned = state.layout(ids: ids, points: points, metersPerPoint: 4, viewport: viewport, isMoving: true)
        XCTAssertEqual(first.placements, returned.placements)
    }

    func testFootprintRemainsVisibleWhenItsPinCrossesBottomInset() {
        var state = MapMarkerSizing.State()
        let bounds = CGRect(x: 10, y: 10, width: 370, height: 210)
        let initial = state.layout(ids: ["mill"], points: [[150, 175]], metersPerPoint: 200,
            viewport: bounds, activeIndices: [0])
        let shifted = SIMD2<Double>(150, 230) // Pin is outside, artwork still intersects.
        let moving = state.layout(ids: ["mill"], points: [shifted], metersPerPoint: 200,
            viewport: bounds, activeIndices: [0], isMoving: true)
        XCTAssertTrue(rectangle(moving.placements[0]).intersects(bounds))
        XCTAssertTrue(moving.placements[0].isVisible, "Never blank visible artwork because its geographic pin crossed an inset")
        XCTAssertEqual(moving.placements[0].center - shifted,
                       initial.placements[0].center - initial.placements[0].site)
        let idle = state.layout(ids: ["mill"], points: [shifted], metersPerPoint: 200,
            viewport: bounds, activeIndices: [0])
        XCTAssertEqual(moving.placements, idle.placements, "Ending the pan must not haul artwork back inside")
    }

    func testEveryViewportEdgeClipsInsteadOfRelocatingRetainedArtwork() {
        let shifts: [SIMD2<Double>] = [[-150, 0], [190, 0], [0, -110], [0, 160]]
        for shift in shifts {
            var state = MapMarkerSizing.State()
            let bounds = CGRect(x: 0, y: 0, width: 320, height: 220)
            let initial = state.layout(ids: ["mill"], points: [[150, 130]], metersPerPoint: 100,
                viewport: bounds, activeIndices: [0])
            let point = SIMD2<Double>(150, 130) + shift
            let moving = state.layout(ids: ["mill"], points: [point], metersPerPoint: 100,
                viewport: bounds, activeIndices: [0], isMoving: true)
            let idle = state.layout(ids: ["mill"], points: [point], metersPerPoint: 100,
                viewport: bounds, activeIndices: [0])
            XCTAssertEqual(moving.placements, idle.placements)
            XCTAssertEqual(idle.placements[0].center - point, initial.placements[0].center - initial.placements[0].site)
            XCTAssertEqual(idle.placements[0].isVisible, rectangle(idle.placements[0]).intersects(bounds))
            XCTAssertEqual(idle.viewport, bounds)
        }
    }

    func testRegionalClusterVisibilityFollowsEachFootprintAcrossRecordingLikePans() {
        var state = MapMarkerSizing.State()
        let bounds = CGRect(x: 10, y: 10, width: 330, height: 190)
        let cluster = (0..<5).map { SIMD2<Double>(120 + Double($0) * 0.5, 155 + Double($0) * 0.2) }
        _ = state.layout(ids: ids, points: cluster, metersPerPoint: 200, viewport: bounds, activeIndices: [0])
        var outsidePinWithVisibleArtwork = false
        for delta in [0.0, 10, 20, 35, 50, 80, 100, 150, 100, 50, 20, 0] {
            let projected = cluster.map { $0 + SIMD2<Double>(0, delta) }
            let layout = state.layout(ids: ids, points: projected, metersPerPoint: 200,
                viewport: bounds, activeIndices: [0], isMoving: true)
            for placement in layout.placements {
                let expected = rectangle(placement).intersects(bounds)
                XCTAssertEqual(placement.isVisible, expected)
                if placement.site.y > bounds.maxY && expected { outsidePinWithVisibleArtwork = true }
            }
        }
        XCTAssertTrue(outsidePinWithVisibleArtwork, "Exercise the actual group-disappearance regression")
    }

    func testImpossibleDenseLayoutDoesNotRetryAndShuffleOnEveryIdleUpdate() {
        var state = MapMarkerSizing.State()
        let bounds = CGRect(x: 0, y: 0, width: 150, height: 130)
        let cluster = Array(repeating: SIMD2<Double>(75, 90), count: 5)
        let first = state.layout(ids: ids, points: cluster, metersPerPoint: 200,
            viewport: bounds, activeIndices: [0])
        for _ in 0..<25 {
            let next = state.layout(ids: ids, points: cluster, metersPerPoint: 200,
                viewport: bounds, activeIndices: [0])
            XCTAssertEqual(next.placements, first.placements)
        }
    }

    func testNumberBadgeStaysInsideTheCanvasAtShippedArtworkScales() {
        let scales = [0.0, 0.64, MapMarkerSizing.artworkScale(baseScale: 0.64, isActive: true), 1.0]
        for scale in scales {
            let canvasWidth = MapMarkerSizing.canvasWidth(scale: scale)
            let canvasHeight = MapMarkerSizing.canvasHeight(scale: scale)
            XCTAssertGreaterThanOrEqual(canvasWidth, 44, "scale \(scale)")
            XCTAssertGreaterThanOrEqual(canvasHeight, 44, "scale \(scale)")
            XCTAssertTrue(canvasWidth.isFinite && canvasHeight.isFinite)
            let artWidth = MapMarkerSizing.width * scale
            let artHeight = MapMarkerSizing.height * scale
            let originX = (canvasWidth - artWidth) / 2
            let originY = (canvasHeight - artHeight) / 2
            let badgeX = originX + artWidth * MapMarkerSizing.badgeCenter.x / MapMarkerSizing.width
            let badgeY = originY + artHeight * MapMarkerSizing.badgeCenter.y / MapMarkerSizing.height
            XCTAssertGreaterThanOrEqual(badgeX - 22, -0.001, "scale \(scale)")
            XCTAssertGreaterThanOrEqual(badgeY - 22, -0.001, "scale \(scale)")
            XCTAssertLessThanOrEqual(badgeX + 22, canvasWidth + 0.001, "scale \(scale)")
            XCTAssertLessThanOrEqual(badgeY + 22, canvasHeight + 0.001, "scale \(scale)")
        }
        XCTAssertEqual(MapMarkerSizing.artworkScale(baseScale: 0.64, isActive: true), 0.96, accuracy: 0.0001)
    }

    func testInvalidInputIsSafe() {
        XCTAssertEqual(MapMarkerSizing.scale(metersPerPoint: 0), 0)
        XCTAssertEqual(MapMarkerSizing.scale(metersPerPoint: .nan), 0)
        let layout = MapMarkerSizing.layout(points: [[2, 2], [.nan, 2]], metersPerPoint: 2,
            viewport: CGRect(x: 0, y: 0, width: 20, height: 20))
        XCTAssertTrue(layout.placements.allSatisfy { !$0.isVisible })
    }

    private func rectangle(_ placement: MapMarkerSizing.Placement) -> CGRect {
        let width = 100 * placement.artworkScale, height = 80 * placement.artworkScale
        return CGRect(x: placement.center.x - width / 2, y: placement.center.y - height / 2, width: width, height: height)
    }
}
