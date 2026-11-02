import CoreLocation
import XCTest
import TourCore
@testable import CranfordHistoricalAR

final class AppConfigurationTests: XCTestCase {
    @MainActor
    func testProviderModesChooseIndependentRouteServicesAndRespectStrictFailures() async throws {
        let origin = CLLocationCoordinate2D(latitude: 40.65, longitude: -74.3)
        let end = CLLocationCoordinate2D(latitude: 40.66, longitude: -74.3)
        var configuration = AppConfiguration.empty
        configuration.googleMapsAPIKey = "test-maps-key"
        configuration.googleRoutesAPIKey = "test-routes-key"
        let google = ProviderRouteStub(source: .googleRoutesAPI, fails: true)
        let apple = ProviderRouteStub(source: .appleMaps)
        let appleOnly = DirectionsServiceFactory.make(configuration: configuration, apple: apple,
            mode: .appleOnly, google: google)
        let appleRoute = try await appleOnly.walkingRoute(from: origin, to: end)
        XCTAssertEqual(appleRoute.source, .appleMaps)
        let googleCalls = await google.calls
        XCTAssertEqual(googleCalls, 0, "Apple-only must never invoke Google routing")
        let strict = DirectionsServiceFactory.make(configuration: configuration, apple: apple,
            mode: .googleOnly, google: google)
        do { _ = try await strict.walkingRoute(from: origin, to: end); XCTFail("Strict Google must expose its error") }
        catch { XCTAssertEqual(error as? DirectionsError, .noRoute) }
        let appleCalls = await apple.calls
        XCTAssertEqual(appleCalls, 1, "Strict Google must not invoke Apple on failure")
        let automatic = DirectionsServiceFactory.make(configuration: configuration, apple: apple,
            mode: .automatic, google: google)
        let recovered = try await automatic.walkingRoute(from: origin, to: end)
        XCTAssertEqual(recovered.source, .appleMaps)
        let recoveredCalls = await apple.calls
        XCTAssertEqual(recoveredCalls, 2)
    }

    @MainActor
    func testStrictGoogleRoutesNeedNoMapKeyButDoRequireRoutesCredentials() async throws {
        let origin = CLLocationCoordinate2D(latitude: 40.65, longitude: -74.3)
        let end = CLLocationCoordinate2D(latitude: 40.66, longitude: -74.3)
        let apple = ProviderRouteStub(source: .appleMaps)
        let google = ProviderRouteStub(source: .googleRoutesAPI)
        var configuration = AppConfiguration.empty
        configuration.googleRoutesAPIKey = "test-routes-key"
        let strict = DirectionsServiceFactory.make(configuration: configuration, apple: apple,
            mode: .googleOnly, google: google)
        let route = try await strict.walkingRoute(from: origin, to: end)
        XCTAssertEqual(route.source, .googleRoutesAPI)
        let missing = DirectionsServiceFactory.make(configuration: .empty, apple: apple,
            mode: .googleOnly, google: google)
        do { _ = try await missing.walkingRoute(from: origin, to: end); XCTFail("Missing Google credentials must be explicit") }
        catch { XCTAssertEqual(error as? DirectionsError, .googleOnlyUnavailable) }
        let appleCalls = await apple.calls
        XCTAssertEqual(appleCalls, 0)
    }

    #if DEBUG
    func testProviderSelectionPersistsWithoutClearingVisitData() {
        let suite = "provider-testing-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("saved visit sentinel", forKey: "existing-visits")
        XCTAssertEqual(DeveloperProviderSettings.load(defaults: defaults), .automatic)
        DeveloperProviderSettings.save(.appleOnly, defaults: defaults)
        XCTAssertEqual(DeveloperProviderSettings.load(defaults: defaults), .appleOnly)
        DeveloperProviderSettings.save(.googleOnly, defaults: defaults)
        XCTAssertEqual(DeveloperProviderSettings.load(defaults: defaults), .googleOnly)
        XCTAssertEqual(defaults.string(forKey: "existing-visits"), "saved visit sentinel")
        defaults.set("invalid", forKey: DeveloperProviderSettings.key)
        XCTAssertEqual(DeveloperProviderSettings.load(defaults: defaults), .automatic)
    }
    #endif

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

private actor ProviderRouteStub: DirectionsService {
    let source: RouteSource
    var fails = false
    private(set) var calls = 0
    init(source: RouteSource, fails: Bool = false) { self.source = source; self.fails = fails }
    func walkingRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> WalkingRoute {
        calls += 1
        if fails { throw DirectionsError.noRoute }
        return WalkingRoute(origin: GeoCoordinate(origin), destination: GeoCoordinate(destination),
            distanceMeters: 200, durationSeconds: 150,
            routeCoordinates: [GeoCoordinate(origin), GeoCoordinate(destination)], source: source)
    }
}
