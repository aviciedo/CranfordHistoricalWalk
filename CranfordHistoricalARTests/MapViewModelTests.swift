import XCTest
@testable import CranfordHistoricalAR

@MainActor
final class MapViewModelTests: XCTestCase {
    func testToggleSelectionSelectsAndDismisses() {
        let model = MapViewModel()
        XCTAssertNil(model.selectedStopID)
        model.toggleSelection(stopID: "hpab-001")
        XCTAssertEqual(model.selectedStopID, "hpab-001")
        model.toggleSelection(stopID: "hpab-002")
        XCTAssertEqual(model.selectedStopID, "hpab-002")
        model.toggleSelection(stopID: "hpab-002")
        XCTAssertNil(model.selectedStopID)
        model.select(stopID: "hpab-003")
        model.select(stopID: nil)
        XCTAssertNil(model.selectedStopID)
    }

    func testOverviewStyleNumbersWhenZoomedIn() {
        let model = MapViewModel()
        XCTAssertEqual(model.overviewMarkerStyle, .dot, "until the map reports zoom, keep unnumbered dots")
        model.cameraDidSettle(zoom: MapViewModel.numberedDotZoom)
        XCTAssertEqual(model.overviewMarkerStyle, .numberedDot)
        model.cameraDidSettle(zoom: MapViewModel.numberedDotZoom - 0.5)
        XCTAssertEqual(model.overviewMarkerStyle, .dot)
    }
}
