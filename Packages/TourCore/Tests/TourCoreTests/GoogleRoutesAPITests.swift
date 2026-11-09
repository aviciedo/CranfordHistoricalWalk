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
        XCTAssertNil(GoogleRoutesAPI.seconds(fromDuration: nil))
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

    func testDurationFallsBackAndGeometryLessRoutesAreRejected() throws {
        let polyline = "ipkcFfichVnP@j@B"
        let staticOnly = """
        {"routes":[{"distanceMeters":120,"staticDuration":"90s","polyline":{"encodedPolyline":"\(polyline)"}}]}
        """.data(using: .utf8)!
        XCTAssertEqual(try GoogleRoutesAPI.walkingRoute(from: staticOnly, origin: origin, destination: destination).durationSeconds, 90)

        let stepsOnly = """
        {"routes":[{"distanceMeters":120,"polyline":{"encodedPolyline":"\(polyline)"},"legs":[{"steps":[
          {"distanceMeters":40,"staticDuration":"30s","startLocation":{"latLng":{"latitude":1,"longitude":2}},"endLocation":{"latLng":{"latitude":1.001,"longitude":2}}},
          {"distanceMeters":80,"staticDuration":"50s","polyline":{"encodedPolyline":"\(polyline)"}}
        ]}]}]}
        """.data(using: .utf8)!
        let stepped = try GoogleRoutesAPI.walkingRoute(from: stepsOnly, origin: origin, destination: destination)
        XCTAssertEqual(stepped.durationSeconds, 80)
        XCTAssertEqual(stepped.routeSteps.count, 2)

        let pace = """
        {"routes":[{"distanceMeters":140,"polyline":{"encodedPolyline":"\(polyline)"}}]}
        """.data(using: .utf8)!
        let estimated = try GoogleRoutesAPI.walkingRoute(from: pace, origin: origin, destination: destination)
        XCTAssertEqual(estimated.durationSeconds, 140 / WalkingRoute.defaultWalkingSpeed, accuracy: 0.0001)

        let shapeless = #"{"routes":[{"distanceMeters":10,"duration":"8s","polyline":{"encodedPolyline":""}}]}"#.data(using: .utf8)!
        XCTAssertThrowsError(try GoogleRoutesAPI.walkingRoute(from: shapeless, origin: origin, destination: destination)) { error in
            XCTAssertEqual(error as? GoogleRoutesAPI.ParseError, .missingGeometry)
        }
    }

    func testAPIErrorEnvelopeWinsOverAPartialRoute() {
        let json = #"{"error":{"code":403,"message":"blocked","status":"PERMISSION_DENIED"},"routes":[{"distanceMeters":10,"duration":"8s","polyline":{"encodedPolyline":"ipkcFfichVnP@j@B"}}]}"#.data(using: .utf8)!
        XCTAssertThrowsError(try GoogleRoutesAPI.walkingRoute(from: json, origin: origin, destination: destination)) { error in
            XCTAssertEqual(error as? GoogleRoutesAPI.ParseError, .api(code: 403, status: "PERMISSION_DENIED", message: "blocked"))
        }
    }

    func testLegacyMarkupDoesNotLeakIntoWalkingInstructions() throws {
        let json = """
        {"status":"OK","routes":[{"overview_polyline":{"points":"ipkcFfichVnP@j@B"},"legs":[{"distance":{"value":120},"duration":{"value":90},"steps":[
          {"distance":{"value":120},"duration":{"value":90},"start_location":{"lat":37.42,"lng":-122.08},"end_location":{"lat":37.41,"lng":-122.07},
           "html_instructions":"Turn <b>left</b> onto <b>North Ave E</b><div style=\\"font-size:0.9em\\">Destination will be on the right</div>",
           "maneuver":"turn-left"}]}]}]}
        """.data(using: .utf8)!
        let instruction = try XCTUnwrap(try GoogleDirectionsLegacyAPI.walkingRoute(from: json, origin: origin, destination: destination).routeSteps.first?.instruction)
        XCTAssertFalse(instruction.contains("<"))
        XCTAssertFalse(instruction.contains(">"))
        XCTAssertEqual(instruction, "Turn left onto North Ave E Destination will be on the right")
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
        let data = #"{"status":"REQUEST_DENIED","error_message":"This API project is not authorized","routes":[]}"#.data(using: .utf8)!
        XCTAssertThrowsError(try GoogleDirectionsLegacyAPI.walkingRoute(from: data, origin: origin, destination: destination)) { error in
            XCTAssertEqual(error as? GoogleDirectionsLegacyAPI.ParseError, .status("REQUEST_DENIED", message: "This API project is not authorized"))
        }
    }
}
