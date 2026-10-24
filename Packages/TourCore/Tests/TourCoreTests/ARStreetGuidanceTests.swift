import XCTest
@testable import TourCore

final class ARStreetGuidanceTests: XCTestCase {
    private let ahead = ARStreetGuidance.Instruction(direction: .ahead, streetName: "Springfield Ave")
    private let right = ARStreetGuidance.Instruction(direction: .right, streetName: "Lincoln Ave E")

    func testEntirePoseRemainsPinnedDespiteGPSGroundAndPhoneMovementNoise() throws {
        var state = ARStreetGuidance.AnchorState()
        let original = try XCTUnwrap(state.update(candidate: [0, 0, -8], camera: .zero,
                                                 instruction: right, timestamp: 0))
        for i in 1...50 {
            let t = Double(i) / 10
            // Candidate can drift radically with compass/GPS; camera translation remains small.
            let pose = state.update(candidate: [t, 0.04 * t, -8 - t], camera: [0.3, 1.5, -1],
                                    instruction: right, timestamp: t)
            XCTAssertEqual(pose, original, "Position, yaw, direction and label must all stay fixed")
        }
    }

    func testFiveMetresOfTranslationRepositionsOnceAndPinsAgain() throws {
        var state = ARStreetGuidance.AnchorState()
        let original = try XCTUnwrap(state.update(candidate: [0, 0, -8], camera: .zero, instruction: right, timestamp: 0))
        XCTAssertEqual(state.update(candidate: [0, 0, -12], camera: [0, 2, -4.9], instruction: right, timestamp: 0.5), original)
        let next = try XCTUnwrap(state.update(candidate: [0, 0.1, -13], camera: [0, 2, -5], instruction: right, timestamp: 1))
        XCTAssertEqual(next.position, [0, 0.1, -13])
        XCTAssertEqual(state.update(candidate: [1, 0.2, -14], camera: [0.1, 1, -6], instruction: right, timestamp: 1.5), next)
    }

    func testHeadHeightAndPhoneTiltingDoNotCountAsWalking() throws {
        var state = ARStreetGuidance.AnchorState()
        let original = try XCTUnwrap(state.update(candidate: [0, 0, -8], camera: .zero, instruction: ahead, timestamp: 0))
        XCTAssertEqual(state.update(candidate: [1, 1, -9], camera: [0, 8, 0], instruction: ahead, timestamp: 0.5), original)
        XCTAssertEqual(state.update(candidate: [-1, -1, -7], camera: [0, -8, 0], instruction: ahead, timestamp: 1), original)
    }

    func testNewTurnMustSettleBeforeReplacingTheWholeSign() throws {
        var state = ARStreetGuidance.AnchorState()
        let original = try XCTUnwrap(state.update(candidate: [0, 0, -8], camera: .zero, instruction: ahead, timestamp: 0))
        for time in [0.1, 0.6, 1.1] {
            XCTAssertEqual(state.update(candidate: [5, 0, -6], camera: .zero, instruction: right, timestamp: time), original)
        }
        let next = try XCTUnwrap(state.update(candidate: [5, 0, -6], camera: .zero, instruction: right, timestamp: 1.7))
        XCTAssertEqual(next.instruction, right)
        XCTAssertNotEqual(next.facingYawRadians, original.facingYawRadians)
        XCTAssertEqual(state.update(candidate: [6, 0.2, -5], camera: [0.5, 0, 0], instruction: right, timestamp: 2), next)
    }

    func testFluctuatingRouteInstructionsNeverSpinTheSign() throws {
        var state = ARStreetGuidance.AnchorState()
        let original = try XCTUnwrap(state.update(candidate: [0, 0, -8], camera: .zero, instruction: ahead, timestamp: 0))
        for i in 1...40 {
            let instruction = i % 3 == 0 ? ahead : right
            XCTAssertEqual(state.update(candidate: [5, 0, -6], camera: .zero, instruction: instruction,
                                        timestamp: Double(i) / 10), original)
        }
    }

    func testTrackingGapRepeatedFrameAndClockRollbackDoNotCommitPendingTurn() throws {
        var state = ARStreetGuidance.AnchorState()
        let original = try XCTUnwrap(state.update(candidate: [0, 0, -8], camera: .zero, instruction: ahead, timestamp: 0))
        XCTAssertEqual(state.update(candidate: [5, 0, -6], camera: .zero, instruction: right, timestamp: 0.2), original)
        XCTAssertEqual(state.update(candidate: [5, 0, -6], camera: .zero, instruction: right, timestamp: 3), original)
        XCTAssertEqual(state.update(candidate: [5, 0, -6], camera: .zero, instruction: right, timestamp: 3), original)
        XCTAssertEqual(state.update(candidate: [5, 0, -6], camera: .zero, instruction: right, timestamp: 2), original)
        for time in [3.5, 4.0] {
            XCTAssertEqual(state.update(candidate: [5, 0, -6], camera: .zero, instruction: right, timestamp: time), original)
        }
        XCTAssertEqual(state.update(candidate: [5, 0, -6], camera: .zero, instruction: right, timestamp: 4.6)?.instruction, right)
    }

    func testInvalidFirstPlacementIsHiddenAndTransientInvalidDataPreservesThePin() throws {
        var state = ARStreetGuidance.AnchorState()
        for candidate: SIMD3<Double> in [[0, 0, -1], [0, 0, -50], [0, .nan, -8]] {
            XCTAssertNil(state.update(candidate: candidate, camera: .zero, instruction: ahead, timestamp: 0))
        }
        let original = try XCTUnwrap(state.update(candidate: [0, 0, -8], camera: .zero, instruction: ahead, timestamp: 1))
        XCTAssertNil(state.update(candidate: [0, .nan, -8], camera: .zero, instruction: ahead, timestamp: 1.5))
        XCTAssertEqual(state.placement, original)
        XCTAssertEqual(state.update(candidate: [0, 0, -100], camera: [0, 0, -5], instruction: ahead, timestamp: 2), original)
    }

    func testResetForNewSessionOrDestinationAllowsFreshPlacement() throws {
        var state = ARStreetGuidance.AnchorState()
        _ = state.update(candidate: [0, 0, -8], camera: .zero, instruction: ahead, timestamp: 10)
        state.reset()
        XCTAssertNil(state.placement)
        XCTAssertEqual(state.update(candidate: [5, 0, -6], camera: .zero, instruction: right, timestamp: 0)?.instruction, right)
    }

    func testStreetNameChangeUsesTheSameSettlingRuleAndBlankLabelsAreOmitted() throws {
        var state = ARStreetGuidance.AnchorState()
        let original = try XCTUnwrap(state.update(candidate: [0, 0, -8], camera: .zero, instruction: ahead, timestamp: 0))
        let next = ARStreetGuidance.Instruction(direction: .ahead, streetName: "  North Ave W  ")
        XCTAssertEqual(next.streetName, "North Ave W")
        XCTAssertNil(ARStreetGuidance.Instruction(direction: .ahead, streetName: "  ").streetName)
        for time in [0.1, 0.6, 1.1] {
            XCTAssertEqual(state.update(candidate: [0, 0, -8], camera: .zero, instruction: next, timestamp: time), original)
        }
        XCTAssertEqual(state.update(candidate: [0, 0, -8], camera: .zero, instruction: next, timestamp: 1.7)?.instruction.streetName, "North Ave W")
    }

    private func cornerRoute() -> WalkingRoute {
        let start = GeoCoordinate(latitude: 40.65, longitude: -74.3)
        let corner = GeoMath.destination(from: start, bearing: 0, distance: 100)
        let end = GeoMath.destination(from: corner, bearing: 90, distance: 100)
        return WalkingRoute(origin: start, destination: end, distanceMeters: 200, durationSeconds: 160,
                            routeCoordinates: [start, corner, end], routeSteps: [], source: .appleMaps)
    }

    func testPreviewIsEightMetersAlongTheActualSegment() throws {
        let route = cornerRoute()
        let progress = RouteProgressCalculator.progress(along: route, userLocation: route.origin)
        let point = try XCTUnwrap(ARStreetGuidance.routePoint(route: route, progress: progress))
        XCTAssertEqual(GeoMath.distance(from: route.origin, to: point), 8, accuracy: 0.05)
        XCTAssertEqual(GeoMath.bearing(from: route.origin, to: point), 0, accuracy: 0.1)
    }

    func testPreviewStopsAtCornerInsteadOfCuttingIntoNextLeg() throws {
        let route = cornerRoute()
        let fix = GeoMath.destination(from: route.origin, bearing: 0, distance: 97)
        let progress = RouteProgressCalculator.progress(along: route, userLocation: fix)
        let point = try XCTUnwrap(ARStreetGuidance.routePoint(route: route, progress: progress))
        XCTAssertLessThan(GeoMath.distance(from: point, to: route.routeCoordinates[1]), 0.05)
    }

    func testEstimatedOffRouteOrInvalidSegmentDoesNotPlaceStreetGuidance() {
        var route = cornerRoute()
        var progress = RouteProgressCalculator.progress(along: route, userLocation: route.origin)
        progress.segmentIndex = .max
        XCTAssertNil(ARStreetGuidance.routePoint(route: route, progress: progress))
        progress.segmentIndex = -1
        XCTAssertNil(ARStreetGuidance.routePoint(route: route, progress: progress))
        progress.segmentIndex = 0
        progress.distanceFromRoute = 36
        XCTAssertNil(ARStreetGuidance.routePoint(route: route, progress: progress))
        progress.distanceFromRoute = 0
        route.source = .straightLineEstimate
        XCTAssertNil(ARStreetGuidance.routePoint(route: route, progress: progress))
    }
}
