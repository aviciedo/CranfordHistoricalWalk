import XCTest
import UIKit
import SwiftUI
import CoreLocation
import TourCore
@testable import CranfordHistoricalAR

@MainActor
final class MapViewModelTests: XCTestCase {
    func testMapStatusReservesDistanceAndLoadingTextHeight() {
        let tour = AppDependencies.preview().tourViewModel
        let sizes: [(DynamicTypeSize, UIContentSizeCategory)] = [
            (.large, .large), (.accessibility5, .accessibilityExtraExtraExtraLarge)
        ]
        for width in [280.0, 350.0] {
            for (dynamicType, category) in sizes {
                tour.isRoutingInFlight = false
                let status = MapDestinationStatus().environment(tour)
                    .environment(\.dynamicTypeSize, dynamicType)
                let host = UIHostingController(rootView: status)
                let proposal = CGSize(width: width, height: 1)
                let measured = host.sizeThatFits(in: proposal)
                let traits = UITraitCollection(preferredContentSizeCategory: category)
                let font = UIFont.preferredFont(forTextStyle: .subheadline, compatibleWith: traits)
                XCTAssertGreaterThanOrEqual(measured.height, font.lineHeight - 1,
                    "Distance/time text must retain its full line height in a short map panel")

                tour.isRoutingInFlight = true
                let loading = UIHostingController(rootView: MapDestinationStatus().environment(tour)
                    .environment(\.dynamicTypeSize, dynamicType))
                XCTAssertGreaterThan(loading.sizeThatFits(in: proposal).height, measured.height,
                    "The route-loading message needs its own space beneath distance/time")
            }
        }
    }

    func testMapPopupCloseIsAnInteractiveControl() throws {
        var dismissed = false
        let popup = StopNameInfoWindow(title: "Greystone", details: "Stop details", width: 280, maximumHeight: 300) {
            dismissed = true
        }
        let close = try XCTUnwrap(popup.subviews.compactMap { $0 as? UIButton }.first)
        XCTAssertEqual(close.accessibilityIdentifier, "map.popup.close")
        XCTAssertGreaterThanOrEqual(close.bounds.width, 44)
        close.sendActions(for: .touchUpInside)
        XCTAssertTrue(dismissed)
    }

    func testRerouteWithSameEndpointsAndMidpointChangesTheMapPath() {
        let original = (0..<5).map { CLLocationCoordinate2D(latitude: 40, longitude: Double($0)) }
        var rerouted = original
        rerouted[1].latitude += 0.001
        XCTAssertFalse(GoogleMapView.Coordinator.routesMatch(original, rerouted))
        XCTAssertTrue(GoogleMapView.Coordinator.routesMatch(original, original))
        XCTAssertFalse(GoogleMapView.Coordinator.routesMatch(original, []))
        XCTAssertTrue(GoogleMapView.Coordinator.routesMatch([], []))
    }

    func testIllustratedMapClampsZoomAndPan() {
        let size = CGSize(width: 300, height: 200)
        let overview = IllustratedMapTransform(scale: 0.5, offset: CGSize(width: 100, height: -100), size: size)
        XCTAssertEqual(overview.scale, 1)
        XCTAssertEqual(overview.offset, .zero)

        let zoomed = IllustratedMapTransform(scale: 8, offset: CGSize(width: 900, height: -900), size: size)
        XCTAssertEqual(zoomed.scale, 4)
        XCTAssertEqual(zoomed.offset, CGSize(width: 450, height: -300))
    }

    func testIllustratedMarkersFollowTheDrawingTransform() {
        let size = CGSize(width: 300, height: 200)
        let transform = IllustratedMapTransform(scale: 2, offset: CGSize(width: 20, height: -10), size: size)
        XCTAssertEqual(transform.project(CGPoint(x: 150, y: 100), in: size), CGPoint(x: 170, y: 90))
        XCTAssertEqual(transform.project(CGPoint(x: 100, y: 75), in: size), CGPoint(x: 70, y: 40))
    }

    func testIllustratedProjectionCentersASingleStopAndPreservesNorth() {
        let size = CGSize(width: 300, height: 300)
        let south = GeoCoordinate(latitude: 40.65, longitude: -74.30)
        let north = GeoCoordinate(latitude: 40.66, longitude: -74.30)
        XCTAssertEqual(IllustratedMapProjection.point(for: south, among: [south], size: size), CGPoint(x: 150, y: 150))
        let top = IllustratedMapProjection.point(for: north, among: [south, north], size: size)
        let bottom = IllustratedMapProjection.point(for: south, among: [south, north], size: size)
        XCTAssertLessThan(top.y, bottom.y)
        XCTAssertEqual(top.x, bottom.x)
    }

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
