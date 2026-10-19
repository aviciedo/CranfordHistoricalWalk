import XCTest
@testable import TourCore

final class HistoricalStopTests: XCTestCase {
    func testBundledTourJSONIsFiveHPABStops() throws {
        let document = try HistoricalStopDecoder.decode(Fixtures.data("historical_stops"))
        XCTAssertEqual(document.schemaVersion, 1)
        XCTAssertEqual(document.stops.map(\.name), [
            "Droescher’s Mill", "Greystone", "Rahway River", "First Baptist Church", "Cranford Hotel"
        ])
        XCTAssertEqual(document.stops.map(\.order), [1, 2, 3, 4, 5])
        XCTAssertEqual(document.stops.map(\.id), ["hpab-001", "hpab-002", "hpab-003", "hpab-004", "hpab-005"])
        XCTAssertTrue(document.dataStatus?.contains("HPAB") == true)
        XCTAssertEqual(document.stops[0].imageName, "droeschers-mill")
        XCTAssertEqual(document.stops[0].historicalDate, "Construction: After 1821")
        XCTAssertEqual(document.stops[0].plaque?.transcription, "c. 1737")
        XCTAssertEqual(document.stops[0].plaque?.quoteLabel, "Door plaque")
        XCTAssertEqual(document.stops[0].plaque?.referenceImageName, SignPlacementPolicy.millReferenceImageName)
        XCTAssertEqual(document.stops[0].plaque?.physicalWidthMeters, SignPlacementPolicy.assumedPlaqueWidthMeters)
        XCTAssertTrue(document.stops[0].hasPlaqueReference)
        XCTAssertFalse((document.stops[0].plaque?.transcription ?? "").contains("1797"))
        XCTAssertEqual(document.stops[1].plaque?.referenceImageName, SignPlacementPolicy.parkReferenceImageName)
        let audioFiles = ["Rahway River.mp3", "First Baptist.mp3", "Cranford Hotel.mp3"]
        for (stop, file) in zip(document.stops.dropFirst(2), audioFiles) {
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
            XCTAssertNil(stop.narrationText)
            XCTAssertEqual(stop.narrationVoicePreference, .systemDefault)
        }
    }

    func testGreystoneUsesCreatorContentAndPreservesTheExistingTourDestination() throws {
        let stop = try HistoricalStopDecoder.decode(Fixtures.data("historical_stops")).stops[1]
        XCTAssertEqual(stop.id, "hpab-002", "Keep existing visits and navigation associated with this stop")
        XCTAssertEqual(stop.name, "Greystone")
        XCTAssertEqual(stop.order, 2)
        XCTAssertEqual(stop.latitude, 40.6524)
        XCTAssertEqual(stop.longitude, -74.2990)
        XCTAssertEqual(stop.address, "600 Lincoln Park East, Cranford, NJ")
        XCTAssertTrue(stop.coordinatesUnverified)
        XCTAssertEqual(stop.arrivalRadius, 35)
        XCTAssertEqual(stop.effectiveDepartureRadius, 50)
        XCTAssertEqual(stop.historicalDate, "Built: Beginning in 1920")
        XCTAssertTrue(stop.markerInformation.contains("25-room mansion"))
        XCTAssertTrue(stop.longDescription.contains("Charles E. Kaltenbach"))
        XCTAssertTrue(stop.longDescription.contains("In 1939, it reopened as Cranford Hall"))
        let script = try XCTUnwrap(stop.narrationText)
        XCTAssertTrue(script.hasPrefix("Greystone: The Castle on the River"))
        XCTAssertTrue(script.contains("Gloria Swanson"))
        XCTAssertTrue(script.contains("William Randolph Hearst"))
        XCTAssertTrue(script.contains("Cranford Park Care"))
        XCTAssertTrue(script.hasSuffix("continuous transformation of our town."))
        XCTAssertGreaterThan(script.split(whereSeparator: \.isWhitespace).count, 330)
        XCTAssertEqual(stop.audioURL?.relativeString, "stop_02_greystone.mp3")
        XCTAssertEqual(stop.narrationSource, .bundledAudio(fileName: "stop_02_greystone.mp3"))
        XCTAssertEqual(stop.narrationVoicePreference, .warmMaleEnglish)
        XCTAssertEqual(stop.imageName, "greystone")
        XCTAssertEqual(stop.galleryPhotos.map(\.imageName), [
            "greystone", "greystone-additional-view", "greystone-tower", "greystone-stonework", "greystone-footbridge-1912",
            "greystone-gloria-swanson", "greystone-william-randolph-hearst"
        ])
        XCTAssertEqual(stop.galleryPhotos[0].caption, "Greystone")
        XCTAssertTrue(stop.galleryPhotos[4].caption.contains("1912"))
        XCTAssertTrue(stop.galleryPhotos[4].credit?.contains("Part IV, PDF page 6") == true)
        XCTAssertTrue(stop.hasPlaqueReference)
        XCTAssertEqual(stop.plaque?.transcription, "Cranford Park")
        XCTAssertEqual(stop.plaque?.referenceImageName, SignPlacementPolicy.parkReferenceImageName)
        XCTAssertEqual(stop.plaque?.physicalWidthMeters, SignPlacementPolicy.assumedParkReferenceWidthMeters)
        XCTAssertEqual(try JSONDecoder().decode(HistoricalStop.self, from: JSONEncoder().encode(stop)), stop)
    }

    func testPhotoGalleryPreservesOrderCaptionsAndCreditsAcrossCodable() throws {
        var stop = makeStop()
        stop.imageName = "cover"
        stop.photos = [
            HistoricalStopPhoto(imageName: "cover", caption: "Main photo"),
            HistoricalStopPhoto(imageName: "  bridge  ", caption: "Stone footbridge, 1912", credit: "Archive, page 6"),
            HistoricalStopPhoto(imageName: "cover", caption: "Duplicate"),
            HistoricalStopPhoto(imageName: "\n", caption: "Invalid"),
            HistoricalStopPhoto(imageName: "portrait", caption: "Portrait")
        ]
        XCTAssertEqual(stop.galleryPhotos.map(\.imageName), ["cover", "bridge", "portrait"])
        XCTAssertEqual(stop.galleryPhotos[0].caption, "Main photo")
        XCTAssertEqual(stop.galleryPhotos[1].credit, "Archive, page 6")
        XCTAssertTrue(stop.hasAnyImage)
        let decoded = try JSONDecoder().decode(HistoricalStop.self, from: JSONEncoder().encode(stop))
        XCTAssertEqual(decoded, stop)
        XCTAssertEqual(decoded.galleryPhotos, stop.galleryPhotos)
        stop.imageName = nil
        XCTAssertTrue(stop.hasAnyImage, "A gallery-only stop still supplies cover artwork")
        XCTAssertEqual(stop.galleryPhotos.first?.imageName, "cover")
    }

    func testLegacySinglePhotoStopsKeepTheirCoverAndEmptyPhotoNamesAreIgnored() {
        var stop = makeStop()
        stop.imageName = "legacy-cover"
        XCTAssertEqual(stop.galleryPhotos, [HistoricalStopPhoto(imageName: "legacy-cover", caption: stop.name)])
        stop.imageName = "  "
        stop.photos = [HistoricalStopPhoto(imageName: "", caption: "Empty")]
        XCTAssertFalse(stop.hasAnyImage)
        XCTAssertTrue(stop.galleryPhotos.isEmpty)
    }

    func testMillUsesTheFullCreatorScriptAndKeepsItsPhysicalPlaqueReference() throws {
        let mill = try HistoricalStopDecoder.decode(Fixtures.data("historical_stops")).stops[0]
        XCTAssertEqual(mill.address, "347 Lincoln Avenue East, Cranford, NJ")
        XCTAssertTrue(mill.markerInformation.contains("After 1821"))
        XCTAssertTrue(mill.markerInformation.contains("at least 1779"))
        XCTAssertTrue(mill.markerInformation.contains("Last surviving historic mill on the Rahway River."))
        XCTAssertFalse(mill.markerInformation.contains("1737"), "The plaque inscription is not the current building's construction date")
        XCTAssertTrue(mill.longDescription.contains("Severin Droescher"))
        XCTAssertTrue(mill.longDescription.contains("pipe organs"))
        XCTAssertEqual(mill.audioURL?.relativeString, "stop_01_droeschers_mill.mp3")
        let script = try XCTUnwrap(mill.narrationText)
        XCTAssertTrue(script.hasPrefix("Droescher’s Mill: A River That Built a Town"))
        XCTAssertTrue(script.contains("Alleum Yoga"))
        XCTAssertTrue(script.contains("healthcare sector"))
        XCTAssertTrue(script.contains("National Register of Historic Places in 1974"))
        XCTAssertTrue(script.contains("Cranford historic landmark in 2014"))
        XCTAssertTrue(script.hasSuffix("this is the last survivor."))
        XCTAssertGreaterThan(script.split(whereSeparator: \.isWhitespace).count, 330)
        XCTAssertEqual(mill.narrationSource, .bundledAudio(fileName: "stop_01_droeschers_mill.mp3"))
        XCTAssertEqual(mill.narrationVoicePreference, .warmMaleEnglish)
        XCTAssertEqual(mill.plaque?.transcription, "c. 1737")
        XCTAssertEqual(mill.plaque?.referenceImageName, SignPlacementPolicy.millReferenceImageName)
        XCTAssertEqual(try JSONDecoder().decode(HistoricalStop.self, from: JSONEncoder().encode(mill)), mill)
    }

    func testDedicatedNarrationIsSeparateFromTheScreenDescription() throws {
        var stop = makeStop()
        stop.longDescription = "Short screen description."
        stop.narrationText = "  Full story for the listener.\n\nA second paragraph.  "
        XCTAssertEqual(stop.narrationSource, .synthesizedSpeech(text: "Full story for the listener.\n\nA second paragraph."))
        stop.audioURL = URL(string: "https://example.org/a-future-recording.m4a")
        XCTAssertEqual(stop.narrationSource, .remoteAudio(stop.audioURL!), "A real recording can be added later while retaining its transcript")
        stop.audioURL = nil
        stop.narrationText = " \n "
        XCTAssertEqual(stop.narrationSource, .synthesizedSpeech(text: stop.longDescription))
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
        XCTAssertNil(stop.narrationText)
        XCTAssertTrue(stop.photos.isEmpty)
        XCTAssertEqual(stop.narrationVoicePreference, .systemDefault)
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
