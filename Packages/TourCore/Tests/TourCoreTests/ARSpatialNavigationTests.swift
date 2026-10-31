import XCTest
@testable import TourCore

final class ARSpatialNavigationTests: XCTestCase {
    private let origin = GeoCoordinate(latitude: 40.65, longitude: -74.3)
    private func point(_ bearing: Double, _ meters: Double) -> GeoCoordinate {
        GeoMath.destination(from: origin, bearing: bearing, distance: meters)
    }
    private func route(_ points: [GeoCoordinate]) -> WalkingRoute {
        WalkingRoute(origin: points.first ?? origin, destination: points.last ?? origin, distanceMeters: 100,
                     durationSeconds: 80, routeCoordinates: points, source: .googleRoutesAPI)
    }

    func testWGS84KnownEquatorialAxesAndAltitude() throws {
        let frame = WGS84LocalFrame(origin: .init(latitude: 0, longitude: 0))
        let east = try XCTUnwrap(frame.eastNorthUp(.init(latitude: 0, longitude: 0.0001)))
        XCTAssertEqual(east.x, 11.131949, accuracy: 0.0001)
        XCTAssertEqual(east.y, 0, accuracy: 0.0001)
        let north = try XCTUnwrap(frame.arOffset(.init(latitude: 0.0001, longitude: 0)))
        XCTAssertEqual(north.x, 0, accuracy: 0.0001)
        XCTAssertEqual(north.z, -11.057428, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(frame.eastNorthUp(.init(latitude: 0, longitude: 0), altitude: 7)).z, 7, accuracy: 0.00001)
    }

    func testWGS84DatelineAndInvalidCoordinates() throws {
        let frame = WGS84LocalFrame(origin: .init(latitude: 0, longitude: 179.999))
        let offset = try XCTUnwrap(frame.arOffset(.init(latitude: 0, longitude: -179.999)))
        XCTAssertEqual(offset.x, 222.63898, accuracy: 0.01)
        XCTAssertNil(frame.arOffset(.init(latitude: .nan, longitude: 0)))
        XCTAssertNil(WGS84LocalFrame(origin: .init(latitude: 100, longitude: 0)).arOffset(origin))
    }

    func testDelayedGPSUsesInterpolatedCameraPositionAndRejectsGaps() throws {
        var history = ARCameraPositionHistory()
        let start = Date(timeIntervalSince1970: 1000)
        history.append(.zero, at: start)
        history.append([2, 0, 0], at: start.addingTimeInterval(0.2))
        XCTAssertEqual(try XCTUnwrap(history.position(at: start.addingTimeInterval(0.1))).x, 1, accuracy: 0.0001)
        XCTAssertNil(history.position(at: start.addingTimeInterval(-2)))
        XCTAssertNil(history.position(at: start.addingTimeInterval(1)))
        history.append([10, 0, 0], at: start.addingTimeInterval(2))
        XCTAssertNil(history.position(at: start.addingTimeInterval(1)))
    }

    func testStableAlignmentDoesNotFollowStationaryGPSJitterOrReplay() throws {
        var alignment = ARGeographicAlignment()
        let start = Date(timeIntervalSince1970: 1000)
        alignment.update(coordinate: origin, camera: .zero, accuracy: 3, timestamp: start)
        let before = try XCTUnwrap(alignment.position(for: point(0, 8)))
        alignment.update(coordinate: point(90, 2), camera: .zero, accuracy: 3, timestamp: start.addingTimeInterval(1))
        let after = try XCTUnwrap(alignment.position(for: point(0, 8)))
        XCTAssertLessThanOrEqual(abs(after.x - before.x), 0.25)
        alignment.update(coordinate: point(90, 2), camera: [10, 0, 0], accuracy: 3, timestamp: start.addingTimeInterval(1))
        XCTAssertEqual(alignment.position(for: point(0, 8)), after)
    }

    func testGPSJumpSuppressesAlignmentAndRecoversWithoutRebasingStreet() {
        var alignment = ARGeographicAlignment()
        let start = Date(timeIntervalSince1970: 1000)
        alignment.update(coordinate: origin, camera: .zero, accuracy: 3, timestamp: start)
        let original = alignment.position(for: point(0, 8))
        alignment.update(coordinate: point(90, 100), camera: .zero, accuracy: 3, timestamp: start.addingTimeInterval(1))
        XCTAssertFalse(alignment.isConsistent)
        XCTAssertNil(alignment.position(for: point(0, 8)))
        alignment.update(coordinate: origin, camera: .zero, accuracy: 3, timestamp: start.addingTimeInterval(2))
        XCTAssertEqual(alignment.position(for: point(0, 8)), original)
    }

    func testWalkingCourseValidatesWorldNorthRatherThanPhoneFacing() {
        var alignment = ARGeographicAlignment()
        let start = Date(timeIntervalSince1970: 1000)
        alignment.update(coordinate: origin, camera: .zero, accuracy: 2, timestamp: start)
        alignment.update(coordinate: point(90, 12), camera: [12, 0, 0], accuracy: 2,
                         timestamp: start.addingTimeInterval(8), course: 90, speed: 1.5)
        XCTAssertTrue(alignment.isConsistent)
        alignment.update(coordinate: GeoMath.destination(from: point(90, 12), bearing: 0, distance: 12), camera: [24, 0, 0], accuracy: 2,
                         timestamp: start.addingTimeInterval(16), course: 0, speed: 1.5)
        XCTAssertFalse(alignment.isConsistent)
    }

    func testTurningWhileWalkingDoesNotCompareInstantCourseToOldTrajectory() {
        var alignment = ARGeographicAlignment()
        let start = Date(timeIntervalSince1970: 1000)
        alignment.update(coordinate: origin, camera: .zero, accuracy: 3, timestamp: start)
        let corner = point(0, 8)
        let end = GeoMath.destination(from: corner, bearing: 90, distance: 8)
        alignment.update(coordinate: end, camera: [8, 0, -8], accuracy: 3,
            timestamp: start.addingTimeInterval(12), course: 90, speed: 1.4)
        XCTAssertTrue(alignment.isConsistent)
    }

    func testStraightPreviewIsOnRouteAndLookaheadAdaptsToWalkingSpeed() throws {
        let route = route([origin, point(0, 50)])
        let progress = RouteProgressCalculator.progress(along: route, userLocation: origin)
        let slow = try XCTUnwrap(ARRoutePlacementEngine.preview(route: route, progress: progress, speed: 0))
        let fast = try XCTUnwrap(ARRoutePlacementEngine.preview(route: route, progress: progress, speed: 2))
        XCTAssertEqual(slow.distanceAhead, 5, accuracy: 0.01)
        XCTAssertEqual(fast.distanceAhead, 9, accuracy: 0.01)
        XCTAssertEqual(fast.coordinate.longitude, origin.longitude, accuracy: 0.000001)
        XCTAssertEqual(fast.bearing, 0, accuracy: 0.001)
    }

    func testLeftAndRightCornersNeverProduceDiagonalShortcut() throws {
        for turn in [90.0, 270.0] {
            let corner = point(0, 10)
            let route = route([origin, corner, GeoMath.destination(from: corner, bearing: turn, distance: 30)])
            let before = RouteProgressCalculator.progress(along: route, userLocation: point(0, 5))
            let preview = try XCTUnwrap(ARRoutePlacementEngine.preview(route: route, progress: before))
            XCTAssertEqual(preview.coordinate.longitude, origin.longitude, accuracy: 0.000001)
            XCTAssertLessThan(GeoMath.distance(from: origin, to: preview.coordinate), 10)
            let atCrossing = RouteProgressCalculator.progress(along: route, userLocation: point(0, 9))
            XCTAssertNil(ARRoutePlacementEngine.preview(route: route, progress: atCrossing))
            let after = RouteProgressCalculator.progress(along: route,
                userLocation: GeoMath.destination(from: corner, bearing: turn, distance: 4))
            XCTAssertEqual(try XCTUnwrap(ARRoutePlacementEngine.preview(route: route, progress: after)).bearing, turn, accuracy: 0.02)
        }
    }

    func testDenseCurvedPolylinePreviewUsesActualSegments() throws {
        let a = point(0, 2), b = GeoMath.destination(from: a, bearing: 15, distance: 2)
        let c = GeoMath.destination(from: b, bearing: 25, distance: 20)
        let route = route([origin, a, b, c])
        let progress = RouteProgressCalculator.progress(along: route, userLocation: origin)
        let preview = try XCTUnwrap(ARRoutePlacementEngine.preview(route: route, progress: progress))
        XCTAssertEqual(preview.segmentIndex, 2)
        XCTAssertLessThan(GeoMath.project(preview.coordinate, ontoSegment: b, c).distance, 0.01)
    }

    func testOffRouteAndEstimatesSuppressSpatialPreview() {
        var route = route([origin, point(0, 50)])
        let off = RouteProgressCalculator.progress(along: route, userLocation: point(90, 20))
        XCTAssertGreaterThan(off.distanceFromRoute, 8)
        XCTAssertNil(ARRoutePlacementEngine.preview(route: route, progress: off))
        let progress = RouteProgressCalculator.progress(along: route, userLocation: origin)
        route.source = .straightLineEstimate
        XCTAssertNil(ARRoutePlacementEngine.preview(route: route, progress: progress))
        route.source = .simulated
        XCTAssertNil(ARRoutePlacementEngine.preview(route: route, progress: progress))
    }

    func testRouteCrossingKeepsActiveSegmentRatherThanSkippingALoop() {
        let south = point(180, 20), east = point(90, 20), north = point(0, 20)
        let northeast = GeoMath.destination(from: east, bearing: 0, distance: 20)
        let route = route([south, origin, east, northeast, north, origin, point(270, 20)])
        let previous = RouteProgressCalculator.progress(along: route, userLocation: point(180, 5))
        XCTAssertEqual(previous.segmentIndex, 0)
        let crossing = RouteProgressCalculator.progress(along: route, userLocation: origin, previous: previous)
        XCTAssertLessThan(crossing.segmentIndex, 2)
        let after = RouteProgressCalculator.progress(along: route, userLocation: point(90, 5), previous: crossing)
        XCTAssertEqual(after.segmentIndex, 1)
        XCTAssertGreaterThan(after.traveledMeters, crossing.traveledMeters)
    }

    func testReturnWithinTwoMetersDoesNotRewindProgress() {
        let end = point(0, 80)
        let jog = GeoMath.destination(from: end, bearing: 90, distance: 1.5)
        let back = GeoMath.destination(from: jog, bearing: 180, distance: 80)
        let walked = route([origin, end, jog, back])
        var progress: RouteProgress?
        for meters in stride(from: 0.0, through: 80, by: 10) {
            progress = RouteProgressCalculator.progress(along: walked,
                userLocation: GeoMath.destination(from: origin, bearing: 0, distance: meters),
                previous: progress)
        }
        let outbound = progress
        XCTAssertEqual(outbound?.segmentIndex, 1)
        for meters in stride(from: 0.0, through: 80, by: 1) {
            progress = RouteProgressCalculator.progress(along: walked,
                userLocation: GeoMath.destination(from: jog, bearing: 180, distance: meters),
                previous: progress)
            XCTAssertGreaterThanOrEqual(progress?.traveledMeters ?? -1, (outbound?.traveledMeters ?? 0) - 0.5,
                "Walking back within 2 m of the outbound leg must not rewind the route")
        }
        XCTAssertEqual(progress?.segmentIndex, 2)
        XCTAssertEqual(progress?.remainingMeters ?? -1, 0, accuracy: 0.5)
    }

    func testConfidenceAcquiresSlowlyDropsImmediatelyAndUsesHysteresis() {
        var confidence = ARSpatialConfidence()
        func update(_ time: Double, accuracy: Double = 3, tracking: Bool = true) -> ARSpatialConfidence.Mode {
            confidence.update(tracking: tracking, locationAge: 0, accuracy: accuracy, yawAccuracy: 5,
                              routeOffset: 1, hasPreview: true, alignment: true, timestamp: time)
        }
        for t in stride(from: 0.0, to: 2.0, by: 0.5) { XCTAssertEqual(update(t), .aligning) }
        XCTAssertEqual(update(2), .spatial)
        XCTAssertEqual(update(2.5, accuracy: 6), .spatial)
        XCTAssertEqual(update(3, accuracy: 12), .degraded(.location))
        XCTAssertEqual(update(3.5, accuracy: 6), .degraded(.location))
        for t in stride(from: 4.0, to: 6.0, by: 0.5) { XCTAssertEqual(update(t), .aligning) }
        XCTAssertEqual(update(6), .spatial)
        XCTAssertEqual(update(6.1, tracking: false), .degraded(.tracking))
    }

    func testStaleGPSPoorHeadingOffRouteAndNoGeometryCannotShowSpatialArrows() {
        for (age, accuracy, yaw, offset, preview, alignment, expected) in [
            (10.0, 3.0, 5.0, 0.0, true, true, ARSpatialConfidence.Reason.location),
            (0, 3, 30, 0, true, true, .heading), (0, 3, 5, 20, true, true, .offRoute),
            (0, 3, 5, 0, false, true, .route), (0, 3, 5, 0, true, false, .alignment)
        ] {
            var confidence = ARSpatialConfidence()
            XCTAssertEqual(confidence.update(tracking: true, locationAge: age, accuracy: accuracy, yawAccuracy: yaw,
                routeOffset: offset, hasPreview: preview, alignment: alignment, timestamp: 0), .degraded(expected))
        }
    }

    func testConfidenceReacquiresAfterSessionGapRatherThanFlashingOldState() {
        var state = ARSpatialConfidence()
        for t in stride(from: 0.0, through: 2.0, by: 0.5) {
            _ = state.update(tracking: true, locationAge: 0, accuracy: 3, yawAccuracy: 5, routeOffset: 0,
                             hasPreview: true, alignment: true, timestamp: t)
        }
        XCTAssertEqual(state.mode, .spatial)
        XCTAssertEqual(state.update(tracking: true, locationAge: 0, accuracy: 3, yawAccuracy: 5, routeOffset: 0,
            hasPreview: true, alignment: true, timestamp: 20), .aligning)
    }

    func testPinnedWorldPoseIgnoresGPSJitterAndHasNoCameraYawInput() throws {
        var state = ARWorldPlacementState()
        let original = try XCTUnwrap(state.update(position: [0, 0, -7], routeYaw: 0, direction: .ahead,
                                                  segment: 0, camera: .zero, timestamp: 0))
        for i in 1...100 {
            XCTAssertEqual(state.update(position: [0.5, 0, -7.3], routeYaw: 0.05, direction: .ahead,
                segment: 0, camera: .zero, timestamp: Double(i) / 10), original)
        }
        let next = state.update(position: [0, 0, -11], routeYaw: 0, direction: .ahead,
                                segment: 0, camera: [0, 0, -4], timestamp: 10.1)
        XCTAssertNotEqual(next, original)
        XCTAssertEqual(next?.position.z, -11)
    }

    func testManeuverReplacementSettlesBeforeChangingWorldPose() {
        var state = ARWorldPlacementState()
        let first = state.update(position: [0, 0, -7], routeYaw: 0, direction: .ahead, segment: 0, camera: .zero, timestamp: 0)
        XCTAssertEqual(state.update(position: [5, 0, -7], routeYaw: .pi / 2, direction: .right,
            segment: 1, camera: .zero, timestamp: 0.5), first)
        XCTAssertNotEqual(state.update(position: [5, 0, -7], routeYaw: .pi / 2, direction: .right,
            segment: 1, camera: .zero, timestamp: 1.5), first)
    }
}
