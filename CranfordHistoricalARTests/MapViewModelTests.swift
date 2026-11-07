import XCTest
import UIKit
import SwiftUI
import CoreLocation
import TourCore
@testable import CranfordHistoricalAR

@MainActor
final class MapViewModelTests: XCTestCase {
    func testIllustrationOverlayKeepsBadgeTargetsClearAndUsesApprovedSizes() {
        let models = HistoricalStop.previewStops.enumerated().map { index, stop in
            StopMarkerModel(id: stop.id, coordinate: stop.clLocationCoordinate,
                order: stop.order, name: stop.name, state: .upcoming, isTourDestination: index == 0)
        }
        let map = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 620))
        let overlay = StopMapLeaderView()
        let points: [SIMD2<Double>] = [[190, 490], [230, 390], [55, 80], [190, 270], [110, 180]]
        var state = MapMarkerSizing.State()
        let layout = state.layout(ids: models.map(\.id), points: points, metersPerPoint: 4,
            viewport: map.bounds.insetBy(dx: 10, dy: 10), activeIndices: [0])
        overlay.update(layout, models: models, in: map)
        let buttons = overlay.subviews.compactMap { $0 as? UIButton }
        XCTAssertFalse(overlay.isUserInteractionEnabled, "Artwork must never intercept the SDK's pan/pinch/rotation")
        XCTAssertEqual(map.gestureRecognizers?.count, 1)
        XCTAssertEqual(map.gestureRecognizers?.first?.cancelsTouchesInView, false)
        XCTAssertEqual(buttons.count, 5)
        XCTAssertEqual(buttons.filter { abs($0.bounds.width - 96) < 0.01 }.count, 1)
        XCTAssertEqual(buttons.filter { abs($0.bounds.width - 64) < 0.01 }.count, 4)
        for point in points {
            XCTAssertNil(overlay.hitTest(CGPoint(x: point.x, y: point.y), with: nil), "Native number badge keeps its tap")
        }
        XCTAssertNil(overlay.hitTest(CGPoint(x: 389, y: 619), with: nil), "Empty overlay never steals the map")
        var tapped: String?
        overlay.onTap = { tapped = $0 }
        buttons.first { $0.accessibilityIdentifier == "map.artwork.\(models[0].id)" }?.sendActions(for: .touchUpInside)
        XCTAssertEqual(tapped, models[0].id)
        overlay.update(layout, models: Array(models.prefix(1)), in: map)
        XCTAssertEqual(overlay.subviews.compactMap { $0 as? UIButton }.count, 1)
    }

    func testArtworkMaskClipsAtTheSameViewportAsVisibilityEvenForEdgePins() throws {
        let stop = HistoricalStop.previewStops[0]
        let model = StopMarkerModel(id: stop.id, coordinate: stop.clLocationCoordinate,
            order: stop.order, name: stop.name, state: .current, isTourDestination: true)
        let map = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 300))
        let viewport = CGRect(x: 10, y: 10, width: 370, height: 210)
        let overlay = StopMapLeaderView()
        var state = MapMarkerSizing.State()
        _ = state.layout(ids: [model.id], points: [[150, 175]], metersPerPoint: 200,
            viewport: viewport, activeIndices: [0])
        for pinY in [230.0, 255.0] {
            let layout = state.layout(ids: [model.id], points: [SIMD2(150, pinY)], metersPerPoint: 200,
                viewport: viewport, activeIndices: [0], isMoving: true)
            overlay.update(layout, models: [model], in: map)
            XCTAssertTrue(layout.placements[0].isVisible)
            let mask = try XCTUnwrap(overlay.layer.mask as? CAShapeLayer)
            let path = try XCTUnwrap(mask.path)
            XCTAssertTrue(viewport.contains(path.boundingBoxOfPath), "Badge cutouts must not extend the artwork mask outside its clip")
            XCTAssertFalse(path.contains(CGPoint(x: 150, y: 235), using: .evenOdd))
            XCTAssertFalse(path.contains(CGPoint(x: 5, y: 100), using: .evenOdd))
            XCTAssertTrue(path.contains(CGPoint(x: 50, y: 100), using: .evenOdd))
            if pinY == 255 {
                let hiddenPoint = CGPoint(x: 150, y: 225)
                let art = try XCTUnwrap(overlay.subviews.first { $0 is UIButton })
                XCTAssertTrue(art.frame.contains(hiddenPoint), "Exercise the clipped part of the illustration")
                XCTAssertNil(overlay.artworkID(at: hiddenPoint), "Clipped artwork must not react to taps")
                XCTAssertEqual(overlay.artworkID(at: art.center), model.id)
            }
        }
    }

    func testUpdatedCatalogImageDoesNotReuseAnOldStopThumbnail() async throws {
        let loader = CompositeImageLoader()
        var stop = HistoricalStop.previewStops[0]
        stop.imageName = "droeschers-mill"
        let original = await loader.image(for: stop)
        XCTAssertNotNil(original)
        stop.imageName = "greystone"
        XCTAssertNil(loader.cachedImage(for: stop), "Resource identity, not only stop ID, keys the cache")
        let updated = await loader.image(for: stop)
        XCTAssertNotNil(updated)
        XCTAssertFalse(original?.image === updated?.image)
    }

    func testNewCatalogStopUsesSuppliedArtworkWithoutStopIDSwitches() throws {
        let media = StopArtwork(homeInk: "home-sketch-mill", listInk: "stop-ink-mill",
            watercolor: "sketchbook-mill", mapLandmark: "mill-map-landmark")
        let id = "another-tour-new-stop"
        XCTAssertEqual(HomeStopEmblem.assetName(for: id, artwork: media), media.homeInk)
        XCTAssertEqual(SketchArtwork.assetName(for: id, artwork: media), media.watercolor)
        XCTAssertEqual(StopCollectionIllustration.assetName(for: id, isSketchUnlocked: false, artwork: media), media.listInk)
        XCTAssertEqual(StopCollectionIllustration.assetName(for: id, isSketchUnlocked: true, artwork: media), media.listInk)
        for name in media.assetNames { XCTAssertNotNil(UIImage(named: name)) }
        for stop in try XCTUnwrap(BundledStopArtwork.document).stops {
            for name in stop.artwork?.assetNames ?? [] {
                XCTAssertNotNil(UIImage(named: name), "Catalog references missing resource \(name)")
            }
        }
    }

    func testSketchbookOpensRequestedStopRegardlessOfPageOrderOrFutureStops() {
        let ids = ["future-stop", "hpab-002", "hpab-001"]
        for (expected, id) in ids.enumerated() {
            XCTAssertEqual(SketchbookView.initialPageIndex(stopID: id, pageStopIDs: ids), expected)
        }
        XCTAssertEqual(SketchbookView.initialPageIndex(stopID: "missing", pageStopIDs: ids), 0)
        XCTAssertEqual(SketchbookView.initialPageIndex(stopID: "hpab-001", pageStopIDs: []), 0)
    }

    func testSketchbookCurlInitiallyShowsRequestedLogicalPage() {
        let selected = SketchbookView.initialPageIndex(stopID: "hpab-002", pageStopIDs: ["hpab-001", "hpab-002"])
        let curl = SketchbookPageCurl(pages: [AnyView(Text("Mill")), AnyView(Text("Greystone"))],
            index: .constant(selected), enabled: true)
        let coordinator = curl.makeCoordinator()
        let controller = SketchbookPageCurl.makePageController()
        coordinator.configure(controller)
        XCTAssertEqual(coordinator.displayedIndex, 1)
        XCTAssertTrue(controller.viewControllers?.first === coordinator.controllers[2])
    }

    func testSketchbookOpeningEveryPageUsesOneVisibleController() throws {
        // Includes a single-stop book and future books larger than the current two stops.
        for count in [1, 2, 6] {
            for initial in 0..<count {
                let pages = (0..<count).map { AnyView(Text("Sketch \($0)")) }
                let curl = SketchbookPageCurl(pages: pages, index: .constant(initial), enabled: true)
                let coordinator = curl.makeCoordinator()
                let controller = SketchbookPageCurl.makePageController()
                coordinator.configure(controller)
                let visible = try XCTUnwrap(controller.viewControllers)
                XCTAssertEqual(visible.count, 1, "Nonanimated minimum-spine opening requires one front")
                XCTAssertTrue(visible.first === coordinator.controllers[initial * 2])
                // SwiftUI refreshes must preserve the requested page without invalidating the curl.
                coordinator.configure(controller)
                XCTAssertTrue(controller.viewControllers?.first === visible.first)
                XCTAssertEqual(coordinator.displayedIndex, initial)
            }
        }
    }

    func testSketchbookCurlUsesOpaqueParchmentForContainerAndBothFaces() throws {
        let curl = SketchbookPageCurl(pages: [AnyView(Text("Mill")), AnyView(Text("Greystone"))],
            index: .constant(0), enabled: true)
        let coordinator = curl.makeCoordinator()
        let controller = SketchbookPageCurl.makePageController()
        coordinator.configure(controller)
        XCTAssertTrue(controller.view.clipsToBounds, "A turning sheet must not expose backing above the book")
        for surface in [controller.view!] + coordinator.controllers.map({ $0.view! }) {
            XCTAssertTrue(surface.isOpaque)
            let color = try XCTUnwrap(surface.backgroundColor)
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            XCTAssertTrue(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
            XCTAssertEqual(red, 248 / 255.0, accuracy: 0.005)
            XCTAssertEqual(green, 242 / 255.0, accuracy: 0.005)
            XCTAssertEqual(blue, 230 / 255.0, accuracy: 0.005)
            XCTAssertEqual(alpha, 1)
        }
        // Preserve one-front opening while retaining two physical faces per logical page.
        XCTAssertEqual(controller.viewControllers?.count, 1)
        XCTAssertEqual(coordinator.controllers.count, 4)
        coordinator.configure(controller)
        XCTAssertEqual(controller.viewControllers?.count, 1)
    }

    func testSketchbookCurlUsesPaperBacksWithoutAddingLogicalPages() throws {
        var selected = 0
        let curl = SketchbookPageCurl(pages: [AnyView(Text("Mill")), AnyView(Text("Greystone"))],
            index: Binding(get: { selected }, set: { selected = $0 }), enabled: true)
        let coordinator = curl.makeCoordinator()
        let controller = SketchbookPageCurl.makePageController()
        coordinator.configure(controller)
        XCTAssertTrue(controller.isDoubleSided)
        let first = try XCTUnwrap(controller.viewControllers)
        XCTAssertEqual(first.count, 1, "Opening uses one front; animated turns also supply its back")
        let firstBack = try XCTUnwrap(coordinator.pageViewController(controller, viewControllerAfter: first[0]))
        XCTAssertTrue(firstBack.view.accessibilityElementsHidden)
        XCTAssertNil(coordinator.pageViewController(controller, viewControllerBefore: first[0]))
        let nextFront = try XCTUnwrap(coordinator.pageViewController(controller, viewControllerAfter: firstBack))
        let nextBack = try XCTUnwrap(coordinator.pageViewController(controller, viewControllerAfter: nextFront))
        XCTAssertNil(coordinator.pageViewController(controller, viewControllerAfter: nextBack))
        controller.setViewControllers([nextFront], direction: .forward, animated: false)
        coordinator.pageViewController(controller, didFinishAnimating: true,
                                       previousViewControllers: first, transitionCompleted: true)
        XCTAssertEqual(selected, 1, "The paper back must not become another sketchbook page")
        let previousBack = try XCTUnwrap(coordinator.pageViewController(controller, viewControllerBefore: nextFront))
        let previousFront = try XCTUnwrap(coordinator.pageViewController(controller, viewControllerBefore: previousBack))
        XCTAssertTrue(previousBack === firstBack)
        XCTAssertTrue(previousFront === first[0])
        controller.setViewControllers(first, direction: .reverse, animated: false)
        coordinator.pageViewController(controller, didFinishAnimating: true,
                                       previousViewControllers: [nextFront], transitionCompleted: true)
        XCTAssertEqual(selected, 0)
        coordinator.pageViewController(controller, didFinishAnimating: false,
                                       previousViewControllers: first, transitionCompleted: false)
        XCTAssertEqual(selected, 0, "A cancelled curl must not change the logical page")
    }

    func testSketchbookAnimatedArrowsCanReturnFromGreystoneRepeatedly() throws {
        var selected = 0
        let curl = SketchbookPageCurl(pages: [AnyView(Text("Mill")), AnyView(Text("Greystone")), AnyView(Text("Future stop"))],
            index: Binding(get: { selected }, set: { selected = $0 }), enabled: true)
        let coordinator = curl.makeCoordinator()
        let controller = SketchbookPageCurl.makePageController()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let originalKey = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = controller
        coordinator.configure(controller)
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; originalKey?.makeKey() }
        window.layoutIfNeeded()
        controller.view.layoutIfNeeded()
        for target in [1, 0, 1, 2, 1, 0] {
            selected = target
            print("Sketchbook curl test request: \(coordinator.displayedIndex) → \(target)")
            coordinator.configure(controller)
            waitForSketchbookTurn(coordinator)
            XCTAssertEqual(coordinator.displayedIndex, target)
            XCTAssertTrue(controller.viewControllers?.first === coordinator.controllers[target * 2],
                          "The settled face must be the requested sketch front (page \(target)), not parchment")
            XCTAssertEqual(controller.spineLocation, .min)
            for host in coordinator.controllers { XCTAssertTrue(host.safeAreaRegions.isEmpty) }
        }
    }

    func testSketchbookQueuesRapidReverseAndContentRefreshUntilCurlFinishes() throws {
        var selected = 0
        let curl = SketchbookPageCurl(pages: [AnyView(Text("Mill")), AnyView(Text("Greystone"))],
            index: Binding(get: { selected }, set: { selected = $0 }), enabled: true)
        let coordinator = curl.makeCoordinator()
        let controller = SketchbookPageCurl.makePageController()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let originalKey = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = controller
        coordinator.configure(controller)
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; originalKey?.makeKey() }
        window.layoutIfNeeded()
        controller.view.layoutIfNeeded()
        selected = 1
        coordinator.configure(controller)
        selected = 0
        coordinator.configure(controller)
        waitForSketchbookTurn(coordinator)
        XCTAssertEqual(selected, 0)
        XCTAssertEqual(coordinator.displayedIndex, 0)
        XCTAssertTrue(controller.viewControllers?.first === coordinator.controllers[0])
    }

    func testSketchbookArrowAfterCancelledInteractiveCurl() {
        var selected = 1
        let curl = SketchbookPageCurl(pages: [AnyView(Text("Mill")), AnyView(Text("Greystone"))],
            index: Binding(get: { selected }, set: { selected = $0 }), enabled: true)
        let coordinator = curl.makeCoordinator()
        let controller = SketchbookPageCurl.makePageController()
        coordinator.configure(controller)
        let original = coordinator.controllers
        coordinator.pageViewController(controller, willTransitionTo: [original[0], original[1]])
        // A SwiftUI refresh during a swipe must not rebuild hosts, even if catalog changes.
        coordinator.parent = SketchbookPageCurl(pages: curl.pages + [AnyView(Text("Future"))],
            index: curl.$index, enabled: true)
        coordinator.configure(controller)
        XCTAssertEqual(coordinator.controllers.count, 4)
        selected = 0 // queued arrow while gesture is cancelling
        coordinator.pageViewController(controller, didFinishAnimating: false,
            previousViewControllers: [original[2], original[3]], transitionCompleted: false)
        waitForSketchbookTurn(coordinator)
        XCTAssertEqual(selected, 0)
        XCTAssertEqual(coordinator.displayedIndex, 0)
        XCTAssertEqual(coordinator.controllers.count, 6)
    }

    private func waitForSketchbookTurn(_ coordinator: SketchbookPageCurl.Coordinator,
                                      file: StaticString = #filePath, line: UInt = #line) {
        // Pump the main run loop, rather than blocking it or nesting a Swift async
        // test task around UIKit's animation callbacks. Real curls still execute.
        let deadline = Date().addingTimeInterval(8)
        repeat {
            RunLoop.main.run(until: Date().addingTimeInterval(0.025))
            if !coordinator.transitioning { return }
        } while Date() < deadline
        XCTFail("Page curl did not settle", file: file, line: line)
    }

    func testStopsListKeepsInkForEveryStopAfterUnlockWhileSketchbookKeepsWatercolor() throws {
        for stop in HistoricalStop.previewStops {
            let ink = try XCTUnwrap(StopCollectionIllustration.assetName(for: stop.id, isSketchUnlocked: false))
            XCTAssertNotNil(UIImage(named: ink), "Missing unframed ink illustration for \(stop.name)")
            let unlocked = try XCTUnwrap(StopCollectionIllustration.assetName(for: stop.id, isSketchUnlocked: true))
            XCTAssertNotNil(UIImage(named: unlocked), "Missing collected illustration for \(stop.name)")
            XCTAssertEqual(ink, unlocked, "Stops retain hunter-green ink after a plaque unlock")
            if stop.hasPlaqueReference {
                XCTAssertNotEqual(ink, SketchArtwork.assetName(for: stop.id), "Sketchbook retains its watercolor")
            }
        }
    }

    func testRiverHomeAssetsAndSignpostAreAvailableInTheAppBundle() throws {
        var sketchStops = 0
        for stop in HistoricalStop.previewStops {
            let asset = try XCTUnwrap(HomeStopEmblem.assetName(for: stop.id),
                                      "Every configured stop needs a pencil-and-ink Home illustration")
            sketchStops += 1
            let image = try XCTUnwrap(UIImage(named: asset), "Missing Home illustration for \(stop.name)")
            XCTAssertEqual(image.size.width, image.size.height, accuracy: 1,
                           "Circular artwork must not be stretched by the Home layout")
        }
        XCTAssertEqual(sketchStops, HistoricalStop.previewStops.count)
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
        let stops = try XCTUnwrap(BundledStopArtwork.document).stops.filter(\.hasPlaqueReference)
        XCTAssertFalse(stops.isEmpty)
        for stop in stops {
            let reference = try XCTUnwrap(stop.plaque?.referenceImageName)
            XCTAssertNotNil(UIImage(named: reference + "-target"),
                            "Scanner card must show the plaque photograph for \(stop.name)")
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

    func testEveryStopHasTheLargestDestinationBadgeIndependentOfArtworkZoomAndVisitHistory() throws {
        for stop in HistoricalStop.previewStops {
            var marker = StopMarkerModel(id: stop.id, coordinate: stop.clLocationCoordinate,
                order: stop.order, name: stop.name, state: .visited, isTourDestination: true)
            let icon = StopMapIconView()
            icon.setArtwork(StopMapArtwork.image(for: marker))
            for walking in [false, true] {
                marker.isWalkingDestination = walking
                icon.setBadge(marker)
                let badge = try XCTUnwrap(icon.badgeView.image)
                XCTAssertEqual(try opaqueBadgeWidth(badge), 32, accuracy: 1)
                for scale in [0.1, 0.47, 0.72, 1.0, 1.3] {
                    icon.resize(scale: scale)
                    XCTAssertEqual(icon.badgeView.bounds.size, CGSize(width: 44, height: 44))
                    XCTAssertTrue(icon.bounds.insetBy(dx: -0.5, dy: -0.5).contains(icon.badgeView.frame))
                    XCTAssertTrue(icon.badgeView.image === badge, "Zoom must not shrink or regenerate the number")
                }
                marker.isTourDestination = false
                XCTAssertEqual(try opaqueBadgeWidth(StopMapArtwork.compactImage(for: marker)), 26, accuracy: 1)
                marker.isTourDestination = true
            }
        }
    }

    private func opaqueBadgeWidth(_ image: UIImage) throws -> CGFloat {
        let source = try XCTUnwrap(image.cgImage)
        let width = source.width, height = source.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let opaque = try pixels.withUnsafeMutableBytes { bytes -> Int in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(source, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
            return (0..<width).filter { bytes[(height / 2 * width + $0) * 4 + 3] > 127 }.count
        }
        return CGFloat(opaque) / image.scale
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
