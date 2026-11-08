import XCTest
@testable import TourCore

final class AppFooterSizingTests: XCTestCase {
    func testHomeIndicatorGapIsCompactWithoutReachingTheGestureIndicator() {
        XCTAssertEqual(AppFooterSizing.bottomClearance(safeAreaBottom: 34), 16)
        XCTAssertEqual(AppFooterSizing.bottomClearance(safeAreaBottom: 21), 12)
        XCTAssertEqual(AppFooterSizing.bottomClearance(safeAreaBottom: 0), 0)
    }

    func testClearanceNeverConsumesMoreThanTheAvailableBottomInset() {
        for inset in stride(from: 0.0, through: 60.0, by: 1) {
            let clearance = AppFooterSizing.bottomClearance(safeAreaBottom: inset)
            XCTAssertGreaterThanOrEqual(clearance, 0)
            XCTAssertLessThanOrEqual(clearance, inset)
        }
        for invalid in [-1.0, .nan, .infinity] {
            XCTAssertEqual(AppFooterSizing.bottomClearance(safeAreaBottom: invalid), 0)
        }
    }
}
