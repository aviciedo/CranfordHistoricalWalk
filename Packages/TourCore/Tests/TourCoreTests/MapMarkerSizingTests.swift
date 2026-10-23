import XCTest
@testable import TourCore

final class MapMarkerSizingTests: XCTestCase {
    private let viewport = CGRect(x: 10, y: 10, width: 370, height: 590)

    func testZoomChangesSizeWithinReadableBounds() {
        XCTAssertEqual(MapMarkerSizing.scale(metersPerPoint: 100), 0.72)
        XCTAssertGreaterThan(MapMarkerSizing.scale(metersPerPoint: 2.5), MapMarkerSizing.scale(metersPerPoint: 10))
        XCTAssertEqual(MapMarkerSizing.scale(metersPerPoint: 0.01), 1.3)
    }

    func testDowntownClusterKeepsNominalSizeInsteadOfShrinkingIsolatedRiver() {
        let points: [SIMD2<Double>] = [[205, 430], [232, 383], [40, 60], [190, 366], [168, 320]]
        let layout = MapMarkerSizing.layout(points: points, metersPerPoint: 4, viewport: viewport)
        XCTAssertEqual(layout.scale, MapMarkerSizing.scale(metersPerPoint: 4))
        assertSeparate(layout)
        XCTAssertTrue(layout.placements.contains { $0.leaderEnd != nil })
    }

    func testDenseAndRotatedLayoutsStaySeparateWithBoundedOffsets() {
        let original: [SIMD2<Double>] = [[0, 0], [8, 10], [60, 15], [150, 180], [90, 92]]
        for degrees in stride(from: 0.0, to: 360.0, by: 30) {
            let angle = degrees * Double.pi / 180
            for zoom in [0.1, 0.5, 1.0, 2.0] {
                let points = original.map { p in
                    SIMD2(180 + (p.x * cos(angle) - p.y * sin(angle)) * zoom,
                          250 + (p.x * sin(angle) + p.y * cos(angle)) * zoom)
                }
                let layout = MapMarkerSizing.layout(points: points, metersPerPoint: 5 / zoom, viewport: viewport)
                XCTAssertGreaterThan(layout.scale, 0)
                assertSeparate(layout)
                let offset = (SIMD2(MapMarkerSizing.width / 2, MapMarkerSizing.height / 2) - MapMarkerSizing.badgeCenter) * layout.scale
                for placement in layout.placements where placement.isVisible {
                    let delta = placement.center - placement.site - offset
                    XCTAssertLessThanOrEqual(delta.x * delta.x + delta.y * delta.y, pow(MapMarkerSizing.maximumOffset, 2) + 0.001)
                }
            }
        }
    }

    func testCoincidentSitesAllRemainVisibleAndSeparate() {
        let layout = MapMarkerSizing.layout(points: Array(repeating: SIMD2(190, 290), count: 5),
                                            metersPerPoint: 5, viewport: viewport)
        XCTAssertTrue(layout.placements.allSatisfy(\.isVisible))
        XCTAssertGreaterThanOrEqual(layout.scale, 0.72)
        assertSeparate(layout)
    }

    func testOffscreenSitesDoNotPullArtworkIntoViewportOrShrinkVisibleSite() {
        let points: [SIMD2<Double>] = [[180, 250], [-800, 100], [-799, 101], [.nan, 2]]
        let layout = MapMarkerSizing.layout(points: points, metersPerPoint: 3.2, viewport: viewport)
        XCTAssertEqual(layout.scale, 1)
        XCTAssertEqual(layout.placements.map(\.isVisible), [true, false, false, false])
        XCTAssertNil(layout.placements[0].leaderEnd)
    }

    func testPanningAndSelectionIndependentInputsProduceStablePositions() {
        let points: [SIMD2<Double>] = [[170, 200], [190, 230], [180, 260]]
        let first = MapMarkerSizing.layout(points: points, metersPerPoint: 4, viewport: viewport)
        let pan = SIMD2<Double>(7, 9)
        let second = MapMarkerSizing.layout(points: points.map { $0 + pan }, metersPerPoint: 4, viewport: viewport)
        XCTAssertEqual(first.scale, second.scale)
        for (a, b) in zip(first.placements, second.placements) {
            XCTAssertEqual(b.center.x - a.center.x, pan.x, accuracy: 0.001)
            XCTAssertEqual(b.center.y - a.center.y, pan.y, accuracy: 0.001)
        }
        XCTAssertEqual(first.placements, MapMarkerSizing.layout(points: points, metersPerPoint: 4, viewport: viewport).placements)
    }

    func testLeadersPreserveExactSitesAndEndAtIllustrationBoundary() {
        let points = Array(repeating: SIMD2<Double>(190, 290), count: 5)
        let layout = MapMarkerSizing.layout(points: points, metersPerPoint: 5, viewport: viewport)
        for (point, placement) in zip(points, layout.placements) {
            XCTAssertEqual(placement.site, point)
            if let end = placement.leaderEnd {
                let rect = rectangle(placement, scale: layout.scale)
                XCTAssertTrue(abs(end.x - rect.minX) < 0.001 || abs(end.x - rect.maxX) < 0.001
                              || abs(end.y - rect.minY) < 0.001 || abs(end.y - rect.maxY) < 0.001)
            }
        }
    }

    func testLeadersDoNotRunThroughAnotherIllustration() {
        let points: [SIMD2<Double>] = [[180, 270], [190, 280], [200, 290], [180, 290], [200, 270]]
        let layout = MapMarkerSizing.layout(points: points, metersPerPoint: 5, viewport: viewport)
        XCTAssertTrue(layout.placements.allSatisfy(\.isVisible))
        for i in layout.placements.indices {
            let placement = layout.placements[i]
            guard let end = placement.leaderEnd else { continue }
            // Sample the full segment independently of the production intersection routine.
            for step in 0...200 {
                let p = placement.site + (end - placement.site) * Double(step) / 200
                for j in layout.placements.indices where i != j {
                    XCTAssertFalse(rectangle(layout.placements[j], scale: layout.scale).contains(CGPoint(x: p.x, y: p.y)))
                }
            }
        }
    }

    func testControlsRemainUncoveredAndEdgeSitesStayInsideMap() {
        let controls = CGRect(x: 310, y: 396, width: 68, height: 196)
        let points: [SIMD2<Double>] = [[375, 590], [335, 530], [20, 30], [350, 30], [20, 585]]
        let layout = MapMarkerSizing.layout(points: points, metersPerPoint: 5, viewport: viewport, reservedAreas: [controls])
        XCTAssertTrue(layout.placements.allSatisfy(\.isVisible))
        assertSeparate(layout)
        for placement in layout.placements { XCTAssertFalse(controls.intersects(rectangle(placement, scale: layout.scale))) }
    }

    func testInvalidCameraAndTinyViewportAreSafe() {
        XCTAssertEqual(MapMarkerSizing.scale(metersPerPoint: 0), 0)
        XCTAssertEqual(MapMarkerSizing.scale(metersPerPoint: .nan), 0)
        let layout = MapMarkerSizing.layout(points: [[2, 2]], metersPerPoint: 2, viewport: CGRect(x: 0, y: 0, width: 20, height: 20))
        XCTAssertEqual(layout.scale, 0)
        XCTAssertFalse(layout.placements[0].isVisible)
    }

    private func rectangle(_ placement: MapMarkerSizing.Placement, scale: Double) -> CGRect {
        let w = max(44, MapMarkerSizing.width * scale), h = max(44, MapMarkerSizing.height * scale)
        return CGRect(x: placement.center.x - w / 2, y: placement.center.y - h / 2, width: w, height: h)
    }

    private func assertSeparate(_ layout: MapMarkerSizing.Layout, file: StaticString = #filePath, line: UInt = #line) {
        let rectangles = layout.placements.filter(\.isVisible).map { rectangle($0, scale: layout.scale) }
        for i in rectangles.indices {
            XCTAssertTrue(viewport.contains(rectangles[i]), file: file, line: line)
            for j in rectangles.indices where j > i {
                XCTAssertFalse(rectangles[i].insetBy(dx: -8, dy: -8).intersects(rectangles[j]), file: file, line: line)
            }
        }
    }
}
