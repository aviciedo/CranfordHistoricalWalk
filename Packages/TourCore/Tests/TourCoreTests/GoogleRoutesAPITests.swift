import XCTest
@testable import TourCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class GoogleRoutesAPITests: XCTestCase {
    let origin = GeoCoordinate(latitude: 37.4197318, longitude: -122.0827887)
    let destination = GeoCoordinate(latitude: 37.4176670, longitude: -122.0795950)

    func testRequestBodyMatchesRoutesAPIShape() throws {
        let request = GoogleRoutesAPI.Request(origin: origin, destination: destination)
        let json = try JSONSerialization.jsonObject(with: request.encoded()) as! [String: Any]
        XCTAssertEqual(json["travelMode"] as? String, "WALK")
        XCTAssertNil(json["routingPreference"], "routingPreference must be omitted for WALK")
        let o = json["origin"] as! [String: Any]
        let latLng = (o["location"] as! [String: Any])["latLng"] as! [String: Any]
        XCTAssertEqual(latLng["latitude"] as! Double, origin.latitude, accuracy: 1e-9)
        XCTAssertEqual(json["computeAlternativeRoutes"] as? Bool, false)
        XCTAssertEqual(json["polylineQuality"] as? String, "HIGH_QUALITY")
    }

    func testRequestAlwaysSendsNonEmptyIOSBundleIdentifier() throws {
        let empty = try GoogleRoutesAPI.makeURLRequest(apiKey: "AIzaTest", bundleIdentifier: "", origin: origin, destination: destination)
        XCTAssertEqual(empty.value(forHTTPHeaderField: GoogleAPIClientIdentity.iosBundleIdentifierHeader), "com.cranford.historicalar")
        let unexpanded = try GoogleRoutesAPI.makeURLRequest(apiKey: "AIzaTest", bundleIdentifier: "$(PRODUCT_BUNDLE_IDENTIFIER)", origin: origin, destination: destination)
        XCTAssertEqual(unexpanded.value(forHTTPHeaderField: GoogleAPIClientIdentity.iosBundleIdentifierHeader), "com.cranford.historicalar")
        let custom = try GoogleRoutesAPI.makeURLRequest(apiKey: "AIzaTest", bundleIdentifier: " com.cranford.historicalar ", origin: origin, destination: destination)
        XCTAssertEqual(custom.value(forHTTPHeaderField: GoogleAPIClientIdentity.iosBundleIdentifierHeader), "com.cranford.historicalar")
        XCTAssertEqual(custom.httpMethod, "POST")
        XCTAssertEqual(custom.value(forHTTPHeaderField: "X-Goog-Api-Key"), "AIzaTest")
    }

    func testBlockedEmptyBundleErrorIsActionable() {
        let message = GoogleAPIClientIdentity.userFacingRoutesError(
            code: 403,
            status: "PERMISSION_DENIED",
            message: "Requests from this iOS client application <empty> are blocked."
        )
        XCTAssertTrue(message.contains("com.cranford.historicalar"))
        XCTAssertTrue(message.lowercased().contains("routes api"))
        XCTAssertFalse(message.contains("<empty>"), "Do not echo Google's empty-client wording as the only hint")
        XCTAssertTrue(GoogleAPIClientIdentity.isBlockedClientMessage("Requests from this iOS client application <empty> are blocked."))
        XCTAssertEqual(GoogleAPIClientIdentity.resolvedIOSBundleIdentifier(nil), "com.cranford.historicalar")
        XCTAssertEqual(GoogleAPIClientIdentity.resolvedIOSBundleIdentifier("  "), "com.cranford.historicalar")
    }

    func testDisabledRoutesAPIErrorMentionsEnablement() {
        let message = GoogleAPIClientIdentity.userFacingRoutesError(
            code: 403,
            status: "PERMISSION_DENIED",
            message: "Routes API has not been used in project 123 before or it is disabled."
        )
        XCTAssertTrue(message.lowercased().contains("enable"))
        XCTAssertTrue(message.contains("com.cranford.historicalar"))
    }

    func testFieldMaskContainsEssentials() {
        for required in ["routes.distanceMeters", "routes.duration", "routes.polyline.encodedPolyline", "routes.legs.steps.navigationInstruction"] {
            XCTAssertTrue(GoogleRoutesAPI.fieldMask.contains(required), required)
        }
        XCTAssertFalse(GoogleRoutesAPI.fieldMask.contains(" "))
    }

    func testDurationParsing() {
        XCTAssertEqual(GoogleRoutesAPI.seconds(fromDuration: "165s"), 165)
        XCTAssertEqual(GoogleRoutesAPI.seconds(fromDuration: "3.5s"), 3.5)
        XCTAssertEqual(GoogleRoutesAPI.seconds(fromDuration: "165.25s"), 165.25)
        XCTAssertNil(GoogleRoutesAPI.seconds(fromDuration: nil))
        XCTAssertNil(GoogleRoutesAPI.seconds(fromDuration: ""))
        XCTAssertNil(GoogleRoutesAPI.seconds(fromDuration: "s"))
        XCTAssertNil(GoogleRoutesAPI.seconds(fromDuration: "abc"))
    }

    func testParsesWalkingResponse() throws {
        let route = try GoogleRoutesAPI.walkingRoute(from: Fixtures.data("routes_api_walk_response"), origin: origin, destination: destination)
        XCTAssertEqual(route.source, .googleRoutesAPI)
        XCTAssertEqual(route.distanceMeters, 772)
        XCTAssertEqual(route.durationSeconds, 555)
        XCTAssertGreaterThanOrEqual(route.routeCoordinates.count, 3)
        XCTAssertEqual(route.routeCoordinates.first!.latitude, 37.41973, accuracy: 1e-4)
        XCTAssertEqual(route.routeSteps.count, 2)
        XCTAssertEqual(route.routeSteps[0].maneuver, "DEPART")
        XCTAssertEqual(route.routeSteps[1].instruction, "Turn left onto Charleston Rd")
        XCTAssertEqual(route.routeSteps[1].distanceMeters, 652)
        XCTAssertEqual(route.routeSteps[1].durationSeconds, 469)
        XCTAssertFalse(route.routeSteps[1].coordinates.isEmpty)
        XCTAssertEqual(route.origin, origin)
        XCTAssertEqual(route.destination, destination)
    }

    func testSurfacesAPIErrorEnvelope() throws {
        XCTAssertThrowsError(try GoogleRoutesAPI.walkingRoute(from: Fixtures.data("routes_api_error_response"), origin: origin, destination: destination)) { error in
            guard case GoogleRoutesAPI.ParseError.api(let code, let status, _) = error else { return XCTFail("\(error)") }
            XCTAssertEqual(code, 403)
            XCTAssertEqual(status, "PERMISSION_DENIED")
        }
    }

    func testEmptyRoutesIsAnError() {
        let data = #"{"routes": []}"#.data(using: .utf8)!
        XCTAssertThrowsError(try GoogleRoutesAPI.walkingRoute(from: data, origin: origin, destination: destination)) { error in
            XCTAssertEqual(error as? GoogleRoutesAPI.ParseError, .noRoutes)
        }
        let empty = "{}".data(using: .utf8)!
        XCTAssertThrowsError(try GoogleRoutesAPI.walkingRoute(from: empty, origin: origin, destination: destination))
    }

    func testMissingDurationFallsBackWithoutInventingAZeroMinuteWalk() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let polyline = "ipkcFfichVnP@j@B"
        let staticOnly = """
        {"routes":[{"distanceMeters":140,"staticDuration":"100s","polyline":{"encodedPolyline":"\(polyline)"}}]}
        """.data(using: .utf8)!
        let fromStatic = try GoogleRoutesAPI.walkingRoute(from: staticOnly, origin: origin, destination: destination, now: now)
        XCTAssertEqual(fromStatic.durationSeconds, 100)
        XCTAssertEqual(fromStatic.distanceMeters, 140)
        XCTAssertEqual(fromStatic.computedAt, now)

        let neither = """
        {"routes":[{"distanceMeters":140,"polyline":{"encodedPolyline":"\(polyline)"}}]}
        """.data(using: .utf8)!
        let paced = try GoogleRoutesAPI.walkingRoute(from: neither, origin: origin, destination: destination, now: now)
        XCTAssertEqual(paced.durationSeconds, 140 / WalkingRoute.defaultWalkingSpeed, accuracy: 0.001)

        let zero = """
        {"routes":[{"distanceMeters":140,"duration":"0s","polyline":{"encodedPolyline":"\(polyline)"}}]}
        """.data(using: .utf8)!
        let zeroDuration = try GoogleRoutesAPI.walkingRoute(from: zero, origin: origin, destination: destination, now: now)
        XCTAssertEqual(zeroDuration.durationSeconds, 140 / WalkingRoute.defaultWalkingSpeed, accuracy: 0.001)
    }

    func testRouteWithoutUsableGeometryIsMissingGeometry() {
        let onePoint = #"{"routes":[{"distanceMeters":10,"duration":"8s","polyline":{"encodedPolyline":"_p~iF~ps|U"}}]}"#.data(using: .utf8)!
        XCTAssertThrowsError(try GoogleRoutesAPI.walkingRoute(from: onePoint, origin: origin, destination: destination)) { error in
            XCTAssertEqual(error as? GoogleRoutesAPI.ParseError, .missingGeometry)
        }
        let stepWithoutLocations = #"{"routes":[{"legs":[{"steps":[{"distanceMeters":12,"staticDuration":"9s"}]}]}]}"#.data(using: .utf8)!
        XCTAssertThrowsError(try GoogleRoutesAPI.walkingRoute(from: stepWithoutLocations, origin: origin, destination: destination)) { error in
            XCTAssertEqual(error as? GoogleRoutesAPI.ParseError, .missingGeometry)
        }
    }

    func testDistanceComesFromStepsWhenTheRouteOmitsIt() throws {
        let json = """
        {"routes":[{"duration":"86s","legs":[{"steps":[{"staticDuration":"86s","polyline":{"encodedPolyline":"ipkcFfichVnP@j@B"},"startLocation":{"latLng":{"latitude":37.42,"longitude":-122.08}},"endLocation":{"latLng":{"latitude":37.41,"longitude":-122.07}}}]}]}]}
        """.data(using: .utf8)!
        let route = try GoogleRoutesAPI.walkingRoute(from: json, origin: origin, destination: destination)
        let expected = GeoMath.distance(
            from: GeoCoordinate(latitude: 37.42, longitude: -122.08),
            to: GeoCoordinate(latitude: 37.41, longitude: -122.07)
        )
        XCTAssertEqual(route.distanceMeters, expected, accuracy: 0.01)
        XCTAssertEqual(route.durationSeconds, 86)
        XCTAssertEqual(route.routeSteps.count, 1)
        XCTAssertGreaterThanOrEqual(route.routeCoordinates.count, 2)
    }

    func testMalformedPayloadIsNotANoRoute() {
        XCTAssertThrowsError(try GoogleRoutesAPI.walkingRoute(from: Data("not-json".utf8), origin: origin, destination: destination)) { error in
            XCTAssertFalse(error is GoogleRoutesAPI.ParseError)
        }
    }

    func testFallsBackToStepGeometryWhenOverviewMissing() throws {
        let json = """
        {"routes":[{"distanceMeters":120,"duration":"86s","legs":[{"steps":[{"distanceMeters":120,"staticDuration":"86s","polyline":{"encodedPolyline":"ipkcFfichVnP@j@B"}}]}]}]}
        """.data(using: .utf8)!
        let route = try GoogleRoutesAPI.walkingRoute(from: json, origin: origin, destination: destination)
        XCTAssertGreaterThanOrEqual(route.routeCoordinates.count, 2)
        XCTAssertEqual(route.routeSteps.count, 1)
    }

    func testLegacyDirectionsParsing() throws {
        let route = try GoogleDirectionsLegacyAPI.walkingRoute(from: Fixtures.data("directions_legacy_walk_response"), origin: origin, destination: destination)
        XCTAssertEqual(route.source, .googleDirectionsLegacy)
        XCTAssertEqual(route.distanceMeters, 772)
        XCTAssertEqual(route.durationSeconds, 555)
        XCTAssertEqual(route.routeSteps.count, 2)
        XCTAssertEqual(route.routeSteps[0].instruction, "Head south on Amphitheatre Pkwy")
        XCTAssertEqual(route.routeSteps[1].maneuver, "turn-left")
    }

    func testLegacyStatusErrors() {
        let denied = #"{"status":"REQUEST_DENIED","error_message":"This API project is not authorized","routes":[]}"#.data(using: .utf8)!
        XCTAssertThrowsError(try GoogleDirectionsLegacyAPI.walkingRoute(from: denied, origin: origin, destination: destination)) { error in
            XCTAssertEqual(error as? GoogleDirectionsLegacyAPI.ParseError, .status("REQUEST_DENIED", message: "This API project is not authorized"))
        }
        let none = #"{"status":"ZERO_RESULTS","routes":[]}"#.data(using: .utf8)!
        XCTAssertThrowsError(try GoogleDirectionsLegacyAPI.walkingRoute(from: none, origin: origin, destination: destination)) { error in
            XCTAssertEqual(error as? GoogleDirectionsLegacyAPI.ParseError, .status("ZERO_RESULTS", message: nil))
        }
    }

    func testLegacyHTMLInstructionsDoNotLeakTags() {
        XCTAssertEqual(
            "Turn <b>left</b> onto <div style=\"font-size:0.9em\">Main St</div>".strippingHTMLTags(),
            "Turn left onto Main St"
        )
        XCTAssertEqual("Head <b north".strippingHTMLTags(), "Head")
        XCTAssertEqual("  Keep   straight  ".strippingHTMLTags(), "Keep straight")
    }

    func testRefusalWithoutAMessageNamesTheStatusAndBundle() {
        let message = GoogleAPIClientIdentity.userFacingRoutesError(
            code: 403,
            status: "PERMISSION_DENIED",
            message: nil,
            bundleIdentifier: "  "
        )
        XCTAssertTrue(message.contains("HTTP 403"))
        XCTAssertTrue(message.contains("PERMISSION_DENIED"))
        XCTAssertTrue(message.contains("com.cranford.historicalar"))
        XCTAssertFalse(message.contains("AIza"))

        XCTAssertEqual(
            GoogleAPIClientIdentity.userFacingRoutesError(code: 400, status: "INVALID_ARGUMENT", message: "Waypoint is invalid."),
            "Waypoint is invalid."
        )
        let disabled = GoogleAPIClientIdentity.userFacingRoutesError(code: nil, status: "PERMISSION_DENIED", message: "SERVICE_DISABLED")
        XCTAssertTrue(disabled.lowercased().contains("enable"))
        XCTAssertFalse(GoogleAPIClientIdentity.isBlockedClientMessage(nil))
        XCTAssertFalse(GoogleAPIClientIdentity.isBlockedClientMessage("quota exceeded"))
    }
}
