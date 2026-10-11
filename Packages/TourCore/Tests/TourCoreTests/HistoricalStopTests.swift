import XCTest
@testable import TourCore

final class HistoricalStopTests: XCTestCase {
    func testBundledSampleJSONDecodesAndIsOrdered() throws {
        let document = try HistoricalStopDecoder.decode(Fixtures.data("historical_stops"))
        XCTAssertEqual(document.schemaVersion, 1)
        XCTAssertEqual(document.stops.count, 5)
        XCTAssertEqual(document.stops.map(\.order), [1, 2, 3, 4, 5])
        XCTAssertEqual(Set(document.stops.map(\.id)).count, 5)
    }

    func testSampleDataIsHonestlyLabeled() throws {
        let stops = try Fixtures.sampleStops()
        for stop in stops {
            XCTAssertTrue(stop.isSample, "\(stop.id) must be flagged isSample until verified")
            XCTAssertTrue(stop.address.contains("SAMPLE LOCATION"), "\(stop.id) address must carry the SAMPLE LOCATION label")
            XCTAssertTrue(stop.shortDescription.contains("SAMPLE HISTORICAL DESCRIPTION"))
            XCTAssertNil(stop.historicalDate, "No dates may be asserted for sample stops")
            XCTAssertEqual(stop.arrivalRadius, 35)
            XCTAssertEqual(stop.effectiveDepartureRadius, 50)
        }
    }

    func testSampleCoordinatesAreNearCranford() throws {
        // Loose sanity check: all sample points within ~2.5 km of a downtown reference point.
        for stop in try Fixtures.sampleStops() {
            XCTAssertLessThan(GeoMath.distance(from: cranfordCenter, to: stop.coordinate), 2500, stop.id)
        }
    }

    func testDefaultsAppliedForOmittedKeys() throws {
        let json = """
        {"schemaVersion":1,"tourName":"T","stops":[{"id":"a","name":"A","latitude":40.65,"longitude":-74.30,"order":1}]}
        """.data(using: .utf8)!
        let stop = try HistoricalStopDecoder.decode(json).stops[0]
        XCTAssertEqual(stop.arrivalRadius, 35)
        XCTAssertEqual(stop.effectiveDepartureRadius, 50)
        XCTAssertEqual(stop.estimatedVisitDuration, 90)
        XCTAssertEqual(stop.address, "Cranford, NJ")
        XCTAssertFalse(stop.hasAnyImage)
        XCTAssertFalse(stop.isSample)
    }

    func testDepartureRadiusNeverBelowArrival() {
        let stop = makeStop(arrival: 40, departure: 20)
        XCTAssertEqual(stop.effectiveDepartureRadius, 56, accuracy: 0.001) // max(40+15, 40*1.4)
    }

    func testRejectsDuplicateIDs() {
        let json = """
        {"schemaVersion":1,"tourName":"T","stops":[
          {"id":"a","name":"A","latitude":40.65,"longitude":-74.30,"order":1},
          {"id":"a","name":"B","latitude":40.66,"longitude":-74.31,"order":2}]}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try HistoricalStopDecoder.decode(json)) { error in
            XCTAssertEqual(error as? HistoricalStopDecodingError, .duplicateIdentifiers(["a"]))
        }
    }

    func testRejectsInvalidCoordinateAndEmptyTour() {
        let bad = """
        {"schemaVersion":1,"tourName":"T","stops":[{"id":"a","name":"A","latitude":140.65,"longitude":-74.30,"order":1}]}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try HistoricalStopDecoder.decode(bad))
        let empty = #"{"schemaVersion":1,"tourName":"T","stops":[]}"#.data(using: .utf8)!
        XCTAssertThrowsError(try HistoricalStopDecoder.decode(empty)) { error in
            XCTAssertEqual(error as? HistoricalStopDecodingError, .emptyTour)
        }
    }

    func testRoundTripsThroughCodable() throws {
        let stops = try Fixtures.sampleStops()
        let data = try JSONEncoder().encode(stops)
        let decoded = try JSONDecoder().decode([HistoricalStop].self, from: data)
        XCTAssertEqual(decoded, stops)
    }
}
