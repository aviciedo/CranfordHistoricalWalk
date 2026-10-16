import XCTest
@testable import TourCore

final class PolylineTests: XCTestCase {
    /// Google's documented example: `_p~iF~ps|U_ulLnnqC_mqNvxq`@` -> three points.
    func testDecodesGoogleReferenceExample() {
        let points = Polyline.decode("_p~iF~ps|U_ulLnnqC_mqNvxq`@")
        XCTAssertEqual(points.count, 3)
        XCTAssertEqual(points[0].latitude, 38.5, accuracy: 1e-5)
        XCTAssertEqual(points[0].longitude, -120.2, accuracy: 1e-5)
        XCTAssertEqual(points[1].latitude, 40.7, accuracy: 1e-5)
        XCTAssertEqual(points[1].longitude, -120.95, accuracy: 1e-5)
        XCTAssertEqual(points[2].latitude, 43.252, accuracy: 1e-5)
        XCTAssertEqual(points[2].longitude, -126.453, accuracy: 1e-5)
    }

    func testEncodeMatchesReference() {
        let points = [
            GeoCoordinate(latitude: 38.5, longitude: -120.2),
            GeoCoordinate(latitude: 40.7, longitude: -120.95),
            GeoCoordinate(latitude: 43.252, longitude: -126.453)
        ]
        XCTAssertEqual(Polyline.encode(points), "_p~iF~ps|U_ulLnnqC_mqNvxq`@")
    }

    func testRoundTripWalkingScale() {
        var points: [GeoCoordinate] = [cranfordCenter]
        for i in 1...40 {
            points.append(GeoMath.destination(from: points.last!, bearing: Double(i * 17 % 360), distance: 12))
        }
        let decoded = Polyline.decode(Polyline.encode(points))
        XCTAssertEqual(decoded.count, points.count)
        for (a, b) in zip(points, decoded) {
            XCTAssertEqual(a.latitude, b.latitude, accuracy: 1e-5)
            XCTAssertEqual(a.longitude, b.longitude, accuracy: 1e-5)
        }
    }

    func testEmptyAndGarbageInputDoNotCrash() {
        XCTAssertTrue(Polyline.decode("").isEmpty)
        XCTAssertTrue(Polyline.decode("!!!").isEmpty)
        XCTAssertTrue(Polyline.decode("_p~iF").isEmpty, "a latitude without its longitude must not become a point")
    }

    func testIncompleteFinalPairDoesNotShiftEarlierPoints() {
        let full = Polyline.decode("_p~iF~ps|U_ulLnnqC_mqNvxq`@")
        XCTAssertEqual(full.count, 3)
        // A trailing continuation chunk (`_`) has a latitude delta and no longitude.
        let truncated = Polyline.decode("_p~iF~ps|U_ulLnnqC_")
        XCTAssertEqual(truncated.count, 2)
        XCTAssertEqual(truncated[0].latitude, full[0].latitude, accuracy: 1e-6)
        XCTAssertEqual(truncated[0].longitude, full[0].longitude, accuracy: 1e-6)
        XCTAssertEqual(truncated[1].latitude, full[1].latitude, accuracy: 1e-6)
        XCTAssertEqual(truncated[1].longitude, full[1].longitude, accuracy: 1e-6)
    }
}
