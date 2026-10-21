import XCTest
@testable import TourCore

final class ArtworkClassificationTests: XCTestCase {
    func testLocalPhotographsStayPhotographsUnlessTheNameIsAPlaceholderOrTheStopIsSample() {
        let mill = ArtworkClassification.localAsset(named: "droeschers-mill", isSample: false)
        XCTAssertEqual(mill.kind, .photograph)
        XCTAssertFalse(mill.isPlaceholder)

        let embeddedWord = ArtworkClassification.localAsset(named: "mill-placeholder-photo", isSample: false)
        XCTAssertEqual(embeddedWord.kind, .photograph)
        XCTAssertFalse(embeddedWord.isPlaceholder, "Only a leading placeholder prefix is a stand-in")

        for name in ["placeholder", "placeholder-mill", "Placeholder-Mill"] {
            let label = ArtworkClassification.localAsset(named: name, isSample: false)
            XCTAssertEqual(label.kind, .photograph, name)
            XCTAssertTrue(label.isPlaceholder, name)
        }

        let sample = ArtworkClassification.localAsset(named: "droeschers-mill", isSample: true)
        XCTAssertEqual(sample.kind, .photograph)
        XCTAssertTrue(sample.isPlaceholder)
    }

    func testPhotoBasedRiverArtworkIsAnIllustrationAndNotAPlaceholder() {
        for name in ["rahway-river-illustration", "Rahway-River-Illustration", "photo-illustration-2"] {
            let label = ArtworkClassification.localAsset(named: name, isSample: false)
            XCTAssertEqual(label.kind, .illustration, name)
            XCTAssertFalse(label.isPlaceholder, name)
        }
        let sampleDrawing = ArtworkClassification.localAsset(named: "rahway-river-illustration", isSample: true)
        XCTAssertEqual(sampleDrawing.kind, .illustration)
        XCTAssertTrue(sampleDrawing.isPlaceholder)
    }

    func testRemoteImagesArePlaceholdersOnlyForSampleStops() {
        let photo = ArtworkClassification.remote(kind: .photograph, isSample: false)
        XCTAssertEqual(photo, ArtworkClassification(kind: .photograph, isPlaceholder: false))
        let samplePhoto = ArtworkClassification.remote(kind: .photograph, isSample: true)
        XCTAssertEqual(samplePhoto, ArtworkClassification(kind: .photograph, isPlaceholder: true))
        let drawing = ArtworkClassification.remote(kind: .illustration, isSample: false)
        XCTAssertEqual(drawing, ArtworkClassification(kind: .illustration, isPlaceholder: false))
    }

    func testDownloadsAcceptOnlyWebAndFileURLsAndSuccessfulHTTPStatuses() {
        XCTAssertTrue(ArtworkClassification.allowsDownload(scheme: "https", isFileURL: false))
        XCTAssertTrue(ArtworkClassification.allowsDownload(scheme: "http", isFileURL: false))
        XCTAssertTrue(ArtworkClassification.allowsDownload(scheme: "file", isFileURL: true))
        XCTAssertTrue(ArtworkClassification.allowsDownload(scheme: nil, isFileURL: true))
        XCTAssertFalse(ArtworkClassification.allowsDownload(scheme: "FILE", isFileURL: false))
        XCTAssertFalse(ArtworkClassification.allowsDownload(scheme: "ftp", isFileURL: false))
        XCTAssertFalse(ArtworkClassification.allowsDownload(scheme: "javascript", isFileURL: false))
        XCTAssertFalse(ArtworkClassification.allowsDownload(scheme: nil, isFileURL: false))

        XCTAssertTrue(ArtworkClassification.acceptsHTTPStatus(200))
        XCTAssertTrue(ArtworkClassification.acceptsHTTPStatus(299))
        XCTAssertFalse(ArtworkClassification.acceptsHTTPStatus(199))
        XCTAssertFalse(ArtworkClassification.acceptsHTTPStatus(300))
        XCTAssertFalse(ArtworkClassification.acceptsHTTPStatus(404))
    }

    func testFailedImageLookupsStaySuppressedUntilTheRetryIntervalElapses() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(ArtworkClassification.failureRetryInterval, 120)
        XCTAssertTrue(ArtworkClassification.shouldSuppressRetry(failedAt: now, now: now))
        XCTAssertTrue(ArtworkClassification.shouldSuppressRetry(failedAt: now.addingTimeInterval(-119.999), now: now))
        XCTAssertFalse(ArtworkClassification.shouldSuppressRetry(failedAt: now.addingTimeInterval(-120), now: now))
        XCTAssertFalse(ArtworkClassification.shouldSuppressRetry(failedAt: now.addingTimeInterval(-121), now: now))
        XCTAssertTrue(ArtworkClassification.shouldSuppressRetry(failedAt: now.addingTimeInterval(5), now: now), "A future failure timestamp is still inside the window")
    }
}
