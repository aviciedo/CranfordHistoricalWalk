import XCTest
@testable import TourCore

final class MapScreenSizingTests: XCTestCase {
    func testNormalMapViewportIncludesCompleteDestinationWithoutScrolling() {
        let sizes = MapScreenSizing.metrics(availableHeight: 580, destinationHeight: 154)
        XCTAssertEqual(sizes.mapHeight, 394)
        XCTAssertEqual(sizes.contentHeight, 580)
        XCTAssertFalse(sizes.requiresScrolling)
    }

    func testPlayerConsumesSpaceByShrinkingMapInsteadOfHidingActions() {
        let sizes = MapScreenSizing.metrics(availableHeight: 420, destinationHeight: 196)
        XCTAssertEqual(sizes.mapHeight, 192)
        XCTAssertEqual(sizes.destinationHeight, 196)
        XCTAssertLessThan(sizes.mapHeight, MapScreenSizing.compactControlsThreshold)
        XCTAssertEqual(sizes.contentHeight, 420)
        XCTAssertFalse(sizes.requiresScrolling)
    }

    func testLoadingOrWrappingTextReceivesItsMeasuredHeightInSamePass() {
        let before = MapScreenSizing.metrics(availableHeight: 580, destinationHeight: 154)
        let after = MapScreenSizing.metrics(availableHeight: 580, destinationHeight: 214)
        XCTAssertEqual(after.destinationHeight - before.destinationHeight, 60)
        XCTAssertEqual(before.mapHeight - after.mapHeight, 60)
        XCTAssertFalse(after.requiresScrolling)
    }

    func testMapDoesNotGrowToFillLargeScreensAtExpenseOfPageHierarchy() {
        let sizes = MapScreenSizing.metrics(availableHeight: 900, destinationHeight: 160)
        XCTAssertEqual(sizes.mapHeight, MapScreenSizing.maximumMapHeight)
        XCTAssertLessThan(sizes.contentHeight, 900)
    }

    func testAccessibilityOverflowRemainsScrollableWithoutCompressingText() {
        let sizes = MapScreenSizing.metrics(availableHeight: 360, destinationHeight: 320)
        XCTAssertEqual(sizes.mapHeight, MapScreenSizing.minimumMapHeight)
        XCTAssertEqual(sizes.destinationHeight, 320)
        XCTAssertTrue(sizes.requiresScrolling)
    }

    func testNoDestinationDoesNotReserveAnEmptySectionGap() {
        let sizes = MapScreenSizing.metrics(availableHeight: 600, destinationHeight: 0)
        XCTAssertEqual(sizes.gap, 0)
        XCTAssertEqual(sizes.contentHeight, sizes.mapHeight + MapScreenSizing.bottomSpacing)
        XCTAssertFalse(sizes.requiresScrolling)
    }

    func testAllFittingViewportAndPanelCombinationsKeepActionsOnScreen() {
        for available in stride(from: 320.0, through: 850.0, by: 10) {
            for panel in stride(from: 80.0, through: 320.0, by: 8) {
                let sizes = MapScreenSizing.metrics(availableHeight: available, destinationHeight: panel)
                XCTAssertEqual(sizes.destinationHeight, panel)
                XCTAssertGreaterThanOrEqual(sizes.mapHeight, MapScreenSizing.minimumMapHeight)
                XCTAssertLessThanOrEqual(sizes.mapHeight, MapScreenSizing.maximumMapHeight)
                if MapScreenSizing.minimumMapHeight + panel + MapScreenSizing.sectionSpacing
                    + MapScreenSizing.bottomSpacing <= available {
                    XCTAssertFalse(sizes.requiresScrolling)
                    XCTAssertLessThanOrEqual(sizes.contentHeight, available + 0.001)
                }
            }
        }
    }

    func testInitialZeroSizeAndInvalidMeasurementsRemainFinite() {
        for height in [0.0, -1, .nan, .infinity] {
            let sizes = MapScreenSizing.metrics(availableHeight: height, destinationHeight: 200)
            XCTAssertEqual(sizes.contentHeight, 0)
            XCTAssertFalse(sizes.requiresScrolling)
        }
        for panel in [-1.0, .nan, .infinity] {
            let sizes = MapScreenSizing.metrics(availableHeight: 500, destinationHeight: panel)
            XCTAssertTrue(sizes.contentHeight.isFinite)
            XCTAssertEqual(sizes.destinationHeight, 0)
        }
    }
}
