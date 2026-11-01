import XCTest
@testable import TourCore

final class StopArtworkTests: XCTestCase {
    func testSecondCatalogCarriesMediaAndKeepsOldResumeNamespacesSeparate() throws {
        let legacy = try HistoricalStopDecoder.decode(Fixtures.data("sample_historical_stops"))
        let second = try HistoricalStopDecoder.decode(Fixtures.data("second_tour"))
        let catalog = try TourCatalog(tours: [legacy, second])
        let stop = try XCTUnwrap(catalog.tours.last?.stops.first)
        XCTAssertEqual(stop.artwork?.homeInk, "home-sketch-mill")
        XCTAssertEqual(stop.artwork?.listInk, "stop-ink-mill")
        XCTAssertNil(stop.artwork?.watercolor, "Adding a catalog never invents an unlock")
        XCTAssertEqual(stop.catalogID, second.identity.tourID)
        let roundtrip = try HistoricalStopDecoder.decode(JSONEncoder().encode(second))
        XCTAssertEqual(roundtrip.stops.first?.artwork, stop.artwork)
        XCTAssertNotEqual(legacy.identity.storageKey("activities"), second.identity.storageKey("activities"))
        XCTAssertEqual(legacy.identity.storageKey("cranford.stop-activities.v1"), "cranford.stop-activities.v1")
    }
    func testMalformedMediaCannotBecomeFilePathsOrCacheSeparators() throws {
        for invalid in ["", "../bad", "bad\\path", "bad\u{1f}key", "\n"] {
            var doc = try HistoricalStopDecoder.decode(Fixtures.data("second_tour"))
            doc.stops[0].artwork = StopArtwork(listInk: invalid)
            XCTAssertThrowsError(try HistoricalStopDecoder.decode(JSONEncoder().encode(doc)))
        }
        XCTAssertFalse(StopArtwork(listHeight: .nan).isValid)
        XCTAssertFalse(StopArtwork(listHeight: 10000).isValid)
    }
    func testRevisedMediaChangesRenderingCacheIdentity() {
        let first = StopArtwork(listInk: "original", mapLandmark: "landmark")
        let second = StopArtwork(listInk: "updated", mapLandmark: "landmark")
        XCTAssertNotEqual(first.cacheKey, second.cacheKey)
        XCTAssertTrue(first.isValid)
    }

    func testArtworkBoundsAcceptTheClosedLimitsOnly() throws {
        let limit = String(repeating: "n", count: 160)
        XCTAssertTrue(StopArtwork(homeInk: limit, listHeight: 44).isValid)
        XCTAssertTrue(StopArtwork(listHeight: 160).isValid)
        XCTAssertTrue(StopArtwork().isValid)
        XCTAssertFalse(StopArtwork(listInk: limit + "x").isValid)
        XCTAssertFalse(StopArtwork(listInk: " ").isValid)
        XCTAssertFalse(StopArtwork(listInk: "a\u{0007}b").isValid)
        XCTAssertFalse(StopArtwork(listHeight: 43.999).isValid)
        XCTAssertFalse(StopArtwork(listHeight: 160.001).isValid)
        XCTAssertFalse(StopArtwork(listHeight: .infinity).isValid)
        XCTAssertFalse(StopArtwork(listHeight: -44).isValid)

        var document = try HistoricalStopDecoder.decode(Fixtures.data("second_tour"))
        document.stops[0].artwork = StopArtwork(listInk: limit, listHeight: 44)
        XCTAssertTrue(try HistoricalStopDecoder.decode(JSONEncoder().encode(document)).stops[0].artwork?.isValid == true)
        document.stops[0].artwork = StopArtwork(listHeight: 160)
        XCTAssertEqual(try HistoricalStopDecoder.decode(JSONEncoder().encode(document)).stops[0].artwork?.listHeight, 160)
        for invalid in [StopArtwork(listInk: limit + "x"), StopArtwork(listHeight: 43.999), StopArtwork(listHeight: 160.001)] {
            document.stops[0].artwork = invalid
            XCTAssertThrowsError(try HistoricalStopDecoder.decode(JSONEncoder().encode(document)))
        }
    }

    func testRenderedImageCacheSeparatesCatalogsAndRevisedMedia() {
        var stop = makeStop()
        stop.imageName = "mill"
        stop.imageURL = URL(string: "https://example.test/mill.jpg")
        stop.illustrationURL = URL(string: "file:///ill.png")
        let fields = ["", stop.id, "mill", "https://example.test/mill.jpg", "file:///ill.png", "false"]
        XCTAssertEqual(stop.renderedImageCacheKey, fields.joined(separator: "\u{1f}"))

        var catalog = stop
        catalog.catalogID = "test-river-walk"
        XCTAssertNotEqual(catalog.renderedImageCacheKey, stop.renderedImageCacheKey)
        XCTAssertTrue(catalog.renderedImageCacheKey.hasPrefix("test-river-walk\u{1f}"))

        var renamed = catalog
        renamed.imageName = "mill-revised"
        var remote = catalog
        remote.imageURL = URL(string: "https://example.test/mill-revised.jpg")
        var drawing = catalog
        drawing.illustrationURL = URL(string: "file:///ill-revised.png")
        var sample = catalog
        sample.isSample = true
        for changed in [renamed, remote, drawing, sample] {
            XCTAssertNotEqual(changed.renderedImageCacheKey, catalog.renderedImageCacheKey)
        }
        XCTAssertFalse(catalog.renderedImageCacheKey.contains("40.6"))
    }
}
