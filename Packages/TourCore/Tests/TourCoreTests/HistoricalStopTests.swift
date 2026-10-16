import XCTest
@testable import TourCore

final class HistoricalStopTests: XCTestCase {
    func testBundledTourJSONIsFiveHPABStops() throws {
        let document = try HistoricalStopDecoder.decode(Fixtures.data("historical_stops"))
        XCTAssertEqual(document.schemaVersion, 1)
        XCTAssertEqual(document.stops.map(\.name), [
            "Droescher's Mill", "Cranford Hall", "Rahway River", "First Baptist Church", "Cranford Hotel"
        ])
        XCTAssertEqual(document.stops.map(\.order), [1, 2, 3, 4, 5])
        XCTAssertEqual(document.stops.map(\.id), ["hpab-001", "hpab-002", "hpab-003", "hpab-004", "hpab-005"])
        XCTAssertTrue(document.dataStatus?.contains("HPAB") == true)
        XCTAssertEqual(document.stops[0].imageName, "droeschers-mill")
        XCTAssertEqual(document.stops[0].historicalDate, "c. 1737")
        XCTAssertEqual(document.stops[0].plaque?.transcription, "c. 1737")
        XCTAssertEqual(document.stops[0].plaque?.quoteLabel, "Door plaque")
        XCTAssertEqual(document.stops[0].plaque?.referenceImageName, SignPlacementPolicy.millReferenceImageName)
        XCTAssertEqual(document.stops[0].plaque?.physicalWidthMeters, SignPlacementPolicy.assumedPlaqueWidthMeters)
        XCTAssertTrue(document.stops[0].hasPlaqueReference)
        XCTAssertFalse((document.stops[0].plaque?.transcription ?? "").contains("1797"))
        XCTAssertNil(document.stops[1].plaque)
        let audioFiles = ["Droescher Mill.mp3", "Greystone.mp3", "Rahway River.mp3", "First Baptist.mp3", "Cranford Hotel.mp3"]
        for (stop, file) in zip(document.stops, audioFiles) {
            XCTAssertFalse(stop.isSample)
            XCTAssertTrue(stop.coordinatesUnverified)
            XCTAssertEqual(stop.arrivalRadius, 35)
            XCTAssertEqual(stop.effectiveDepartureRadius, 50)
            guard case .remoteAudio(let url) = stop.narrationSource else {
                return XCTFail("\(stop.id) must play the HPAB QR recording")
            }
            XCTAssertEqual(url.scheme, "http")
            XCTAssertTrue(url.host?.contains("preservecranford.com") == true)
            XCTAssertEqual(url.lastPathComponent, file)
        }
    }

    func testSampleDataIsHonestlyLabeled() throws {
        let stops = try Fixtures.sampleStops()
        XCTAssertEqual(stops.count, 3)
        XCTAssertEqual(stops.map(\.order), [1, 2, 3])
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
        XCTAssertEqual(try stop(audio: "file:///tmp/mill.m4a").narrationSource, .remoteAudio(URL(string: "file:///tmp/mill.m4a")!))
        XCTAssertEqual(try stop(audio: "ftp://example.org/mill.mp3").narrationSource, .synthesizedSpeech(text: "Long text."))
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
        let equal = makeStop(arrival: 40, departure: 40)
        XCTAssertEqual(equal.effectiveDepartureRadius, 56, accuracy: 0.001, "a radius equal to arrival would flap; keep the hysteresis floor")
    }

    func testStopsAreSortedByOrderThenIdentifier() throws {
        let json = """
        {"schemaVersion":1,"tourName":"T","stops":[
          {"id":"c","name":"C","latitude":40.67,"longitude":-74.32,"order":2},
          {"id":"a","name":"A","latitude":40.65,"longitude":-74.30,"order":1},
          {"id":"b","name":"B","latitude":40.66,"longitude":-74.31,"order":2}
        ]}
        """.data(using: .utf8)!
        let stops = try HistoricalStopDecoder.decode(json).stops
        XCTAssertEqual(stops.map(\.id), ["a", "b", "c"])
    }

    func testUnusablePlaqueIsNotATrackingReference() throws {
        func decoded(_ plaque: String) throws -> HistoricalStop {
            let json = """
            {"schemaVersion":1,"tourName":"T","stops":[
              {"id":"a","name":"A","latitude":40.65,"longitude":-74.30,"order":1,"plaque":\(plaque)}
            ]}
            """.data(using: .utf8)!
            return try HistoricalStopDecoder.decode(json).stops[0]
        }
        XCTAssertFalse(try decoded(#"{"transcription":"  ","quoteLabel":"Door plaque","referenceImageName":"plate","physicalWidthMeters":0.18}"#).hasPlaqueReference)
        XCTAssertFalse(try decoded(#"{"transcription":"c. 1737","quoteLabel":"Door plaque","referenceImageName":"","physicalWidthMeters":0.18}"#).hasPlaqueReference)
        XCTAssertFalse(try decoded(#"{"transcription":"c. 1737","quoteLabel":"Door plaque","referenceImageName":"plate","physicalWidthMeters":0}"#).hasPlaqueReference)
        XCTAssertFalse(try decoded(#"{"transcription":"c. 1737","quoteLabel":"Door plaque","referenceImageName":"plate","physicalWidthMeters":-0.2}"#).hasPlaqueReference)
        let missingLabel = """
        {"schemaVersion":1,"tourName":"T","stops":[
          {"id":"a","name":"A","latitude":40.65,"longitude":-74.30,"order":1,"plaque":{"transcription":"c. 1737","referenceImageName":"plate","physicalWidthMeters":0.18}}
        ]}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try HistoricalStopDecoder.decode(missingLabel))
        let usable = try decoded(#"{"transcription":"c. 1737","quoteLabel":"Door plaque","referenceImageName":"plate","physicalWidthMeters":0.18}"#)
        XCTAssertTrue(usable.hasPlaqueReference)
        XCTAssertEqual(usable.plaque?.transcription, "c. 1737")
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
        let badLatitude = """
        {"schemaVersion":1,"tourName":"T","stops":[{"id":"a","name":"A","latitude":140.65,"longitude":-74.30,"order":1}]}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try HistoricalStopDecoder.decode(badLatitude)) { error in
            XCTAssertEqual(error as? HistoricalStopDecodingError, .invalidCoordinate(stopID: "a"))
        }
        let badLongitude = """
        {"schemaVersion":1,"tourName":"T","stops":[{"id":"edge","name":"E","latitude":40.65,"longitude":181,"order":1}]}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try HistoricalStopDecoder.decode(badLongitude)) { error in
            XCTAssertEqual(error as? HistoricalStopDecodingError, .invalidCoordinate(stopID: "edge"))
        }
        XCTAssertFalse(GeoCoordinate(latitude: .nan, longitude: -74.3).isValid)
        XCTAssertFalse(GeoCoordinate(latitude: 40.65, longitude: .infinity).isValid)
        XCTAssertTrue(GeoCoordinate(latitude: 90, longitude: 180).isValid)
        XCTAssertTrue(GeoCoordinate(latitude: -90, longitude: -180).isValid)
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
