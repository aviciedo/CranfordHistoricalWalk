import XCTest
@testable import TourCore

final class PhotoGalleryIndexTests: XCTestCase {
    func testStoredSelectionCannotPointOutsideTheGallery() {
        XCTAssertEqual(PhotoGalleryIndex.displayed(stored: nil, count: 4), 0)
        XCTAssertEqual(PhotoGalleryIndex.displayed(stored: -3, count: 4), 0)
        XCTAssertEqual(PhotoGalleryIndex.displayed(stored: 99, count: 4), 3)
        XCTAssertEqual(PhotoGalleryIndex.displayed(stored: 2, count: 1), 0)
        XCTAssertEqual(PhotoGalleryIndex.displayed(stored: 2, count: 0), 0)
    }

    func testArrowsWrapWithoutSkippingTheClampedPhoto() {
        XCTAssertEqual(PhotoGalleryIndex.advanced(stored: 0, by: -1, count: 4), 3)
        XCTAssertEqual(PhotoGalleryIndex.advanced(stored: 3, by: 1, count: 4), 0)
        XCTAssertEqual(PhotoGalleryIndex.advanced(stored: 99, by: 1, count: 4), 0,
                       "A stale index past the end advances from the last visible photo")
        XCTAssertEqual(PhotoGalleryIndex.advanced(stored: -8, by: -1, count: 4), 3)
        XCTAssertEqual(PhotoGalleryIndex.advanced(stored: 0, by: 1, count: 1), 0)
        XCTAssertEqual(PhotoGalleryIndex.advanced(stored: 5, by: 1, count: 0), 0)
    }
}
