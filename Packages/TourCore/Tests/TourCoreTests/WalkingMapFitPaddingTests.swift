import XCTest
@testable import TourCore

final class WalkingMapFitPaddingTests: XCTestCase {
    func testTallMapUsesTheDestinationClearanceOnEveryEdge() {
        let tall = WalkingMapFitPadding.insets(mapHeight: 400)
        XCTAssertEqual(tall, WalkingMapFitPadding.preferred)
        XCTAssertEqual(tall.top, 40)
        XCTAssertEqual(tall.left, 40)
        XCTAssertEqual(tall.bottom, 56)
        XCTAssertEqual(tall.right, 96, "The recenter control stays clear of the destination art")
    }

    func testVerticalInsetsShrinkOnlyBelowTheirViewportFraction() {
        let atTop = WalkingMapFitPadding.insets(mapHeight: 200)
        XCTAssertEqual(atTop.top, 40)
        XCTAssertEqual(atTop.bottom, 56)
        XCTAssertEqual(atTop.right, 96)
        let belowTop = WalkingMapFitPadding.insets(mapHeight: 199)
        XCTAssertEqual(belowTop.top, 39.8, accuracy: 0.001)
        XCTAssertLessThan(belowTop.top, 40)
        XCTAssertEqual(belowTop.bottom, 56)

        // 187 * 0.3 is just over 56; 186 * 0.3 is just under.
        let atBottom = WalkingMapFitPadding.insets(mapHeight: 187)
        XCTAssertEqual(atBottom.bottom, 56)
        XCTAssertEqual(atBottom.right, 96)
        let belowBottom = WalkingMapFitPadding.insets(mapHeight: 186)
        XCTAssertEqual(belowBottom.bottom, 55.8, accuracy: 0.001)
        XCTAssertLessThan(belowBottom.bottom, 56)
        XCTAssertEqual(belowBottom.top, 37.2, accuracy: 0.001)
        XCTAssertEqual(belowBottom.left, 40)
        XCTAssertEqual(belowBottom.right, 96)
    }

    func testShortAndEmptyMapsKeepTheHorizontalClearance() {
        for height in [0.0, 1, 50, 100] {
            let insets = WalkingMapFitPadding.insets(mapHeight: height)
            XCTAssertEqual(insets.left, 40)
            XCTAssertEqual(insets.right, 96)
            XCTAssertEqual(insets.top, height * 0.2, accuracy: 0.000_001)
            XCTAssertEqual(insets.bottom, height * 0.3, accuracy: 0.000_001)
        }
    }

    func testNonFiniteHeightKeepsOrPassesTheVerticalFraction() {
        for height in [Double.nan, Double.infinity] {
            let insets = WalkingMapFitPadding.insets(mapHeight: height)
            XCTAssertEqual(insets, WalkingMapFitPadding.preferred)
        }
        let negative = WalkingMapFitPadding.insets(mapHeight: -.infinity)
        XCTAssertEqual(negative.top, -.infinity)
        XCTAssertEqual(negative.bottom, -.infinity)
        XCTAssertEqual(negative.left, 40)
        XCTAssertEqual(negative.right, 96)
    }

    func testNegativeHeightPassesThroughTheVerticalFraction() {
        let insets = WalkingMapFitPadding.insets(mapHeight: -10)
        XCTAssertEqual(insets.top, -2)
        XCTAssertEqual(insets.bottom, -3)
        XCTAssertEqual(insets.left, 40)
        XCTAssertEqual(insets.right, 96)
    }
}
