import XCTest
@testable import TourCore

final class MapMarkerSizingTests: XCTestCase {
    func testZoomChangesSizeWithoutChangingRelativeMarkerSizes() {
        let points: [SIMD2<Double>] = [[0, 0], [200, 200]]
        let overview = MapMarkerSizing.scale(points: points, metersPerPoint: 10)
        let detail = MapMarkerSizing.scale(points: points, metersPerPoint: 2.5)
        XCTAssertGreaterThan(detail, overview)
        XCTAssertLessThanOrEqual(detail, 1.4)
    }

    func testDenseAndRotatedLayoutsNeverOverlapIllustrationOrNumber() {
        let original: [SIMD2<Double>] = [[0, 0], [8, 10], [60, 15], [150, 180], [90, 92]]
        for degrees in stride(from: 0.0, to: 360.0, by: 15) {
            let angle = degrees * Double.pi / 180
            for zoom in [0.1, 0.5, 1.0, 2.0, 8.0] {
                let points = original.map { p in
                    SIMD2((p.x * cos(angle) - p.y * sin(angle)) * zoom,
                          (p.x * sin(angle) + p.y * cos(angle)) * zoom)
                }
                let scale = MapMarkerSizing.scale(points: points, metersPerPoint: 5 / zoom)
                for i in points.indices {
                    for j in points.indices where j > i {
                        let delta = points[i] - points[j]
                        XCTAssertTrue(abs(delta.x) > MapMarkerSizing.width * scale
                                      || abs(delta.y) > MapMarkerSizing.height * scale)
                    }
                }
            }
        }
    }

    func testEmptyAndInvalidCameraInputIsSafe() {
        XCTAssertEqual(MapMarkerSizing.scale(points: [], metersPerPoint: 2.5), 1)
        XCTAssertEqual(MapMarkerSizing.scale(points: [], metersPerPoint: 0), 0)
        XCTAssertEqual(MapMarkerSizing.scale(points: [], metersPerPoint: .nan), 0)
    }
}
