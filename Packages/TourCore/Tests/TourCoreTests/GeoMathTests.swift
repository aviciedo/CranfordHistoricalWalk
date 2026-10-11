import XCTest
@testable import TourCore

final class GeoMathTests: XCTestCase {
    func testHaversineKnownDistance() {
        // One degree of latitude ≈ 111.2 km.
        let a = GeoCoordinate(latitude: 40, longitude: -74)
        let b = GeoCoordinate(latitude: 41, longitude: -74)
        XCTAssertEqual(GeoMath.distance(from: a, to: b), 111_195, accuracy: 100)
        XCTAssertEqual(GeoMath.distance(from: a, to: a), 0)
    }

    func testBearingCardinals() {
        let o = cranfordCenter
        XCTAssertEqual(GeoMath.bearing(from: o, to: GeoMath.destination(from: o, bearing: 0, distance: 100)), 0, accuracy: 0.01)
        XCTAssertEqual(GeoMath.bearing(from: o, to: GeoMath.destination(from: o, bearing: 90, distance: 100)), 90, accuracy: 0.05)
        XCTAssertEqual(GeoMath.bearing(from: o, to: GeoMath.destination(from: o, bearing: 180, distance: 100)), 180, accuracy: 0.01)
        XCTAssertEqual(GeoMath.bearing(from: o, to: GeoMath.destination(from: o, bearing: 270, distance: 100)), 270, accuracy: 0.05)
    }

    func testDestinationRoundTrip() {
        let p = GeoMath.destination(from: cranfordCenter, bearing: 37, distance: 250)
        XCTAssertEqual(GeoMath.distance(from: cranfordCenter, to: p), 250, accuracy: 0.01)
        XCTAssertEqual(GeoMath.bearing(from: cranfordCenter, to: p), 37, accuracy: 0.01)
    }

    func testRelativeBearingWrapsCorrectly() {
        XCTAssertEqual(GeoMath.relativeBearing(heading: 350, bearing: 10), 20)
        XCTAssertEqual(GeoMath.relativeBearing(heading: 10, bearing: 350), -20)
        XCTAssertEqual(GeoMath.relativeBearing(heading: 90, bearing: 270), 180)
        XCTAssertEqual(GeoMath.relativeBearing(heading: 0, bearing: 0), 0)
    }

    func testNormalizeBearing() {
        XCTAssertEqual(GeoMath.normalizeBearing(-90), 270)
        XCTAssertEqual(GeoMath.normalizeBearing(360), 0)
        XCTAssertEqual(GeoMath.normalizeBearing(725), 5)
    }

    func testLocalOffsetMatchesDestination() {
        let east = GeoMath.destination(from: cranfordCenter, bearing: 90, distance: 120)
        let offset = GeoMath.localOffset(of: east, from: cranfordCenter)
        XCTAssertEqual(offset.east, 120, accuracy: 0.1)
        XCTAssertEqual(offset.north, 0, accuracy: 0.1)
    }

    func testProjectionOntoSegment() {
        let a = cranfordCenter
        let b = GeoMath.destination(from: a, bearing: 90, distance: 200)
        // 50 m east, 30 m north of the segment -> fraction .25, distance 30.
        let mid = GeoMath.destination(from: a, bearing: 90, distance: 50)
        let p = GeoMath.destination(from: mid, bearing: 0, distance: 30)
        let projection = GeoMath.project(p, ontoSegment: a, b)
        XCTAssertEqual(projection.fraction, 0.25, accuracy: 0.005)
        XCTAssertEqual(projection.distance, 30, accuracy: 0.2)

        // Beyond the end clamps to b.
        let beyond = GeoMath.destination(from: b, bearing: 90, distance: 40)
        let clamped = GeoMath.project(beyond, ontoSegment: a, b)
        XCTAssertEqual(clamped.fraction, 1)
        XCTAssertEqual(clamped.distance, 40, accuracy: 0.2)
    }

    func testUnitConversions() {
        XCTAssertEqual(GeoMath.miles(fromMeters: 1609.344), 1, accuracy: 1e-9)
        XCTAssertEqual(GeoMath.feet(fromMeters: 1), 3.28084, accuracy: 1e-4)
    }
}
