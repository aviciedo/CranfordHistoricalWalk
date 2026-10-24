import XCTest
@testable import TourCore

final class TourCatalogTests: XCTestCase {
    func testLegacyDocumentAndWalkRemainCompatibleOnlyWithLegacyTour() throws {
        let document = try HistoricalStopDecoder.decode(Fixtures.data("sample_historical_stops"))
        XCTAssertEqual(document.identity, .legacy)
        var progress = TourProgress(stopIDs: document.stops.map(\.id)); progress.start()
        let record = WalkResumeRecord(progress: progress)
        XCTAssertTrue(record.isValid(for: .legacy, stopIDs: progress.stopIDs))
        XCTAssertFalse(record.isValid(for: .init(tourID: "other"), stopIDs: progress.stopIDs))
    }
    func testResumeRequiresMatchingCatalogAndPreservesSessionUUID() throws {
        var progress = TourProgress(stopIDs: ["a", "b"]); progress.start(); progress.advanceCurrentStop()
        let identity = TourCatalogIdentity(tourID: "another-tour", version: 2)
        let session = UUID()
        let record = WalkResumeRecord(progress: progress, catalogIdentity: identity, sessionID: session)
        let restored = try JSONDecoder().decode(WalkResumeRecord.self, from: JSONEncoder().encode(record))
        XCTAssertEqual(restored.sessionID, session)
        XCTAssertTrue(restored.isValid(for: identity, stopIDs: progress.stopIDs))
        XCTAssertFalse(restored.isValid(for: .init(tourID: identity.tourID, version: 3), stopIDs: progress.stopIDs))
        XCTAssertFalse(restored.isValid(for: .legacy, stopIDs: progress.stopIDs))
    }
    func testNamespacesRetainActivitiesAcrossRevisionsButSeparateWalksAndTours() {
        let v1 = TourCatalogIdentity(tourID: "tour-a", version: 1)
        let v2 = TourCatalogIdentity(tourID: "tour-a", version: 2)
        XCTAssertEqual(v1.storageKey("activities"), v2.storageKey("activities"))
        XCTAssertNotEqual(v1.storageKey("walk", perRevision: true), v2.storageKey("walk", perRevision: true))
        XCTAssertNotEqual(v1.storageKey("activities"), TourCatalogIdentity(tourID: "tour-b").storageKey("activities"))
        XCTAssertEqual(TourCatalogIdentity.legacy.storageKey("cranford.walk-resume.v1", perRevision: true), "cranford.walk-resume.v1")
    }
    func testCatalogAcceptsSecondTourAndRejectsIdentifierCollisions() throws {
        let a = HistoricalTourDocument(tourName: "A", stops: [makeStop(id: "a")], tourID: "a")
        var b = HistoricalTourDocument(tourName: "B", stops: [makeStop(id: "b")], tourID: "b")
        XCTAssertEqual(try TourCatalog(tours: [a,b]).tours.count, 2)
        b.stops[0].id = "a"
        XCTAssertThrowsError(try TourCatalog(tours: [a,b]))
        XCTAssertThrowsError(try TourCatalog(tours: [a,a]))
        XCTAssertThrowsError(try TourCatalog(tours: []))
    }
    func testInvalidMetadataAndManifestAreRejected() throws {
        var document = HistoricalTourDocument(tourName: "A", stops: [makeStop(id: "a")], tourID: " ")
        XCTAssertThrowsError(try HistoricalStopDecoder.decode(JSONEncoder().encode(document)))
        document.tourID = "a"
        document.recordings = [.init(stopID: "a", fileName: "../other.mp3", duration: 12,
            audioSHA256: String(repeating: "a", count: 64), transcriptSHA256: String(repeating: "b", count: 64))]
        XCTAssertThrowsError(try HistoricalStopDecoder.decode(JSONEncoder().encode(document)))
        document.recordings = nil
        XCTAssertNoThrow(try HistoricalStopDecoder.decode(JSONEncoder().encode(document)))
    }
}
