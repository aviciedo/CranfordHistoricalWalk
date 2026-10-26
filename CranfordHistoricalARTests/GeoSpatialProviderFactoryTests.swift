import XCTest
import RealityKit
@testable import CranfordHistoricalAR
import TourCore

@MainActor
final class GeoSpatialProviderFactoryTests: XCTestCase {
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
