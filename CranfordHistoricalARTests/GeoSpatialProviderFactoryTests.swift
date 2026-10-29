import XCTest
import ARKit
import simd
import RealityKit
@testable import CranfordHistoricalAR
import TourCore

@MainActor
final class GeoSpatialProviderFactoryTests: XCTestCase {
    func testWalkingSessionNeverEnablesPlaqueRecognitionOrChangesToScanner() async {
        let dependencies = AppDependencies.preview()
        let tour = dependencies.tourViewModel
        await tour.loadStopsIfNeeded()
        // Persisted discoveries/search state must not change the session's purpose.
        tour.activities.collectSketch(at: "hpab-001")
        let model = ARViewModel(tour: tour, provider: CoreLocationGeoSpatialProvider(),
            imageLoader: dependencies.imageLoader, narrationPlayer: dependencies.narrationPlayer)
        let config = model.makeSessionConfiguration()
        XCTAssertTrue(config.detectionImages?.isEmpty ?? true)
        XCTAssertFalse(model.imageTrackingAvailable)
        XCTAssertTrue(config.planeDetection.contains(.horizontal))
        model.startPlaqueDiscovery()
        model.showSign()
        model.activateMarker()
        XCTAssertFalse(model.isPlaqueScanner, "Walking cannot silently change into plaque scanning")
        XCTAssertFalse(model.isShowingSignDetails)
        XCTAssertNil(tour.pendingSketchStopID)
    }

    func testExplicitScannerSessionRegistersPlaqueImagesWithoutStartingWalk() async {
        let dependencies = AppDependencies.preview()
        let tour = dependencies.tourViewModel
        await tour.loadStopsIfNeeded()
        let model = ARViewModel(tour: tour, provider: CoreLocationGeoSpatialProvider(),
            imageLoader: dependencies.imageLoader, narrationPlayer: dependencies.narrationPlayer,
            isPlaqueScanner: true)
        let config = model.makeSessionConfiguration()
        XCTAssertTrue(model.isPlaqueScanner)
        XCTAssertTrue(model.imageTrackingAvailable, "The explicit scanner must retain bundled image recognition")
        let bundledNames = Set(PlaqueAnchorController.loadReferenceImages().compactMap(\.name))
        let configuredNames = Set(tour.sketchbookStops.compactMap { $0.plaque?.referenceImageName })
        XCTAssertFalse(configuredNames.isEmpty)
        XCTAssertTrue(configuredNames.isSubset(of: bundledNames),
                      "Every configured passport stop needs its bundled recognition image")
        // Simulator loads the asset catalog but ARKit can discard detectionImages because
        // world tracking is unsupported there. Inspect retained configuration on devices.
        if ARWorldTrackingConfiguration.isSupported {
            XCTAssertFalse(config.detectionImages?.isEmpty ?? true)
        }
        XCTAssertTrue(config.planeDetection.isEmpty)
        XCTAssertEqual(tour.phase, .notStarted)
        XCTAssertNil(tour.pendingSketchStopID, "Opening the scanner does not award a stamp")
    }

    func testNormalTrackingPlacesChunkySignWithoutGroundOrGeographicLocalization() throws {
        let manager = GeoAnchorManager(provider: CoreLocationGeoSpatialProvider(hasCompass: false))
        manager.setNavigationTarget(.init(destination: .init(latitude: 40.65, longitude: -74.30),
            bearingToWaypoint: 90, anchorCoordinate: nil, turnCue: nil))
        manager.updateNavigationPose(cameraTransform: matrix_identity_float4x4, trackingState: .normal, timestamp: 1)
        XCTAssertFalse(manager.hasDetectedGround)
        XCTAssertFalse(manager.localizationState.isUsable)
        XCTAssertTrue(manager.hasPlacedNavigation)
        let position = try XCTUnwrap(manager.anchors.arrows.guidancePosition)
        XCTAssertEqual(position.z, -8, accuracy: 0.01)
        let bounds = manager.anchors.arrows.visualBounds(relativeTo: nil)
        XCTAssertGreaterThan(bounds.extents.x, 1)
        XCTAssertGreaterThan(bounds.extents.y, 1)
        XCTAssertGreaterThan(bounds.extents.z, 0.1)

        let turned = simd_float4x4(simd_quatf(angle: .pi / 2, axis: [0, 1, 0]))
        manager.updateNavigationPose(cameraTransform: turned, trackingState: .normal, timestamp: 2)
        XCTAssertEqual(manager.anchors.arrows.guidancePosition, position, "Turning the phone must not move the sign")
        manager.updateNavigationPose(cameraTransform: turned, trackingState: .limited(.insufficientFeatures), timestamp: 3)
        XCTAssertNil(manager.anchors.arrows.guidancePosition)
        manager.updateNavigationPose(cameraTransform: turned, trackingState: .normal, timestamp: 4)
        XCTAssertEqual(manager.anchors.arrows.guidancePosition, position, "Recovery restores the fixed world anchor")

        manager.hasActivatedStop = true
        manager.updateNavigationPose(cameraTransform: turned, trackingState: .normal, timestamp: 5)
        XCTAssertNil(manager.anchors.arrows.guidancePosition)
    }

    func testNoRouteAndStaleLocationDoNotCreateInventedARInstructions() {
        let manager = GeoAnchorManager(provider: CoreLocationGeoSpatialProvider(hasCompass: false))
        manager.updateNavigationPose(cameraTransform: matrix_identity_float4x4, trackingState: .normal, timestamp: 1)
        XCTAssertNil(manager.anchors.arrows.guidancePosition)
        manager.setNavigationTarget(.init(destination: .init(latitude: 40.65, longitude: -74.30),
            bearingToWaypoint: 90, anchorCoordinate: nil, turnCue: nil,
            locationTimestamp: Date().addingTimeInterval(-60)))
        manager.updateNavigationPose(cameraTransform: matrix_identity_float4x4, trackingState: .normal, timestamp: 2)
        XCTAssertNil(manager.anchors.arrows.guidancePosition)
        XCTAssertTrue(manager.navigationNotice?.contains("fresh location") == true)
    }

    func testNavigationArrowMeshesAndInitialGroundedPlacementAreRenderable() {
        let arrow = ARNavigationArrowEntity()
        XCTAssertTrue(arrow.canRender, "Body and face meshes must both generate successfully")
        arrow.setVisible(true)
        arrow.update(ground: [0, -1.4, -8], camera: .zero,
                     instruction: .init(direction: .left, streetName: "Alden St"), timestamp: 1)
        XCTAssertNotNil(arrow.guidancePosition, "A valid first placement must enable the arrow entity")
        arrow.setVisible(false)
        XCTAssertNil(arrow.guidancePosition)
        arrow.setVisible(true)
        XCTAssertNotNil(arrow.guidancePosition, "Transient visibility loss retains the fixed anchor")
        arrow.resetAnchor()
        XCTAssertNil(arrow.guidancePosition)
    }

    func testDisabledFlagSelectsCoreLocation() {
        let selection = GeoSpatialProviderFactory.selection(
            configuration: .empty,
            locationAuthorized: true,
            preciseLocation: true,
            userConsented: true,
            networkAvailable: true
        )
        XCTAssertEqual(selection.backend, .coreLocation)
        XCTAssertTrue(selection.fallbackReason == .flagDisabled || selection.fallbackReason == .sdkNotLinked)
    }

    func testEnabledWithoutKeyFallsBack() {
        var configuration = AppConfiguration.empty
        configuration.arCoreGeospatialEnabled = true
        let selection = GeoSpatialProviderFactory.selection(
            configuration: configuration,
            locationAuthorized: true,
            preciseLocation: true,
            userConsented: true,
            networkAvailable: true
        )
        XCTAssertEqual(selection.backend, .coreLocation)
        if GeoSpatialProviderFactory.isSDKLinked {
            XCTAssertEqual(selection.fallbackReason, .missingAPIKey)
        } else {
            XCTAssertEqual(selection.fallbackReason, .sdkNotLinked)
        }
        XCTAssertNotNil(selection.reducedAccuracyMessage)
    }

    func testEnabledWithoutConsentFallsBack() {
        var configuration = AppConfiguration.empty
        configuration.arCoreGeospatialEnabled = true
        configuration.googleARCoreAPIKey = "AIzaSyExampleExampleExampleExample"
        let selection = GeoSpatialProviderFactory.selection(
            configuration: configuration,
            locationAuthorized: true,
            preciseLocation: true,
            userConsented: false,
            networkAvailable: true
        )
        XCTAssertEqual(selection.backend, .coreLocation)
        if GeoSpatialProviderFactory.isSDKLinked {
            XCTAssertEqual(selection.fallbackReason, .missingUserConsent)
        } else {
            XCTAssertEqual(selection.fallbackReason, .sdkNotLinked)
        }
    }

    func testPreciseLocationAndNetworkAreRequired() {
        var configuration = AppConfiguration.empty
        configuration.arCoreGeospatialEnabled = true
        configuration.googleARCoreAPIKey = "AIzaSyExampleExampleExampleExample"
        let reduced = GeoSpatialProviderFactory.selection(
            configuration: configuration,
            locationAuthorized: true,
            preciseLocation: false,
            userConsented: true,
            networkAvailable: true
        )
        let offline = GeoSpatialProviderFactory.selection(
            configuration: configuration,
            locationAuthorized: true,
            preciseLocation: true,
            userConsented: true,
            networkAvailable: false
        )
        if GeoSpatialProviderFactory.isSDKLinked {
            XCTAssertEqual(reduced.fallbackReason, .preciseLocationRequired)
            XCTAssertEqual(offline.fallbackReason, .networkUnavailable)
        } else {
            XCTAssertEqual(reduced.fallbackReason, .sdkNotLinked)
            XCTAssertEqual(offline.fallbackReason, .sdkNotLinked)
        }
    }

    func testMakeReturnsCoreLocationWhenNotSelected() {
        let provider = GeoSpatialProviderFactory.make(
            configuration: .empty,
            locationAuthorized: true,
            preciseLocation: true,
            userConsented: true,
            networkAvailable: true
        )
        XCTAssertEqual(provider.backend, .coreLocation)
        XCTAssertEqual(provider.preferredWorldAlignment, CoreLocationGeoSpatialProvider().preferredWorldAlignment)
    }

    func testARCoreKeyFallsBackToRoutesKey() {
        // Mirrors AppConfiguration.from(bundle:) when GoogleARCoreAPIKey is empty.
        XCTAssertFalse(AppConfiguration.empty.hasARCoreKey)
        var configuration = AppConfiguration.empty
        configuration.googleRoutesAPIKey = "AIzaSyExampleExampleExampleExample"
        configuration.googleARCoreAPIKey = configuration.googleRoutesAPIKey
        XCTAssertTrue(configuration.hasARCoreKey)
    }
}
