import XCTest
@testable import TourCore

final class ARWalkingGuidanceTests: XCTestCase {
    private func turnRoute() -> WalkingRoute {
        let start = GeoCoordinate(latitude: 40.6503, longitude: -74.3012)
        let corner = GeoMath.destination(from: start, bearing: 0, distance: 100)
        let end = GeoMath.destination(from: corner, bearing: 90, distance: 80)
        return WalkingRoute(origin: start, destination: end, distanceMeters: 180, durationSeconds: 130,
                            routeCoordinates: [start, corner, end], routeSteps: [
                                RouteStep(distanceMeters: 100, durationSeconds: 70, startCoordinate: start, endCoordinate: corner,
                                          instruction: "Head north on Lincoln Ave E toward Davis St", maneuver: "DEPART"),
                                RouteStep(distanceMeters: 80, durationSeconds: 60, startCoordinate: corner, endCoordinate: end,
                                          instruction: "Turn right onto Davis St", maneuver: "TURN_RIGHT")
                            ], source: .googleRoutesAPI)
    }

    func testPreviewsNextTurnWithStreetAndDistanceAlongRoute() throws {
        let route = turnRoute()
        let position = GeoMath.destination(from: route.origin, bearing: 0, distance: 70)
        let progress = RouteProgressCalculator.progress(along: route, userLocation: position)
        let cue = try XCTUnwrap(ARWalkingGuidance.routeCue(route: route, progress: progress))
        XCTAssertEqual(cue.direction, .right)
        XCTAssertEqual(cue.streetLabel, "Davis St")
        XCTAssertEqual(cue.distanceMeters, 30, accuracy: 0.2)
        XCTAssertEqual(cue.distanceText, "100 ft")
        XCTAssertEqual(cue.coordinate, route.routeSteps[1].startCoordinate)
        XCTAssertTrue(cue.isNearTurn)
        XCTAssertEqual(ARWalkingGuidance.currentStreetLabel(route: route, progress: progress), "Lincoln Ave E")
        XCTAssertEqual(ARWalkingGuidance.direction(for: -90), .left, "Entry orientation uses camera facing, independently of the future right turn")
    }

    func testFloatingTurnIsNotShownFarFromIntersection() throws {
        let route = turnRoute()
        let progress = RouteProgressCalculator.progress(along: route, userLocation: route.origin)
        let cue = try XCTUnwrap(ARWalkingGuidance.routeCue(route: route, progress: progress))
        XCTAssertTrue(cue.isUpcomingTurn)
        XCTAssertFalse(cue.isNearTurn)
        XCTAssertEqual(cue.distanceMeters, 100, accuracy: 0.2)
        XCTAssertEqual(cue.distanceText, "330 ft")
    }

    func testPassingCornerRetiresOldTurnAndUsesNewStreet() throws {
        let route = turnRoute()
        let position = GeoMath.destination(from: route.routeSteps[1].startCoordinate, bearing: 90, distance: 15)
        let progress = RouteProgressCalculator.progress(along: route, userLocation: position)
        let cue = try XCTUnwrap(ARWalkingGuidance.routeCue(route: route, progress: progress))
        XCTAssertFalse(cue.isUpcomingTurn)
        XCTAssertFalse(cue.isNearTurn)
        XCTAssertEqual(cue.direction, .ahead)
        XCTAssertEqual(cue.streetLabel, "Davis St")
        XCTAssertEqual(cue.distanceMeters, 65, accuracy: 0.2)
        XCTAssertEqual(cue.distanceText, "210 ft")
    }

    func testTurnPreviewSkipsContinueStepsButCountsTheirDistances() throws {
        var route = turnRoute()
        var middle = route.routeSteps[0]
        middle.distanceMeters = 20
        middle.instruction = "Continue on Lincoln Ave E"
        middle.maneuver = "STRAIGHT"
        route.routeSteps[0].distanceMeters = 80
        route.routeSteps.insert(middle, at: 1)
        let progress = RouteProgressCalculator.progress(along: route, userLocation: route.origin)
        let cue = try XCTUnwrap(ARWalkingGuidance.routeCue(route: route, progress: progress))
        XCTAssertEqual(cue.stepIndex, 2)
        XCTAssertEqual(cue.distanceMeters, 100, accuracy: 0.2)
        XCTAssertEqual(cue.streetLabel, "Davis St")
    }

    func testMissingStreetAndLegacyManeuverDoNotInventAName() throws {
        var route = turnRoute()
        route.routeSteps[1].instruction = "Turn left"
        route.routeSteps[1].maneuver = nil
        let progress = RouteProgressCalculator.progress(along: route, userLocation: route.origin)
        let cue = try XCTUnwrap(ARWalkingGuidance.routeCue(route: route, progress: progress))
        XCTAssertEqual(cue.direction, .left)
        XCTAssertNil(cue.streetName)
        XCTAssertEqual(cue.streetLabel, "Next turn")
    }

    func testHeadTowardStreetDoesNotClaimUserIsAlreadyOnIt() throws {
        var route = turnRoute()
        route.routeSteps[0].instruction = "Head south toward Lincoln Ave E"
        let progress = RouteProgressCalculator.progress(along: route, userLocation: route.origin)
        XCTAssertEqual(ARWalkingGuidance.currentStreetLabel(route: route, progress: progress), "Toward Lincoln Ave E")
    }

    func testLegacyAndSlightTurnsKeepStreetSeparateFromArrivalNote() throws {
        var route = turnRoute()
        route.routeSteps[1].maneuver = "turn-left"
        route.routeSteps[1].instruction = "Turn left onto North Ave E\nDestination will be on the left"
        let progress = RouteProgressCalculator.progress(along: route, userLocation: route.origin)
        var cue = try XCTUnwrap(ARWalkingGuidance.routeCue(route: route, progress: progress))
        XCTAssertEqual(cue.direction, .left)
        XCTAssertEqual(cue.streetName, "North Ave E")
        route.routeSteps[1].maneuver = "TURN_SLIGHT_RIGHT"
        cue = try XCTUnwrap(ARWalkingGuidance.routeCue(route: route, progress: progress))
        XCTAssertEqual(cue.direction, .bearRight)
    }

    func testArrivalNoteIsNotUsedAsStreetName() {
        var route = turnRoute()
        route.routeSteps[0].instruction = "Your destination will be on the left"
        let progress = RouteProgressCalculator.progress(along: route, userLocation: route.origin)
        XCTAssertNil(ARWalkingGuidance.currentStreetLabel(route: route, progress: progress))
    }

    func testEstimateOffRouteAndMissingStepsCannotSupplyStreetTurnSigns() {
        var route = turnRoute()
        var progress = RouteProgressCalculator.progress(along: route, userLocation: route.origin)
        route.source = .straightLineEstimate
        XCTAssertNil(ARWalkingGuidance.routeCue(route: route, progress: progress))
        XCTAssertNil(ARWalkingGuidance.currentStreetLabel(route: route, progress: progress))
        route.source = .googleRoutesAPI
        progress.distanceFromRoute = 50
        XCTAssertNil(ARWalkingGuidance.routeCue(route: route, progress: progress))
        progress.distanceFromRoute = 0
        route.routeSteps = []
        XCTAssertNil(ARWalkingGuidance.routeCue(route: route, progress: progress))
    }

    func testFeetAlwaysRemainFeetAndHandleInvalidValues() {
        XCTAssertEqual(ARWalkingGuidance.feet(meters: 1000), "3280 ft")
        XCTAssertEqual(ARWalkingGuidance.feet(meters: 0), "0 ft")
        XCTAssertEqual(ARWalkingGuidance.feet(meters: 1), "10 ft")
        for invalid in [Double.nan, .infinity, -1] { XCTAssertEqual(ARWalkingGuidance.feet(meters: invalid), "—") }
    }

    func testAngularSmoothingCrossesNorthAndWrapWithoutSpinning() throws {
        let value = try XCTUnwrap(ARWalkingGuidance.smoothAngle(from: 179, to: -179, elapsed: 0.1))
        XCTAssertLessThan(abs(GeoMath.relativeBearing(heading: 179, bearing: value)), 2)
        XCTAssertGreaterThan(value, 179)
        let north = try XCTUnwrap(ARWalkingGuidance.smoothAngle(from: 359, to: 1, elapsed: 0.1))
        XCTAssertLessThan(abs(north), 1)
        XCTAssertEqual(ARWalkingGuidance.smoothAngle(from: 10, to: 90, elapsed: 0), 10)
        XCTAssertNil(ARWalkingGuidance.smoothAngle(from: 0, to: .nan, elapsed: 0.1))
    }

    func testAngularSmoothingConvergesAcrossDifferentFrameRates() throws {
        func filtered(hz: Int) throws -> Double {
            var value: Double? = 0
            for _ in 0..<hz { value = ARWalkingGuidance.smoothAngle(from: value, to: 90, elapsed: 1 / Double(hz)) }
            return try XCTUnwrap(value)
        }
        XCTAssertEqual(try filtered(hz: 10), try filtered(hz: 60), accuracy: 0.001)
        XCTAssertGreaterThan(try filtered(hz: 10), 88)
    }

    func testEntryOrientationStaysVisibleUntilSustainedAlignment() {
        var state = ARWalkingGuidance.OrientationState()
        XCTAssertTrue(state.update(relativeBearing: -90, timestamp: 0, isAtStop: false))
        XCTAssertTrue(state.update(relativeBearing: 0, timestamp: 0.5, isAtStop: false))
        XCTAssertTrue(state.update(relativeBearing: 0, timestamp: 1.8, isAtStop: false), "Entry cue must remain long enough to read")
        XCTAssertFalse(state.update(relativeBearing: 0, timestamp: 2.6, isAtStop: false))
    }

    func testLookingAwayRestoresOrientationWithHysteresis() {
        var state = ARWalkingGuidance.OrientationState()
        state.update(relativeBearing: 0, timestamp: 0, isAtStop: false)
        XCTAssertFalse(state.update(relativeBearing: 0, timestamp: 3, isAtStop: false))
        XCTAssertFalse(state.update(relativeBearing: 40, timestamp: 3.1, isAtStop: false))
        XCTAssertTrue(state.update(relativeBearing: 60, timestamp: 3.2, isAtStop: false))
        XCTAssertTrue(state.update(relativeBearing: 40, timestamp: 3.3, isAtStop: false))
        XCTAssertTrue(state.update(relativeBearing: 0, timestamp: 4, isAtStop: false))
        XCTAssertFalse(state.update(relativeBearing: 0, timestamp: 5.3, isAtStop: false))
    }

    func testUnknownCameraAsksForOrientationAndStopArrivalHidesIt() {
        var state = ARWalkingGuidance.OrientationState()
        XCTAssertTrue(state.update(relativeBearing: nil, timestamp: 0, isAtStop: false))
        XCTAssertFalse(state.update(relativeBearing: nil, timestamp: 1, isAtStop: true))
        state = ARWalkingGuidance.OrientationState()
        XCTAssertTrue(state.isPresented, "Continue to a new destination restores entry guidance")
        XCTAssertTrue(state.update(relativeBearing: .nan, timestamp: 2, isAtStop: false))
    }

    func testTurnAtCornerSaysNowInsteadOfZeroFeet() throws {
        let route = turnRoute()
        let progress = RouteProgressCalculator.progress(along: route, userLocation: route.routeSteps[1].startCoordinate)
        let cue = try XCTUnwrap(ARWalkingGuidance.routeCue(route: route, progress: progress))
        XCTAssertEqual(cue.instruction, "Turn right now")
    }

    func testCameraFacingChangesTheDirectionWithoutChangingTheDestination() throws {
        // The destination stays north. The visitor looks north, east, south and west.
        let cameras: [(Double, Double, Double)] = [(0, -1, 0), (1, 0, -90), (0, 1, -180), (-1, 0, 90)]
        for (x, z, expected) in cameras {
            let result = try XCTUnwrap(ARWalkingGuidance.relativeBearing(directionX: 0, directionZ: -1, cameraForwardX: x, cameraForwardZ: z))
            XCTAssertEqual(abs(result - expected).truncatingRemainder(dividingBy: 360), 0, accuracy: 0.001)
        }
    }

    func testRightAndLeftMatchScreenRotation() throws {
        for (x, expected) in [(1.0, 90.0), (-1.0, -90.0)] {
            let bearing = try XCTUnwrap(ARWalkingGuidance.relativeBearing(directionX: x, directionZ: 0, cameraForwardX: 0, cameraForwardZ: -1))
            XCTAssertEqual(bearing, expected, accuracy: 0.001)
        }
    }

    func testWorldAlignmentRotationDoesNotChangeCameraRelativeGuidance() throws {
        // Rotating both the AR world and camera 90 degrees preserves a right turn.
        let northWorld = try XCTUnwrap(ARWalkingGuidance.relativeBearing(directionX: 1, directionZ: 0, cameraForwardX: 0, cameraForwardZ: -1))
        let rotatedWorld = try XCTUnwrap(ARWalkingGuidance.relativeBearing(directionX: 0, directionZ: 1, cameraForwardX: 1, cameraForwardZ: 0))
        XCTAssertEqual(northWorld, rotatedWorld, accuracy: 0.001)
    }

    func testNorthWrapUsesTheShortTurn() throws {
        func vector(_ degrees: Double) -> (Double, Double) { (sin(degrees * .pi / 180), -cos(degrees * .pi / 180)) }
        let destination = vector(1), camera = vector(359)
        let result = try XCTUnwrap(ARWalkingGuidance.relativeBearing(directionX: destination.0, directionZ: destination.1, cameraForwardX: camera.0, cameraForwardZ: camera.1))
        XCTAssertEqual(result, 2, accuracy: 0.001)
    }

    func testHorizontalProjectionWorksWhenPhoneIsTilted() throws {
        let result = try XCTUnwrap(ARWalkingGuidance.relativeBearing(directionX: 10, directionZ: 0, cameraForwardX: 0, cameraForwardZ: -0.4))
        XCTAssertEqual(result, 90, accuracy: 0.001)
    }

    func testVerticalCameraAndZeroDirectionAreUnavailable() {
        XCTAssertNil(ARWalkingGuidance.relativeBearing(directionX: 0, directionZ: -1, cameraForwardX: 0, cameraForwardZ: 0.1))
        XCTAssertNil(ARWalkingGuidance.relativeBearing(directionX: 0, directionZ: 0, cameraForwardX: 0, cameraForwardZ: -1))
    }

    func testInvalidVectorsNeverBecomeAnArrow() {
        for invalid in [Double.nan, .infinity, -.infinity] {
            XCTAssertNil(ARWalkingGuidance.relativeBearing(directionX: invalid, directionZ: -1, cameraForwardX: 0, cameraForwardZ: -1))
            XCTAssertNil(ARWalkingGuidance.relativeBearing(directionX: 0, directionZ: -1, cameraForwardX: 0, cameraForwardZ: invalid))
        }
    }

    func testInstructionsAndUnknownFacingArePlainLanguage() {
        for (angle, message) in [(0.0, "Walk ahead"), (35, "Bear right"), (-35, "Bear left"), (90, "Turn right"), (-90, "Turn left"), (170, "Turn around")] {
            XCTAssertEqual(ARWalkingGuidance.instruction(for: angle), message)
        }
        XCTAssertEqual(ARWalkingGuidance.instruction(for: nil), "Hold your phone up and look around")
        XCTAssertEqual(ARWalkingGuidance.instruction(for: .nan), "Hold your phone up and look around")
    }
}
