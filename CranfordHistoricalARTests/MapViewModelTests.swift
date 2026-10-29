import XCTest
import UIKit
import SwiftUI
import CoreLocation
import TourCore
@testable import CranfordHistoricalAR

@MainActor
final class MapViewModelTests: XCTestCase {
    func testRiverHomeAssetsAndSignpostAreAvailableInTheAppBundle() throws {
        var engravedStops = 0
        for stop in HistoricalStop.previewStops {
            guard let asset = HomeStopEmblem.assetName(for: stop.id) else { continue }
            engravedStops += 1
            let image = try XCTUnwrap(UIImage(named: asset), "Missing Home illustration for \(stop.name)")
            XCTAssertEqual(image.size.width, image.size.height, accuracy: 1,
                           "Circular artwork must not be stretched by the Home layout")
        }
        XCTAssertGreaterThanOrEqual(engravedStops, 4)
        for asset in ["home-river-crest-mask", "home-river-bank-mask"] {
            XCTAssertNotNil(UIImage(named: asset), "Missing decorative edge mask")
        }
        XCTAssertNotNil(UIImage(systemName: "signpost.right.and.left.fill"))
    }

    func testRiverHomeKeepsControlsSizedWhenArtworkYieldsSpace() {
        for width in [280.0, 390.0] {
            for height in [320.0, 660.0] {
                let available = CGSize(width: width, height: height)
                let content = HomeLandingLayout(availableSize: available) {
                    Color.clear.frame(height: 140)
                    Color.clear
                    Color.clear.frame(height: 240)
                }
                let host = UIHostingController(rootView: content)
                let measured = host.sizeThatFits(in: available)
                XCTAssertEqual(measured.width, available.width, accuracy: 1)
                XCTAssertGreaterThanOrEqual(measured.height, 140 + 240 + 96,
                    "The header/actions and minimum decorative area must not compress")
                if height == 320 {
                    XCTAssertGreaterThan(measured.height, available.height,
                        "Short windows should scroll instead of clipping controls")
                } else {
                    XCTAssertLessThanOrEqual(measured.height, available.height + 1)
                }
            }
        }
    }

    func testEveryPlaqueStopHasItsSketchAndSketchbookPaperInTheAppBundle() throws {
        let stops = HistoricalStop.previewStops.filter(\.hasPlaqueReference)
        XCTAssertFalse(stops.isEmpty)
        for stop in stops {
            let name = try XCTUnwrap(SketchArtwork.assetName(for: stop.id), stop.name)
            let image = try XCTUnwrap(UIImage(named: name), "Missing sketch for \(stop.name)")
            let cgImage = try XCTUnwrap(image.cgImage)
            XCTAssertFalse([CGImageAlphaInfo.none, .noneSkipFirst, .noneSkipLast].contains(cgImage.alphaInfo),
                           "Watercolor edges must retain transparency")
        }
        XCTAssertNotNil(UIImage(named: "sketchbook-paper"))
    }

    func testLandmarkTextureStaysStableDuringSubpixelCameraUpdates() {
        let icon = StopMapIconView()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 80)).image { context in
            UIColor.systemGreen.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 100, height: 80))
        }
        XCTAssertTrue(icon.setArtwork(image))
        icon.resize(scale: 0.75)
        let initialBounds = icon.bounds
        let initialFrame = icon.imageView.frame
        let displayedImage = icon.imageView.image
        for index in 0..<120 {
            let jitter = index.isMultiple(of: 2) ? 0.00001 : -0.00001
            XCTAssertFalse(icon.resize(scale: 0.75 + jitter),
                           "Subpixel camera changes must reuse the existing texture")
            XCTAssertFalse(icon.setArtwork(image), "The same cached art must not be reassigned")
        }
        XCTAssertEqual(icon.bounds, initialBounds)
        XCTAssertEqual(icon.imageView.frame, initialFrame)
        XCTAssertTrue(icon.imageView.image === displayedImage)
        XCTAssertTrue(icon.resize(scale: 1), "An intentional zoom still resizes the illustration")
        XCTAssertGreaterThan(icon.bounds.width, initialBounds.width)
        icon.resize(scale: 0.1)
        XCTAssertGreaterThanOrEqual(icon.bounds.width, 44)
        XCTAssertGreaterThanOrEqual(icon.bounds.height, 44)
    }

    func testLandmarkReplacementKeepsItsLayoutAndUsesNewArtwork() {
        let icon = StopMapIconView()
        icon.resize(scale: 0.8)
        let first = StopMapArtwork.image(for: StopMarkerModel(id: "hpab-001",
            coordinate: CLLocationCoordinate2D(latitude: 40.65, longitude: -74.3),
            order: 1, name: "Droescher’s Mill", state: .current))
        let next = StopMapArtwork.image(for: StopMarkerModel(id: "hpab-002",
            coordinate: CLLocationCoordinate2D(latitude: 40.66, longitude: -74.3),
            order: 2, name: "Greystone", state: .current))
        icon.setArtwork(first)
        let bounds = icon.bounds
        let firstDisplayed = icon.imageView.image
        XCTAssertTrue(icon.setArtwork(next))
        XCTAssertEqual(icon.bounds, bounds)
        XCTAssertFalse(icon.imageView.image === firstDisplayed)
        XCTAssertNotNil(icon.imageView.image)
        XCTAssertFalse(icon.setArtwork(next))
    }

    func testMapLayoutFitsDestinationWithAndWithoutPlayerSpace() {
        for availableHeight in [420.0, 580.0] {
            let available = CGSize(width: 393, height: availableHeight)
            let content = DestinationFirstMapLayout(availableSize: available) {
                Color.clear
                Color.clear.frame(height: 196)
            }
            let host = UIHostingController(rootView: content)
            let measured = host.sizeThatFits(in: available)
            XCTAssertEqual(measured.height, available.height, accuracy: 1)
        }
    }

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
                let font = UIFont.preferredFont(forTextStyle: .title3, compatibleWith: traits)
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
