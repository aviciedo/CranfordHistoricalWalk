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
    func testInkChoiceNeverSubstitutesWatercolorOrTheColorLandmark() {
        let media = StopArtwork(homeInk: "home", listInk: "ink", watercolor: "wash", mapLandmark: "landmark")
        XCTAssertEqual(media.renderedAssetName(usesInk: true), "ink")
        XCTAssertEqual(media.renderedAssetName(usesInk: false), "landmark")
        XCTAssertNil(StopArtwork(listInk: "ink", watercolor: "wash").renderedAssetName(usesInk: false))
        XCTAssertNil(StopArtwork(watercolor: "wash", mapLandmark: "landmark").renderedAssetName(usesInk: true))
        XCTAssertNil(StopArtwork().renderedAssetName(usesInk: true))
        XCTAssertNil(StopArtwork().renderedAssetName(usesInk: false))
        XCTAssertEqual(StopArtwork(listInk: "").renderedAssetName(usesInk: true), "",
                       "An explicit empty name must not fall through to another variant")
    }

    func testRevisedMediaChangesRenderingCacheIdentity() {
        let first = StopArtwork(listInk: "original", mapLandmark: "landmark")
        let second = StopArtwork(listInk: "updated", mapLandmark: "landmark")
        XCTAssertNotEqual(first.cacheKey, second.cacheKey)
        XCTAssertTrue(first.isValid)
    }
}
