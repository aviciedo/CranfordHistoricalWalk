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
