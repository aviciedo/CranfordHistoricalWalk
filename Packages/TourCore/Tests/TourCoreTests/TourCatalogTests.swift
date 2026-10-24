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

    func testLegacyRevisionKeepsVisitHistoryAndRefusesTheOldWalk() {
        let revised = TourCatalogIdentity(tourID: TourCatalogIdentity.legacy.tourID, version: 2)
        XCTAssertEqual(revised.storageKey("cranford.stop-visits.v1"), "cranford.stop-visits.v1")
        XCTAssertEqual(revised.storageKey("cranford.stop-activities.v1"), "cranford.stop-activities.v1")
        XCTAssertNotEqual(revised.storageKey("cranford.walk-resume.v1", perRevision: true), "cranford.walk-resume.v1")
        var progress = TourProgress(stopIDs: ["hpab-001"])
        progress.start()
        let savedBeforeIdentifiers = WalkResumeRecord(progress: progress)
        XCTAssertFalse(savedBeforeIdentifiers.isValid(for: revised, stopIDs: progress.stopIDs))
        XCTAssertFalse(savedBeforeIdentifiers.isValid(for: .init(tourID: TourCatalogIdentity.legacy.tourID, version: 0), stopIDs: progress.stopIDs))
    }

    func testShippedCatalogKeepsLegacyIdentityAndValidRecordings() throws {
        let document = try HistoricalStopDecoder.decode(Fixtures.data("historical_stops"))
        XCTAssertEqual(document.identity, .legacy)
        XCTAssertEqual(document.tourID, "cranford-historical-walk")
        XCTAssertEqual(document.catalogVersion, 1)
        XCTAssertTrue(document.stops.allSatisfy { $0.catalogID == nil })
        let recordings = try XCTUnwrap(document.recordings)
        XCTAssertEqual(recordings.map(\.stopID), ["hpab-001", "hpab-002"])
        XCTAssertEqual(recordings.map(\.fileName), ["stop_01_droeschers_mill.mp3", "stop_02_greystone.mp3"])
        XCTAssertTrue(recordings.allSatisfy(\.isValid))
    }

    func testOtherTourStampsItsIdentityAndRejectsABadManifest() throws {
        var document = HistoricalTourDocument(tourName: "A", stops: [makeStop(id: "a")], tourID: "other-tour", catalogVersion: 2)
        let hash = String(repeating: "ab", count: 32)
        document.recordings = [.init(stopID: "a", fileName: "story.mp3", duration: 12, audioSHA256: hash, transcriptSHA256: hash)]
        let decoded = try HistoricalStopDecoder.decode(JSONEncoder().encode(document))
        XCTAssertEqual(decoded.stops.map(\.catalogID), ["other-tour"])
        XCTAssertEqual(decoded.recordings?.count, 1)

        document.schemaVersion = 2
        XCTAssertThrowsError(try HistoricalStopDecoder.decode(JSONEncoder().encode(document)))
        document.schemaVersion = 1
        document.catalogVersion = 0
        XCTAssertThrowsError(try HistoricalStopDecoder.decode(JSONEncoder().encode(document)))
        document.catalogVersion = -1
        XCTAssertThrowsError(try HistoricalStopDecoder.decode(JSONEncoder().encode(document)))
        document.catalogVersion = 2

        let uppercase = String(repeating: "A", count: 64)
        let shortHash = String(repeating: "a", count: 63)
        let rejected: [TourRecording] = [
            .init(stopID: "missing", fileName: "story.mp3", duration: 12, audioSHA256: hash, transcriptSHA256: hash),
            .init(stopID: "a", fileName: ".", duration: 12, audioSHA256: hash, transcriptSHA256: hash),
            .init(stopID: "a", fileName: "..", duration: 12, audioSHA256: hash, transcriptSHA256: hash),
            .init(stopID: "a", fileName: "a\\b.mp3", duration: 12, audioSHA256: hash, transcriptSHA256: hash),
            .init(stopID: "a", fileName: "", duration: 12, audioSHA256: hash, transcriptSHA256: hash),
            .init(stopID: "", fileName: "story.mp3", duration: 12, audioSHA256: hash, transcriptSHA256: hash),
            .init(stopID: "a", fileName: "story.mp3", duration: 0, audioSHA256: hash, transcriptSHA256: hash),
            .init(stopID: "a", fileName: "story.mp3", duration: -1, audioSHA256: hash, transcriptSHA256: hash),
            .init(stopID: "a", fileName: "story.mp3", duration: 12, audioSHA256: uppercase, transcriptSHA256: hash),
            .init(stopID: "a", fileName: "story.mp3", duration: 12, audioSHA256: hash, transcriptSHA256: shortHash),
        ]
        for recording in rejected {
            document.recordings = [recording]
            XCTAssertThrowsError(try HistoricalStopDecoder.decode(JSONEncoder().encode(document)))
        }
        XCTAssertFalse(TourRecording(stopID: "a", fileName: "story.mp3", duration: .nan, audioSHA256: hash, transcriptSHA256: hash).isValid)
        XCTAssertFalse(TourRecording(stopID: "a", fileName: "story.mp3", duration: .infinity, audioSHA256: hash, transcriptSHA256: hash).isValid)
        document.recordings = [
            .init(stopID: "a", fileName: "one.mp3", duration: 12, audioSHA256: hash, transcriptSHA256: hash),
            .init(stopID: "a", fileName: "two.mp3", duration: 12, audioSHA256: hash, transcriptSHA256: hash),
        ]
        XCTAssertThrowsError(try HistoricalStopDecoder.decode(JSONEncoder().encode(document)))

        let sameTourNextRevision = HistoricalTourDocument(tourName: "A2", stops: [makeStop(id: "b")], tourID: "other-tour", catalogVersion: 3)
        XCTAssertThrowsError(try TourCatalog(tours: [
            HistoricalTourDocument(tourName: "A", stops: [makeStop(id: "a")], tourID: "other-tour"),
            sameTourNextRevision,
        ]))
    }
}
