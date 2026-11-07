import XCTest
@testable import TourCore

final class SketchbookPagingTests: XCTestCase {
    func testNegativePageIndexClampsToFirstPage() {
        XCTAssertEqual(SketchbookPageIndex.clamped(-1, pageCount: 2), 0)
    }

    func testInitialPageFollowsStopIdentityRatherThanCatalogPosition() {
        let pages = ["future-stop", "hpab-002", "hpab-001"]
        for (expected, id) in pages.enumerated() {
            XCTAssertEqual(SketchbookPageIndex.initial(stopID: id, pageStopIDs: pages), expected)
        }
        XCTAssertEqual(SketchbookPageIndex.initial(stopID: "hpab-001", pageStopIDs: ["hpab-001", "hpab-002"]), 0)
        XCTAssertEqual(SketchbookPageIndex.initial(stopID: "hpab-002", pageStopIDs: ["hpab-001", "hpab-002"]), 1)
    }

    func testDuplicateStopUsesTheFirstPageAndNearMissesOpenTheFront() {
        let pages = ["hpab-001", "hpab-001", "hpab-002"]
        XCTAssertEqual(SketchbookPageIndex.initial(stopID: "hpab-001", pageStopIDs: pages), 0)
        XCTAssertEqual(SketchbookPageIndex.initial(stopID: "missing", pageStopIDs: pages), 0)
        XCTAssertEqual(SketchbookPageIndex.initial(stopID: "hpab-001", pageStopIDs: []), 0)
        XCTAssertEqual(SketchbookPageIndex.initial(stopID: "", pageStopIDs: pages), 0)
        XCTAssertEqual(SketchbookPageIndex.initial(stopID: "hpab-00", pageStopIDs: pages), 0)
        XCTAssertEqual(SketchbookPageIndex.initial(stopID: "hpab-001 ", pageStopIDs: pages), 0)
        XCTAssertEqual(SketchbookPageIndex.initial(stopID: "", pageStopIDs: ["", "hpab-001"]), 0)
    }

    func testStoredIndexClampsWhenTheCatalogShrinks() {
        XCTAssertEqual(SketchbookPageIndex.clamped(0, pageCount: 3), 0)
        XCTAssertEqual(SketchbookPageIndex.clamped(2, pageCount: 3), 2)
        XCTAssertEqual(SketchbookPageIndex.clamped(3, pageCount: 3), 2)
        XCTAssertEqual(SketchbookPageIndex.clamped(5, pageCount: 1), 0)
        XCTAssertEqual(SketchbookPageIndex.clamped(4, pageCount: 0), 0)
    }

    func testCurlFrontIsOneControllerAndTheBackStaysOnThatPage() {
        for page in 0..<6 {
            let front = SketchbookCurlLayout.frontControllerIndex(logicalPage: page)
            XCTAssertEqual(front, page * 2)
            XCTAssertEqual(SketchbookCurlLayout.logicalPage(controllerIndex: front), page)
            XCTAssertEqual(SketchbookCurlLayout.logicalPage(controllerIndex: front + 1), page,
                           "The parchment back must not become the next sketch")
        }
        XCTAssertEqual(SketchbookCurlLayout.logicalPage(controllerIndex: 1), 0)
        XCTAssertEqual(SketchbookCurlLayout.logicalPage(controllerIndex: 2), 1)
    }

    func testFrontPaperKeepsTheGutterAndClipsOnlyTheTrailingPaleMargin() throws {
        let frame = SketchbookPaperFraming.sourceFrame(viewportWidth: 200, viewportHeight: 400)
        let source = try XCTUnwrap(frame)
        XCTAssertEqual(source.x, 0, "The cloth gutter is on the leading edge and must not be shifted off")
        XCTAssertEqual(source.y, 0)
        XCTAssertEqual((source.width - 200) / source.width, 0.015, accuracy: 0.0000001)
        XCTAssertEqual((source.height - 400) / source.height, 0.008, accuracy: 0.0000001)
        XCTAssertLessThan((source.width - 200) / source.width, 0.02,
                          "The retired interior crop hid the gutter behind a much larger margin")
        XCTAssertGreaterThan(source.x + source.width, 200)
        XCTAssertGreaterThan(source.y + source.height, 400)
        XCTAssertNil(SketchbookPaperFraming.sourceFrame(viewportWidth: 0, viewportHeight: 400))
        XCTAssertNil(SketchbookPaperFraming.sourceFrame(viewportWidth: -8, viewportHeight: 40))
        XCTAssertNil(SketchbookPaperFraming.sourceFrame(viewportWidth: .nan, viewportHeight: 40))
        XCTAssertNil(SketchbookPaperFraming.sourceFrame(viewportWidth: 40, viewportHeight: .infinity))
    }
}
