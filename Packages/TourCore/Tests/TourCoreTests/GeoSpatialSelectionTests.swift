import XCTest
@testable import TourCore

final class GeoSpatialSelectionTests: XCTestCase {
    private func input(
        sdk: Bool = true,
        flag: Bool = true,
        key: Bool = true,
        consent: Bool = true,
        device: Bool = true,
        location: Bool = true,
        precise: Bool = true,
        network: Bool = true
    ) -> GeoSpatialSelectionInput {
        GeoSpatialSelectionInput(
            sdkLinked: sdk,
            flagEnabled: flag,
            hasAPIKey: key,
            userConsented: consent,
            deviceSupportsGeospatial: device,
            locationAuthorized: location,
            preciseLocation: precise,
            networkAvailable: network
        )
    }

    func testHappyPathSelectsARCore() {
        let selection = GeoSpatialSelector.select(input())
        XCTAssertEqual(selection.backend, .arCoreGeospatial)
        XCTAssertNil(selection.fallbackReason)
        XCTAssertTrue(selection.usesARCore)
        XCTAssertNil(selection.reducedAccuracyMessage)
    }

    func testFallbackOrderPrefersFirstBlockingReason() {
        XCTAssertEqual(GeoSpatialSelector.select(input(sdk: false, flag: false)).fallbackReason, .sdkNotLinked)
        XCTAssertEqual(GeoSpatialSelector.select(input(flag: false)).fallbackReason, .flagDisabled)
        XCTAssertEqual(GeoSpatialSelector.select(input(sdk: false)).fallbackReason, .sdkNotLinked)
        XCTAssertEqual(GeoSpatialSelector.select(input(key: false)).fallbackReason, .missingAPIKey)
        XCTAssertEqual(GeoSpatialSelector.select(input(consent: false)).fallbackReason, .missingUserConsent)
        XCTAssertEqual(GeoSpatialSelector.select(input(device: false)).fallbackReason, .deviceUnsupported)
        XCTAssertEqual(GeoSpatialSelector.select(input(location: false)).fallbackReason, .locationPermissionDenied)
        XCTAssertEqual(GeoSpatialSelector.select(input(precise: false)).fallbackReason, .preciseLocationRequired)
        XCTAssertEqual(GeoSpatialSelector.select(input(network: false)).fallbackReason, .networkUnavailable)
        XCTAssertEqual(GeoSpatialSelector.select(input(flag: false)).backend, .coreLocation)
    }

    func testQualityBuckets() {
        XCTAssertEqual(GeoSpatialSelector.quality(horizontalAccuracy: 4, yawAccuracy: 4), .good)
        XCTAssertEqual(GeoSpatialSelector.quality(horizontalAccuracy: 7, yawAccuracy: 10), .good)
        XCTAssertEqual(GeoSpatialSelector.quality(horizontalAccuracy: 12, yawAccuracy: 18), .fair)
        XCTAssertEqual(GeoSpatialSelector.quality(horizontalAccuracy: 20, yawAccuracy: 25), .fair)
        XCTAssertEqual(GeoSpatialSelector.quality(horizontalAccuracy: 30, yawAccuracy: 10), .poor)
        XCTAssertEqual(GeoSpatialSelector.quality(horizontalAccuracy: 8, yawAccuracy: 40), .poor)
        XCTAssertEqual(GeoSpatialSelector.quality(horizontalAccuracy: -1, yawAccuracy: 5), .unavailable)
        XCTAssertEqual(GeoSpatialSelector.quality(horizontalAccuracy: 10, yawAccuracy: -1), .fair)
    }

    func testEarthStateAndVPSCodeMapping() {
        XCTAssertNil(GeoSpatialSelector.fallbackReason(fromEarthStateCode: 0))
        XCTAssertEqual(GeoSpatialSelector.fallbackReason(fromEarthStateCode: -2), .earthNotAuthorized)
        XCTAssertEqual(GeoSpatialSelector.fallbackReason(fromEarthStateCode: -3), .earthResourceExhausted)
        XCTAssertEqual(GeoSpatialSelector.fallbackReason(fromEarthStateCode: -1), .earthInternalError)
        XCTAssertEqual(GeoSpatialSelector.coverage(fromVPSAvailabilityCode: 1), .available)
        XCTAssertEqual(GeoSpatialSelector.coverage(fromVPSAvailabilityCode: 2), .unavailable)
        XCTAssertTrue(VPSCoverage.unavailable.reducesAccuracy)
        XCTAssertFalse(VPSCoverage.available.reducesAccuracy)
        XCTAssertNotNil(VPSCoverage.unavailable.userMessage)
        XCTAssertNil(VPSCoverage.available.userMessage)
    }

    func testFallbackMessagesAreNonEmptyAndHonest() {
        for reason in [
            GeoSpatialFallbackReason.flagDisabled, .sdkNotLinked, .missingAPIKey, .missingUserConsent,
            .deviceUnsupported, .locationPermissionDenied, .preciseLocationRequired, .networkUnavailable,
            .sessionConfigurationFailed, .earthNotAuthorized, .earthResourceExhausted, .earthInternalError,
            .localizationTimedOut, .geospatialUnavailable
        ] {
            XCTAssertFalse(reason.userMessage.isEmpty, reason.rawValue)
            XCTAssertFalse(reason.userMessage.lowercased().contains("centimeter"))
        }
    }

    func testOptionalAltitudeDecodes() throws {
        let with = """
        {"id":"n","name":"N","latitude":40.65,"longitude":-74.30,"altitude":38.2,"order":1}
        """.data(using: .utf8)!
        let stop = try JSONDecoder().decode(HistoricalStop.self, from: with)
        XCTAssertEqual(stop.altitude, 38.2)
        let without = """
        {"id":"n","name":"N","latitude":40.65,"longitude":-74.30,"order":1}
        """.data(using: .utf8)!
        XCTAssertNil(try JSONDecoder().decode(HistoricalStop.self, from: without).altitude)
    }
}
