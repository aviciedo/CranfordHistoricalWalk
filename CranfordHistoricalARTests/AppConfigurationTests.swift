import CoreLocation
import XCTest
import TourCore
@testable import CranfordHistoricalAR

final class AppConfigurationTests: XCTestCase {
    func testPlaceholdersAreNotKeys() {
        XCTAssertFalse(AppConfiguration.looksLikeKey(""))
        XCTAssertFalse(AppConfiguration.looksLikeKey("$(GOOGLE_MAPS_API_KEY)"), "unexpanded xcconfig variable")
        XCTAssertFalse(AppConfiguration.looksLikeKey("your-maps-key-here"), "Secrets.example.xcconfig placeholder")
        XCTAssertTrue(AppConfiguration.looksLikeKey("AIzaSyExampleExampleExampleExample"))
        XCTAssertFalse(AppConfiguration.looksLikeKey("AIza...your-arcore-api-key..."))
    }

    func testMainBundleConfigurationNeverCrashesWithoutSecrets() {
        // Whatever Secrets.xcconfig contains (or doesn't), reading configuration must be total.
        let configuration = AppConfiguration.fromMainBundle()
        XCTAssertTrue([.routes, .legacy].contains(configuration.directionsProvider))
    }

    func testIOSBundleIdentifierIsNeverEmpty() {
        let id = AppConfiguration.iosBundleIdentifier()
        XCTAssertFalse(id.isEmpty)
        XCTAssertFalse(id.hasPrefix("$("))
        XCTAssertTrue(id.hasPrefix("com.cranford.historicalar"))
        XCTAssertEqual(GoogleAPIClientIdentity.resolvedIOSBundleIdentifier(""), "com.cranford.historicalar")
        XCTAssertEqual(GoogleAPIClientIdentity.resolvedIOSBundleIdentifier("$(PRODUCT_BUNDLE_IDENTIFIER)"), "com.cranford.historicalar")
    }

    @MainActor
    func testDirectionsFactoryUsesAndCachesAppleWalkingFallbackWhenGoogleKeysAreMissing() async throws {
        let apple = AppleWalkingFallbackStub()
        let service = DirectionsServiceFactory.make(configuration: .empty, apple: apple)
        let origin = CLLocationCoordinate2D(latitude: 40.6565, longitude: -74.3040)
        let destination = CLLocationCoordinate2D(latitude: 40.6580, longitude: -74.3005)
        let route = try await service.walkingRoute(from: origin, to: destination)
        XCTAssertEqual(route.source, .appleMaps, "Missing Google keys must retain walking navigation")
        XCTAssertEqual(route.origin, GeoCoordinate(origin))
        XCTAssertEqual(route.destination, GeoCoordinate(destination))
        XCTAssertEqual(route.distanceMeters, 200)
        let cached = try await service.walkingRoute(from: origin, to: destination)
        XCTAssertEqual(cached, route)
        let calls = await apple.calls
        XCTAssertEqual(calls, 1, "The factory must keep the existing route cache")
    }
}

/// Offline fixture: assert factory selection without relying on Apple's live service or CI networking.
private actor AppleWalkingFallbackStub: DirectionsService {
    private(set) var calls = 0
    func walkingRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> WalkingRoute {
        calls += 1
        return WalkingRoute(origin: GeoCoordinate(origin), destination: GeoCoordinate(destination),
                            distanceMeters: 200, durationSeconds: 150,
                            routeCoordinates: [GeoCoordinate(origin), GeoCoordinate(destination)], source: .appleMaps)
    }
}
