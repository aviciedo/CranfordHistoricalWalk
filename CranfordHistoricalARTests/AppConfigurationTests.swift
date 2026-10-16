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
    func testDirectionsFactoryFallsBackWhenKeyMissing() async {
        let service = DirectionsServiceFactory.make(configuration: .empty)
        let origin = CLLocationCoordinate2D(latitude: 40.6565, longitude: -74.3040)
        let destination = CLLocationCoordinate2D(latitude: 40.6580, longitude: -74.3005)
        do {
            _ = try await service.walkingRoute(from: origin, to: destination)
            XCTFail("A missing key must surface as DirectionsError.missingAPIKey so the view model can label the estimate")
        } catch let error as DirectionsError {
            XCTAssertEqual(error, .missingAPIKey)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
