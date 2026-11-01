import XCTest
import ARKit
import simd
import RealityKit
import UIKit
@testable import CranfordHistoricalAR
@testable import TourCore

@MainActor
final class GeoSpatialProviderFactoryTests: XCTestCase {
    func testGPSBeforeMatchingFrameIsRetriedWithoutReplayingBoundFixes() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var now = start
        var media = 100.0
        let provider = CoreLocationGeoSpatialProvider(hasCompass: true,
            currentDate: { now }, mediaTime: { media })
        provider.attach(session: ARSession())
        defer { provider.detach() }
        provider.update(cameraTransform: matrix_identity_float4x4, trackingState: .normal, timestamp: media)
        now = start.addingTimeInterval(1); media = 101
        let coordinate = GeoCoordinate(latitude: 40.65, longitude: -74.3)
        provider.update(location: .init(coordinate: coordinate, horizontalAccuracy: 3, timestamp: now),
            heading: .init(trueHeading: 0, magneticHeading: 0, accuracy: 5, timestamp: now))
        XCTAssertNil(provider.worldPosition(for: coordinate, altitude: nil, heightBelowCamera: 0))
        var camera = matrix_identity_float4x4
        camera.columns.3 = [4, 1.6, -2, 1]
        provider.update(cameraTransform: camera, trackingState: .normal, timestamp: media)
        XCTAssertEqual(try XCTUnwrap(provider.worldPosition(for: coordinate, altitude: nil, heightBelowCamera: 0)).x, 4, accuracy: 0.001)
    }

    func testOrdinaryOutdoorGPSShowsManeuverAndRecoversToSpatialArrows() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let provider = SpatialNavigationTestProvider()
        provider.pose?.timestamp = date
        let manager = GeoAnchorManager(provider: provider, currentDate: { date })
        var target = GeoAnchorManager.NavigationTarget(destination: provider.pose!.coordinate,
            bearingToWaypoint: 0, anchorCoordinate: provider.pose!.coordinate,
            turnCue: .init(direction: .right, streetName: "Springfield Ave", distanceMeters: 125,
                coordinate: nil, stepIndex: 1, isUpcomingTurn: true, isTowardStreet: false),
            locationTimestamp: date, horizontalAccuracy: 9, routeOffset: 8)
        manager.setNavigationTarget(target)
        manager.updateNavigationPose(cameraTransform: matrix_identity_float4x4, trackingState: .normal, timestamp: 0)
        XCTAssertTrue(manager.hasPlacedNavigation)
        XCTAssertTrue(manager.isNavigationManeuverOnly)
        XCTAssertNotNil(manager.anchors.arrows.guidancePosition)
        XCTAssertTrue(manager.navigationNotice?.contains("Not aligned") == true)
        target.horizontalAccuracy = 3; target.routeOffset = 0
        manager.setNavigationTarget(target)
        for time in stride(from: 0.1, through: 2.2, by: 0.1) {
            manager.updateNavigationPose(cameraTransform: matrix_identity_float4x4, trackingState: .normal, timestamp: time)
        }
        XCTAssertEqual(manager.spatialMode, .spatial)
        XCTAssertFalse(manager.isNavigationManeuverOnly)
        XCTAssertTrue(manager.hasPlacedNavigation)
        manager.trackingStateDidChange(.limited(.insufficientFeatures))
        XCTAssertNil(manager.anchors.arrows.guidancePosition)
        target.horizontalAccuracy = 40
        manager.setNavigationTarget(target)
        manager.updateNavigationPose(cameraTransform: matrix_identity_float4x4, trackingState: .normal, timestamp: 2.3)
        XCTAssertFalse(manager.hasPlacedNavigation)
        XCTAssertNil(manager.anchors.arrows.guidancePosition)
        manager.setNavigationTarget(nil)
        XCTAssertNil(manager.anchors.arrows.guidancePosition)
    }

    func testCoreLocationAlignmentUsesFrameCaptureTimeAfterDelayedDelivery() throws {
        let sampleDate = Date(timeIntervalSince1970: 1_800_000_000)
        let provider = CoreLocationGeoSpatialProvider(hasCompass: true,
            currentDate: { sampleDate.addingTimeInterval(0.8) }, mediaTime: { 100.8 })
        provider.attach(session: ARSession())
        defer { provider.detach() }
        var camera = matrix_identity_float4x4
        camera.columns.3 = [5, 1.6, -2, 1]
        provider.update(cameraTransform: camera, trackingState: .normal, timestamp: 100)
        let coordinate = GeoCoordinate(latitude: 40.65, longitude: -74.30)
        provider.update(location: LocationSample(coordinate: coordinate, horizontalAccuracy: 3,
            timestamp: sampleDate), heading: HeadingSample(trueHeading: 0, magneticHeading: 0,
            accuracy: 5, timestamp: sampleDate))
        // Isolate capture-time binding at the known geographic origin. Route distances
        // use a mean-radius sphere; WGS84 offsets intentionally differ at centimetre scale.
        let point = try XCTUnwrap(provider.worldPosition(for: coordinate, altitude: nil, heightBelowCamera: 0))
        XCTAssertEqual(point.x, 5, accuracy: 0.001)
        XCTAssertEqual(point.y, 1.6, accuracy: 0.001)
        XCTAssertEqual(point.z, -2, accuracy: 0.001)
        // Replaying a heading update cannot bind an old GPS coordinate to a new camera pose.
        camera.columns.3.x = 9
        provider.update(cameraTransform: camera, trackingState: .normal, timestamp: 100.1)
        provider.update(location: LocationSample(coordinate: coordinate, horizontalAccuracy: 3,
            timestamp: sampleDate), heading: HeadingSample(trueHeading: 0, magneticHeading: 0,
            accuracy: 5, timestamp: sampleDate))
        XCTAssertEqual(provider.worldPosition(for: coordinate, altitude: nil, heightBelowCamera: 0)?.x ?? -1,
                       5, accuracy: 0.01)
    }

    func testPassedWorldChevronHidesUntilNextDirectionSettles() {
        let arrows = ARNavigationArrowEntity()
        arrows.setVisible(true)
        arrows.updateSpatial(ground: [0, 0, -7], camera: .zero, routeDirection: [0, 0, -1],
            instruction: .init(direction: .ahead, streetName: nil), segment: 0, timestamp: 0)
        XCTAssertNotNil(arrows.guidancePosition)
        arrows.updateSpatial(ground: [6, 0, -8], camera: [0, 0, -8], routeDirection: [1, 0, 0],
            instruction: .init(direction: .ahead, streetName: nil), segment: 1, timestamp: 0.5)
        XCTAssertNil(arrows.guidancePosition)
        arrows.updateSpatial(ground: [6, 0, -8], camera: [0, 0, -8], routeDirection: [1, 0, 0],
            instruction: .init(direction: .ahead, streetName: nil), segment: 1, timestamp: 1.5)
        XCTAssertNotNil(arrows.guidancePosition)
    }

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

    func testReferenceImageWidthsMatchCatalogMetadata() async throws {
        let document = try await BundledJSONHistoricalStopService().loadTour()
        let images = PlaqueAnchorController.loadReferenceImages()
        for stop in document.stops where stop.hasPlaqueReference {
            let plaque = try XCTUnwrap(stop.plaque)
            let matching = images.filter { $0.name == plaque.referenceImageName }
            XCTAssertEqual(matching.count, 1)
            let image = try XCTUnwrap(matching.first)
            XCTAssertEqual(Double(image.physicalSize.width), plaque.physicalWidthMeters, accuracy: 0.00001)
            XCTAssertGreaterThan(image.physicalSize.height, 0)
        }
        // This checks internal consistency, not the unmeasured outdoor dimensions.
    }

    func testReferenceImageFilterClearsPreviousDetectionConfiguration() {
        let configuration = ARWorldTrackingConfiguration()
        XCTAssertTrue(PlaqueAnchorController.applyDetectionImages(to: configuration,
            referenceNames: [SignPlacementPolicy.millReferenceImageName]))
        if ARWorldTrackingConfiguration.isSupported {
            XCTAssertEqual(Set(configuration.detectionImages?.compactMap(\.name) ?? []),
                           [SignPlacementPolicy.millReferenceImageName])
        }
        XCTAssertFalse(PlaqueAnchorController.applyDetectionImages(to: configuration, referenceNames: []))
        XCTAssertTrue(configuration.detectionImages?.isEmpty ?? true)
        XCTAssertEqual(configuration.maximumNumberOfTrackedImages, 0)
    }

    func testInactiveScannerDoesNotRecoverOnLateInterruptionCallbackOrAwardAnything() async {
        let dependencies = AppDependencies.preview()
        let tour = dependencies.tourViewModel
        await tour.loadStopsIfNeeded()
        let destination = tour.currentStop?.id
        let model = ARViewModel(tour: tour, provider: CoreLocationGeoSpatialProvider(hasCompass: false),
            imageLoader: dependencies.imageLoader, narrationPlayer: dependencies.narrationPlayer,
            isPlaqueScanner: true)
        _ = model.makeSessionConfiguration()
        model.setApplicationActive(false)
        model.sessionWasInterrupted()
        model.sessionInterruptionEnded()
        XCTAssertEqual(model.localizationState, .interrupted)
        XCTAssertFalse(model.isConfirmingPlaque)
        XCTAssertTrue(model.scannerInstruction(at: Date()).contains("paused"))
        XCTAssertEqual(model.placementMode, .hidden)
        XCTAssertNil(tour.pendingSketchStopID)
        XCTAssertFalse(tour.isARSessionActive)
        XCTAssertEqual(tour.currentStop?.id, destination)
        XCTAssertEqual(tour.phase, .notStarted)
        model.setApplicationActive(true)
        model.sessionInterruptionEnded()
        XCTAssertEqual(model.localizationState, .initializing)
        XCTAssertNil(tour.pendingSketchStopID)
    }

    func testSessionFailureImmediatelyClearsWorldGuidance() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let provider = SpatialNavigationTestProvider()
        provider.pose?.timestamp = date
        let manager = GeoAnchorManager(provider: provider, currentDate: { date })
        manager.setNavigationTarget(.init(destination: provider.pose!.coordinate,
            bearingToWaypoint: 0, anchorCoordinate: provider.pose!.coordinate, turnCue: nil,
            locationTimestamp: date, horizontalAccuracy: 3, routeOffset: 0))
        for time in stride(from: 0.0, through: 2.1, by: 0.1) {
            manager.updateNavigationPose(cameraTransform: matrix_identity_float4x4,
                trackingState: .normal, timestamp: time)
        }
        XCTAssertTrue(manager.hasPlacedNavigation)
        manager.sessionDidFail("Test interruption")
        XCTAssertFalse(manager.hasPlacedNavigation)
        XCTAssertNil(manager.anchors.arrows.guidancePosition)
        XCTAssertEqual(manager.localizationState, .failed("Test interruption"))
        XCTAssertNil(manager.navigationNotice, "An old alignment notice must not mask a session error")
    }

    func testScannerFailureShowsRecoveryInsteadOfCameraStarting() async {
        let dependencies = AppDependencies.preview()
        await dependencies.tourViewModel.loadStopsIfNeeded()
        let model = ARViewModel(tour: dependencies.tourViewModel,
            provider: CoreLocationGeoSpatialProvider(hasCompass: false),
            imageLoader: dependencies.imageLoader, narrationPlayer: dependencies.narrationPlayer,
            isPlaqueScanner: true)
        model.sessionDidFail(message: "Test camera failure", code: nil)
        XCTAssertEqual(model.scannerPhaseTitle, "Scanning stopped")
        XCTAssertTrue(model.scannerInstruction(at: Date()).contains("Try again"))
        XCTAssertNil(dependencies.tourViewModel.pendingSketchStopID)
        XCTAssertEqual(model.placementMode, .hidden)
    }

    func testTrackingLossHidesHistoricalContentWithoutAWorldSpaceFade() {
        let manager = GeoAnchorManager(provider: CoreLocationGeoSpatialProvider(hasCompass: false))
        manager.anchors.sign.presentOnPlaque()
        XCTAssertTrue(manager.anchors.sign.isEnabled)
        manager.trackingStateDidChange(.limited(.insufficientFeatures))
        XCTAssertFalse(manager.anchors.sign.isEnabled)
        XCTAssertFalse(manager.anchors.sign.isPresented)
        manager.anchors.sign.presentOnPlaque()
        manager.updateNavigationPose(cameraTransform: matrix_identity_float4x4,
            trackingState: .limited(.relocalizing), timestamp: 1)
        XCTAssertFalse(manager.anchors.sign.isEnabled)
        manager.anchors.sign.presentOnPlaque()
        manager.sessionDidFail("Test camera failure")
        XCTAssertFalse(manager.anchors.sign.isEnabled)
    }

    func testNormalTrackingWithoutGeographicAlignmentDoesNotInventStreetArrows() {
        let manager = GeoAnchorManager(provider: CoreLocationGeoSpatialProvider(hasCompass: false))
        manager.setNavigationTarget(.init(destination: .init(latitude: 40.65, longitude: -74.30),
            bearingToWaypoint: 90, anchorCoordinate: nil, turnCue: nil))
        for time in stride(from: 0.0, through: 3.0, by: 0.1) {
            manager.updateNavigationPose(cameraTransform: matrix_identity_float4x4, trackingState: .normal, timestamp: time)
        }
        XCTAssertFalse(manager.hasPlacedNavigation)
        XCTAssertNil(manager.anchors.arrows.guidancePosition)
        XCTAssertNotNil(manager.navigationNotice)
    }

    func testAlignedRoutePoseDoesNotFollowPhoneRotationAndHidesOnTrackingLoss() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let provider = SpatialNavigationTestProvider()
        provider.pose?.timestamp = date
        // Cold RealityKit initialization can exceed the location freshness limit.
        // Simulated sensors and freshness must share a clock, independent of rendering cost.
        let manager = GeoAnchorManager(provider: provider, currentDate: { date })
        manager.setNavigationTarget(.init(destination: provider.pose!.coordinate,
            bearingToWaypoint: 0, anchorCoordinate: provider.pose!.coordinate, turnCue: nil,
            locationTimestamp: date, horizontalAccuracy: 3, routeOffset: 0))
        for time in stride(from: 0.0, through: 2.1, by: 0.1) {
            manager.updateNavigationPose(cameraTransform: matrix_identity_float4x4, trackingState: .normal, timestamp: time)
        }
        let position = try XCTUnwrap(manager.anchors.arrows.guidancePosition)
        XCTAssertTrue(manager.hasPlacedNavigation)
        XCTAssertEqual(position.z, -7, accuracy: 0.01)
        let turned = simd_float4x4(simd_quatf(angle: .pi, axis: [0, 1, 0]))
        manager.updateNavigationPose(cameraTransform: turned, trackingState: .normal, timestamp: 2.2)
        XCTAssertEqual(manager.anchors.arrows.guidancePosition, position)
        manager.trackingStateDidChange(.limited(.insufficientFeatures))
        XCTAssertNil(manager.anchors.arrows.guidancePosition)
    }

    func testSpatialPoseExpiryHidesArrowsEvenWhenRouteLocationIsFresh() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let provider = SpatialNavigationTestProvider()
        provider.pose?.timestamp = date.addingTimeInterval(-6)
        let manager = GeoAnchorManager(provider: provider, currentDate: { date })
        manager.setNavigationTarget(.init(destination: provider.pose!.coordinate,
            bearingToWaypoint: 0, anchorCoordinate: provider.pose!.coordinate, turnCue: nil,
            locationTimestamp: date, horizontalAccuracy: 3, routeOffset: 0))
        for time in stride(from: 0.0, through: 2.1, by: 0.1) {
            manager.updateNavigationPose(cameraTransform: matrix_identity_float4x4,
                trackingState: .normal, timestamp: time)
        }
        XCTAssertFalse(manager.hasPlacedNavigation)
        XCTAssertNil(manager.anchors.arrows.guidancePosition)
        XCTAssertEqual(manager.spatialMode, .degraded(.location))
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

    func testChevronArtworkRetainsWhiteFacesAndVisibleTexturedGreenSidewalls() {
        let arrow = ARNavigationArrowEntity()
        var materials: [UnlitMaterial] = []
        func inspect(_ entity: Entity) {
            if let model = entity as? ModelEntity {
                materials += (model.model?.materials ?? []).compactMap { $0 as? UnlitMaterial }
            }
            for child in entity.children { inspect(child) }
        }
        inspect(arrow)
        let texturedSides = materials.filter { $0.color.texture != nil }
        let whiteFaces = materials.filter { material in
            guard material.color.texture == nil else { return false }
            // RealityKit can return an equivalent white in a different color space.
            // Compare resolved components rather than UIColor object/color-space equality.
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            guard material.color.tint.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return false }
            return [red, green, blue, alpha].allSatisfy { abs($0 - 1) < 0.001 }
        }
        XCTAssertEqual(texturedSides.count, 3, "Each extruded body needs its cached hunter-green gradient")
        XCTAssertEqual(whiteFaces.count, 3, "Keep the three bright white front faces")
        XCTAssertTrue(arrow.canRender)
    }

    func testNavigationArrowMeshesAndInitialGroundedPlacementAreRenderable() {
        let arrow = ARNavigationArrowEntity()
        XCTAssertTrue(arrow.canRender, "Body and face meshes must both generate successfully")
        arrow.setVisible(true)
        arrow.updateSpatial(ground: [0, -1.4, -8], camera: .zero, routeDirection: [0, 0, -1],
                     instruction: .init(direction: .left, streetName: "Alden St"), segment: 0, timestamp: 1)
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

@MainActor
private final class SpatialNavigationTestProvider: GeoSpatialProvider {
    let displayName = "Deterministic route test"
    let backend: GeoSpatialBackend = .coreLocation
    let quality: GeoLocalizationQuality = .good
    let preferredWorldAlignment: ARConfiguration.WorldAlignment = .gravityAndHeading
    let fallbackReason: GeoSpatialFallbackReason? = nil
    let vpsCoverage: VPSCoverage = .unknown
    var pose: GeoPose? = GeoPose(coordinate: .init(latitude: 40.65, longitude: -74.30),
        horizontalAccuracy: 3, heading: 0, headingAccuracy: 5, altitude: nil, timestamp: Date())
    func attach(session: ARSession) {}
    func detach() {}
    func update(cameraTransform: simd_float4x4, trackingState: ARCamera.TrackingState, timestamp: TimeInterval) {}
    func update(frame: ARFrame) {}
    func update(location: LocationSample?, heading: HeadingSample?) {}
    func worldPosition(for coordinate: GeoCoordinate, altitude: Double?, heightBelowCamera: Float) -> SIMD3<Float>? { [0, -1.4, -7] }
    func worldDirection(forBearing bearing: Double) -> SIMD3<Float>? { [0, 0, -1] }
}
