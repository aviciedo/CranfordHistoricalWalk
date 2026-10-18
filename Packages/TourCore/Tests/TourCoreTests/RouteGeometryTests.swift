import XCTest
@testable import TourCore

final class RouteGeometryTests: XCTestCase {
    func testInteriorRerouteDiffersEvenWhenEndpointsAndMidpointMatch() {
        let original = (0..<5).map { GeoCoordinate(latitude: 40, longitude: Double($0)) }
        var rerouted = original
        rerouted[1].latitude += 0.001

        XCTAssertFalse(RouteGeometry.coordinatesMatch(original, rerouted))
        XCTAssertEqual(original.first, rerouted.first)
        XCTAssertEqual(original.last, rerouted.last)
        XCTAssertEqual(original[original.count / 2], rerouted[rerouted.count / 2])
    }

    func testIdenticalAndEmptyPathsMatch() {
        let path = [
            GeoCoordinate(latitude: 40.6551, longitude: -74.2926),
            GeoCoordinate(latitude: 40.6560, longitude: -74.2940)
        ]
        XCTAssertTrue(RouteGeometry.coordinatesMatch(path, path))
        XCTAssertTrue(RouteGeometry.coordinatesMatch([], []))
        XCTAssertFalse(RouteGeometry.coordinatesMatch(path, []))
        XCTAssertFalse(RouteGeometry.coordinatesMatch(path, Array(path.dropLast())))
    }

    func testReversedPathIsADifferentRoute() {
        let path = [
            GeoCoordinate(latitude: 40.65, longitude: -74.30),
            GeoCoordinate(latitude: 40.66, longitude: -74.31)
        ]
        XCTAssertFalse(RouteGeometry.coordinatesMatch(path, Array(path.reversed())))
    }
}
