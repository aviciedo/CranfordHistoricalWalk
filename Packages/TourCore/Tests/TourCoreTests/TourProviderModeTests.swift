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

    func testLaunchModeRejectsBlankAndMismatchedStoredValues() {
        for stored in ["", " ", "GoogleOnly", "googleOnly ", "APPLEONLY"] {
            XCTAssertEqual(TourProviderMode.launchMode(storedValue: stored, developerEnabled: true), .automatic, stored)
        }
    }

    func testProviderModeDecidesConsentAndGoogleMapsInitialization() {
        XCTAssertFalse(TourProviderMode.appleOnly.requestsARCoreGeospatial(plistEnabled: true))
        XCTAssertFalse(TourProviderMode.appleOnly.requestsARCoreGeospatial(plistEnabled: false))
        XCTAssertFalse(TourProviderMode.appleOnly.initializesGoogleMapsSDK)
        XCTAssertTrue(TourProviderMode.googleOnly.requestsARCoreGeospatial(plistEnabled: false))
        XCTAssertTrue(TourProviderMode.googleOnly.requestsARCoreGeospatial(plistEnabled: true))
        XCTAssertTrue(TourProviderMode.googleOnly.initializesGoogleMapsSDK)
        XCTAssertEqual(TourProviderMode.automatic.requestsARCoreGeospatial(plistEnabled: true), true)
        XCTAssertEqual(TourProviderMode.automatic.requestsARCoreGeospatial(plistEnabled: false), false)
        XCTAssertTrue(TourProviderMode.automatic.initializesGoogleMapsSDK)
    }

    func testWalkingDirectionsNeverCrossStrictBoundaries() {
        let cases: [(TourProviderMode, Bool, Bool, TourProviderMode.WalkingDirectionsPlan)] = [
            (.appleOnly, true, true, .apple),
            (.appleOnly, false, false, .apple),
            (.appleOnly, true, false, .apple),
            (.googleOnly, true, false, .googleOnly),
            (.googleOnly, true, true, .googleOnly),
            (.googleOnly, false, true, .googleUnavailable),
            (.googleOnly, false, false, .googleUnavailable),
            (.automatic, true, true, .googleWithAppleFallback),
            (.automatic, true, false, .apple),
            (.automatic, false, true, .apple),
            (.automatic, false, false, .apple),
        ]
        for (mode, routes, maps, plan) in cases {
            XCTAssertEqual(mode.walkingDirectionsPlan(hasRoutesKey: routes, hasMapsKey: maps), plan,
                           "\(mode.rawValue) routes=\(routes) maps=\(maps)")
        }
        XCTAssertEqual(TourProviderMode.googleOnlyDirectionsUnavailable,
                       "Google-only walking directions require a valid Routes API key. Apple fallback is disabled.")
    }

    func testMapAndRouteLabelsDoNotCallAnEstimateApple() {
        XCTAssertEqual(TourProviderMode.googleOnly.mapBackendTitle(googleConfigured: false),
                       "Google unavailable; fallback disabled")
        XCTAssertEqual(TourProviderMode.googleOnly.mapBackendTitle(googleConfigured: true), "Google Maps")
        XCTAssertEqual(TourProviderMode.appleOnly.mapBackendTitle(googleConfigured: true), "Apple Maps")
        XCTAssertEqual(TourProviderMode.automatic.mapBackendTitle(googleConfigured: false), "Apple Maps")
        XCTAssertEqual(RouteSource.developerLabel(for: nil), "No route requested")
        XCTAssertEqual(RouteSource.googleRoutesAPI.developerLabel, "Google Routes API")
        XCTAssertEqual(RouteSource.googleDirectionsLegacy.developerLabel, "Google Directions (legacy)")
        XCTAssertEqual(RouteSource.appleMaps.developerLabel, "Apple Maps")
        XCTAssertEqual(RouteSource.straightLineEstimate.developerLabel, "Distance estimate — no walking route")
        XCTAssertEqual(RouteSource.simulated.developerLabel, "Practice route")
        XCTAssertFalse(RouteSource.straightLineEstimate.developerLabel.contains("Apple"))
    }

    func testStrictGoogleHUDKeepsPlaqueCopyAndUsableFixesAheadOfFailures() throws {
        XCTAssertEqual(TourProviderMode.strictGoogleARStatus(
            isPlaqueScanner: true, allowsNativeFallback: false, isUsable: false,
            navigationNotice: nil, coverageMessage: nil, fallbackReason: .missingUserConsent,
            failureMessage: "camera failed", interruptionMessage: nil), .passthrough)
        XCTAssertEqual(TourProviderMode.strictGoogleARStatus(
            isPlaqueScanner: false, allowsNativeFallback: true, isUsable: false,
            navigationNotice: nil, coverageMessage: nil, fallbackReason: .missingUserConsent,
            failureMessage: nil, interruptionMessage: nil), .passthrough)

        XCTAssertEqual(TourProviderMode.strictGoogleARStatus(
            isPlaqueScanner: false, allowsNativeFallback: false, isUsable: true,
            navigationNotice: "Turn toward the route to see the arrows.",
            coverageMessage: "coverage", fallbackReason: .localizationTimedOut,
            failureMessage: "failed", interruptionMessage: "paused"),
            .text("Turn toward the route to see the arrows."))
        let coverage = try XCTUnwrap(VPSCoverage.unavailable.userMessage)
        XCTAssertEqual(TourProviderMode.strictGoogleARStatus(
            isPlaqueScanner: false, allowsNativeFallback: false, isUsable: true,
            navigationNotice: nil, coverageMessage: coverage,
            fallbackReason: .networkUnavailable, failureMessage: nil, interruptionMessage: nil),
            .text(coverage))
        XCTAssertEqual(TourProviderMode.strictGoogleARStatus(
            isPlaqueScanner: false, allowsNativeFallback: false, isUsable: true,
            navigationNotice: nil, coverageMessage: nil, fallbackReason: .missingAPIKey,
            failureMessage: "failed", interruptionMessage: nil), .suppressed)

        let unavailable = TourProviderMode.strictGoogleARStatus(
            isPlaqueScanner: false, allowsNativeFallback: false, isUsable: false,
            navigationNotice: "ignored", coverageMessage: "ignored", fallbackReason: .missingUserConsent,
            failureMessage: "Geospatial localization did not become ready.",
            interruptionMessage: "AR paused. Return to the app to continue.")
        XCTAssertEqual(unavailable, .text("Google-only AR is unavailable (missingUserConsent). Check ARCore setup, consent and location. Apple positioning fallback is disabled."))
        XCTAssertEqual(TourProviderMode.developerGoogleOnlyUnavailable(.missingUserConsent),
                       "Google-only AR unavailable (missingUserConsent); Apple positioning fallback is disabled.")

        XCTAssertEqual(TourProviderMode.strictGoogleARStatus(
            isPlaqueScanner: false, allowsNativeFallback: false, isUsable: false,
            navigationNotice: nil, coverageMessage: nil, fallbackReason: nil,
            failureMessage: "ARCore could not start.", interruptionMessage: "AR paused. Return to the app to continue."),
            .text("ARCore could not start."))
        XCTAssertEqual(TourProviderMode.strictGoogleARStatus(
            isPlaqueScanner: false, allowsNativeFallback: false, isUsable: false,
            navigationNotice: nil, coverageMessage: nil, fallbackReason: nil,
            failureMessage: nil, interruptionMessage: "AR paused. Return to the app to continue."),
            .text("AR paused. Return to the app to continue."))
        XCTAssertEqual(TourProviderMode.strictGoogleARStatus(
            isPlaqueScanner: false, allowsNativeFallback: false, isUsable: false,
            navigationNotice: nil, coverageMessage: nil, fallbackReason: nil,
            failureMessage: nil, interruptionMessage: nil),
            .text("Google-only AR is waiting for localization. Apple positioning fallback is disabled."))
    }
}
