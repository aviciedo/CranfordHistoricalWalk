import XCTest
@testable import TourCore

final class TourProviderModeTests: XCTestCase {
    func testMapsNeverCrossStrictProviderBoundaries() {
        XCTAssertEqual(TourProviderMode.appleOnly.mapBackend(googleConfigured: true), .apple)
        XCTAssertEqual(TourProviderMode.appleOnly.mapBackend(googleConfigured: false), .apple)
        XCTAssertEqual(TourProviderMode.googleOnly.mapBackend(googleConfigured: true), .google)
        XCTAssertEqual(TourProviderMode.googleOnly.mapBackend(googleConfigured: false), .unavailable)
        XCTAssertEqual(TourProviderMode.automatic.mapBackend(googleConfigured: false), .apple)
        XCTAssertEqual(TourProviderMode.automatic.mapBackend(googleConfigured: true), .google)
    }

    func testReleaseCannotInheritADeveloperOverride() {
        for mode in TourProviderMode.allCases {
            XCTAssertEqual(TourProviderMode.launchMode(storedValue: mode.rawValue, developerEnabled: false), .automatic)
            XCTAssertEqual(TourProviderMode.launchMode(storedValue: mode.rawValue, developerEnabled: true), mode)
        }
        XCTAssertEqual(TourProviderMode.launchMode(storedValue: "unknown", developerEnabled: true), .automatic)
        XCTAssertEqual(TourProviderMode.launchMode(storedValue: nil, developerEnabled: true), .automatic)
    }

    func testStrictGoogleDisablesNativeARPositioningFallback() {
        XCTAssertFalse(TourProviderMode.googleOnly.allowsNativeARFallback)
        XCTAssertTrue(TourProviderMode.appleOnly.allowsNativeARFallback)
        XCTAssertTrue(TourProviderMode.automatic.allowsNativeARFallback)
    }
}
