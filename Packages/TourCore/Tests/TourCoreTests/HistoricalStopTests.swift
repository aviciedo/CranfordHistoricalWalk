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

    func testNarrationSourceResolution() throws {
        func stop(audio: String?, long: String = "Long text.", short: String = "Short.") throws -> HistoricalStop {
            var json: [String: Any] = ["id": "n", "name": "N", "latitude": 40.65, "longitude": -74.30, "order": 1, "longDescription": long, "shortDescription": short]
            if let audio { json["audioURL"] = audio }
            let data = try JSONSerialization.data(withJSONObject: json)
            return try JSONDecoder().decode(HistoricalStop.self, from: data)
        }
        XCTAssertEqual(try stop(audio: "https://example.org/mill.m4a").narrationSource, .remoteAudio(URL(string: "https://example.org/mill.m4a")!))
        XCTAssertEqual(try stop(audio: "droeschers-mill.m4a").narrationSource, .bundledAudio(fileName: "droeschers-mill.m4a"))
        XCTAssertEqual(try stop(audio: "Audio/droeschers-mill.m4a").narrationSource, .bundledAudio(fileName: "droeschers-mill.m4a"), "folder prefixes are ignored; resources are flat in the bundle")
        XCTAssertEqual(try stop(audio: nil).narrationSource, .synthesizedSpeech(text: "Long text."))
        XCTAssertEqual(try stop(audio: nil, long: "  ").narrationSource, .synthesizedSpeech(text: "Short."))
        XCTAssertNil(try stop(audio: nil, long: "", short: "").narrationSource)
    }

    func testHPABAudioTourCatalogDecodesWithRecordingsAndUnverifiedCoordinates() throws {
        let document = try HistoricalStopDecoder.decode(Fixtures.data("hpab_audio_tour"))
        XCTAssertEqual(document.stops.count, 25)
        XCTAssertEqual(document.stops.map(\.order), Array(1...25))
        XCTAssertEqual(Set(document.stops.map(\.id)).count, 25)
        XCTAssertTrue(document.dataStatus?.contains("HPAB") == true)
        for stop in document.stops {
            XCTAssertFalse(stop.isSample, "\(stop.id) is sourced HPAB content, not sample filler")
            XCTAssertTrue(stop.coordinatesUnverified, "\(stop.id) coordinates are geocodes, not surveyed")
            XCTAssertEqual(stop.arrivalRadius, 35)
            XCTAssertEqual(stop.effectiveDepartureRadius, 50)
            guard case .remoteAudio(let url) = stop.narrationSource else {
                return XCTFail("\(stop.id) must play the HPAB QR recording, not synthesized speech")
            }
            XCTAssertEqual(url.scheme, "http")
            XCTAssertTrue(url.host?.contains("preservecranford.com") == true)
            XCTAssertTrue(url.path.lowercased().hasSuffix(".mp3"))
        }
        let mill = try XCTUnwrap(document.stops.first)
        XCTAssertEqual(mill.id, "hpab-001")
        XCTAssertEqual(mill.name, "Droescher's Mill")
        XCTAssertEqual(mill.imageName, "droeschers-mill")
        XCTAssertTrue(mill.hasAnyImage)
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
        XCTAssertFalse(stop.coordinatesUnverified)
        XCTAssertEqual(stop.narrationSource, nil)
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
