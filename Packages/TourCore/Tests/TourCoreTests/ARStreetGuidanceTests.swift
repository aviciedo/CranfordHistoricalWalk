import XCTest
@testable import TourCore

final class ARStreetGuidanceTests: XCTestCase {
    func testReadableCandidateKeepsActualNearbyRouteProjection() {
        XCTAssertEqual(ARStreetGuidance.readableCandidate(projected: [2, -1.4, -8], camera: .zero,
            routeDirection: [0, 0, -1]), [2, -1.4, -8])
    }

    func testGPSLateralOffsetBeyondRendererLimitProducesReadableNearbySign() throws {
        // routePoint accepts 35 m lateral error, but the old renderer refused over 14 m.
        let candidate = try XCTUnwrap(ARStreetGuidance.readableCandidate(projected: [25, -1.4, -8], camera: .zero,
            routeDirection: [0, 0, -1]))
        XCTAssertEqual(candidate, [0, -1.4, -8])
        var state = ARStreetGuidance.AnchorState()
        XCTAssertNotNil(state.update(candidate: candidate, camera: .zero,
            instruction: .init(direction: .left, streetName: "Alden St"), timestamp: 1))
    }

    func testShortPolylineVertexDoesNotPreventFirstArrowPlacement() throws {
        for distance in [0.0, 0.2, 1.0, 2.9, 50.0] {
            let candidate = try XCTUnwrap(ARStreetGuidance.readableCandidate(projected: [0, -1, -distance], camera: .zero,
                routeDirection: [0, 0, -2]))
            XCTAssertEqual(candidate, [0, -1, -8])
        }
    }

    func testReadableFallbackRejectsInvalidOrUnavailableDirection() {
        XCTAssertNil(ARStreetGuidance.readableCandidate(projected: [0, 0, -50], camera: .zero, routeDirection: .zero))
        XCTAssertNil(ARStreetGuidance.readableCandidate(projected: [0, .nan, -8], camera: .zero, routeDirection: [0, 0, -1]))
        XCTAssertNil(ARStreetGuidance.readableCandidate(projected: [0, 0, -8], camera: [.nan, 0, 0], routeDirection: [0, 0, -1]))
    }

    func testFallbackStillPinsPoseRatherThanFollowingGPSNoise() throws {
        var state = ARStreetGuidance.AnchorState()
        let instruction = ARStreetGuidance.Instruction(direction: .left, streetName: "Alden St")
        let first = try XCTUnwrap(ARStreetGuidance.readableCandidate(projected: [25, -1, -8], camera: .zero, routeDirection: [0, 0, -1]))
        let original = try XCTUnwrap(state.update(candidate: first, camera: .zero, instruction: instruction, timestamp: 0))
        for i in 1...20 {
            let candidate = try XCTUnwrap(ARStreetGuidance.readableCandidate(projected: [30, -1, 20], camera: [0.2, 0, 0.2], routeDirection: [1, 0, 0]))
            XCTAssertEqual(state.update(candidate: candidate, camera: [0.2, 0, 0.2], instruction: instruction,
                                         timestamp: Double(i) / 10), original)
        }
    }

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

    func testUnconfirmedTurnBlocksRepositionUntilTheInstructionSettles() throws {
        var state = ARStreetGuidance.AnchorState()
        let original = try XCTUnwrap(state.update(candidate: [0, 0, -8], camera: .zero, instruction: ahead, timestamp: 0))
        XCTAssertEqual(state.update(candidate: [0, 0, -8], camera: [6, 0, 0], instruction: right, timestamp: 0.5), original)
        XCTAssertEqual(state.update(candidate: [0, 0, -8], camera: [7, 0, 0], instruction: right, timestamp: 1.25), original)
        let next = try XCTUnwrap(state.update(candidate: [7, 0, -8], camera: [7, 0, 0], instruction: right, timestamp: 2))
        XCTAssertEqual(next.instruction, right)
        XCTAssertEqual(next.position, [7, 0, -8])
    }

    func testOneSecondGapKeepsTheSettleClockAndALongerGapRestartsIt() throws {
        var kept = ARStreetGuidance.AnchorState()
        let original = try XCTUnwrap(kept.update(candidate: [0, 0, -8], camera: .zero, instruction: ahead, timestamp: 0))
        XCTAssertEqual(kept.update(candidate: [0, 0, -8], camera: .zero, instruction: right, timestamp: 0.5), original)
        // A gap of exactly one second must not discard the pending turn.
        XCTAssertEqual(kept.update(candidate: [0, 0, -8], camera: [6, 0, 0], instruction: right, timestamp: 1.5), original)
        let committed = try XCTUnwrap(kept.update(candidate: [6, 0, -8], camera: [6, 0, 0], instruction: right, timestamp: 2))
        XCTAssertEqual(committed.instruction, right)

        var restarted = ARStreetGuidance.AnchorState()
        XCTAssertNotNil(restarted.update(candidate: [0, 0, -8], camera: .zero, instruction: ahead, timestamp: 0))
        XCTAssertEqual(restarted.update(candidate: [0, 0, -8], camera: .zero, instruction: right, timestamp: 0.5), original)
        XCTAssertEqual(restarted.update(candidate: [0, 0, -8], camera: [6, 0, 0], instruction: right, timestamp: 1.75), original)
        // The clock restarted at 1.75, so 2.75 is only one second into the new wait.
        XCTAssertEqual(restarted.update(candidate: [6, 0, -8], camera: [6, 0, 0], instruction: right, timestamp: 2.75)?.instruction, ahead)
        XCTAssertEqual(restarted.update(candidate: [6, 0, -8], camera: [6, 0, 0], instruction: right, timestamp: 3.25)?.instruction, right)
    }

    func testRepositionAndFirstPlacementUseClosedDistanceThresholds() throws {
        var state = ARStreetGuidance.AnchorState()
        let original = try XCTUnwrap(state.update(candidate: [0, 0, -8], camera: .zero, instruction: ahead, timestamp: 0))
        XCTAssertEqual(state.update(candidate: [0, 0, -8], camera: [4.999, 0, 0], instruction: ahead, timestamp: 0.4), original)
        let moved = try XCTUnwrap(state.update(candidate: [0, 0, -8], camera: [5, 0, 0], instruction: ahead, timestamp: 0.8))
        XCTAssertNotEqual(moved.facingYawRadians, original.facingYawRadians)

        var edges = ARStreetGuidance.AnchorState()
        XCTAssertNil(edges.update(candidate: [0, 0, -2.999], camera: .zero, instruction: ahead, timestamp: 0))
        XCTAssertNotNil(edges.update(candidate: [0, 0, -3], camera: .zero, instruction: ahead, timestamp: 0))
        edges.reset()
        XCTAssertNotNil(edges.update(candidate: [0, 0, -14], camera: .zero, instruction: ahead, timestamp: 0))
        edges.reset()
        XCTAssertNil(edges.update(candidate: [0, 0, -14.001], camera: .zero, instruction: ahead, timestamp: 0))
    }

    func testReadableCandidateKeepsTheInclusiveThreeToFourteenMetreWindow() {
        let direction = SIMD3<Double>(0, 0, -1)
        XCTAssertEqual(ARStreetGuidance.readableCandidate(projected: [0, -1, -3], camera: .zero, routeDirection: direction), [0, -1, -3])
        XCTAssertEqual(ARStreetGuidance.readableCandidate(projected: [0, -1, -14], camera: .zero, routeDirection: direction), [0, -1, -14])
        XCTAssertEqual(ARStreetGuidance.readableCandidate(projected: [0, -1, -2.999], camera: .zero, routeDirection: direction), [0, -1, -8])
        XCTAssertEqual(ARStreetGuidance.readableCandidate(projected: [0, -1, -14.001], camera: .zero, routeDirection: direction), [0, -1, -8])
    }

    func testRoutePreviewAcceptsThirtyFiveMetresOfLateralErrorAndRejectsTheNextMillimetre() throws {
        let route = cornerRoute()
        var progress = RouteProgressCalculator.progress(along: route, userLocation: route.origin)
        progress.distanceFromRoute = 35
        XCTAssertNotNil(ARStreetGuidance.routePoint(route: route, progress: progress))
        progress.distanceFromRoute = 35.0001
        XCTAssertNil(ARStreetGuidance.routePoint(route: route, progress: progress))
        progress.distanceFromRoute = -0.001
        XCTAssertNil(ARStreetGuidance.routePoint(route: route, progress: progress))
        progress.distanceFromRoute = .nan
        XCTAssertNil(ARStreetGuidance.routePoint(route: route, progress: progress))
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
