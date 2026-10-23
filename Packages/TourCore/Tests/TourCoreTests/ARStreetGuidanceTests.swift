import XCTest
@testable import TourCore

final class ARStreetGuidanceTests: XCTestCase {
    private let forward = SIMD2<Double>(0, -1)

    func testAnchorDoesNotChaseCameraMovementOrGroundRefinement() {
        var state = ARStreetGuidance.AnchorState()
        let original = SIMD3<Double>(0, 0, -6)
        XCTAssertEqual(state.update(candidate: original, camera: .zero, direction: forward, segment: 0), original)
        // Walking a little or moving/tilting the phone must not drag the marker along with it.
        let shifted = SIMD3<Double>(1, 0.4, -7)
        XCTAssertEqual(state.update(candidate: shifted, camera: [0.3, 1, -1], direction: forward, segment: 0), original)
        XCTAssertEqual(state.update(candidate: shifted, camera: [-0.3, 2, -1], direction: forward, segment: 0), original)
    }

    func testAnchorAdvancesWhenApproachedInsteadOfGrowingIntoTheCamera() {
        var state = ARStreetGuidance.AnchorState()
        _ = state.update(candidate: [0, 0, -6], camera: .zero, direction: forward, segment: 0)
        XCTAssertEqual(state.update(candidate: [0, 0, -10], camera: [0, 0, -4], direction: forward, segment: 0), [0, 0, -10])
    }

    func testNewSegmentOrMeaningfulDirectionChangeRelocatesAnchor() {
        var state = ARStreetGuidance.AnchorState()
        _ = state.update(candidate: [0, 0, -6], camera: .zero, direction: forward, segment: 0)
        XCTAssertEqual(state.update(candidate: [6, 0, 0], camera: .zero, direction: [1, 0], segment: 0), [6, 0, 0])
        XCTAssertEqual(state.update(candidate: [7, 0, 0], camera: .zero, direction: [1, 0], segment: 1), [7, 0, 0])
    }

    func testTooCloseTooFarAndInvalidInputsCannotProduceOversizedMarkers() {
        var state = ARStreetGuidance.AnchorState()
        XCTAssertNil(state.update(candidate: [0, 0, -1], camera: .zero, direction: forward, segment: 0))
        XCTAssertNil(state.update(candidate: [0, 0, -50], camera: .zero, direction: forward, segment: 0))
        XCTAssertNil(state.update(candidate: [0, .nan, -6], camera: .zero, direction: forward, segment: 0))
        XCTAssertNil(state.update(candidate: [0, 0, -6], camera: .zero, direction: .zero, segment: 0))
        XCTAssertNil(state.position)
    }

    func testForceAndResetDiscardOldAnchor() {
        var state = ARStreetGuidance.AnchorState()
        _ = state.update(candidate: [0, 0, -6], camera: .zero, direction: forward, segment: 0)
        XCTAssertEqual(state.update(candidate: [0, 0, -7], camera: .zero, direction: forward, segment: 0, force: true), [0, 0, -7])
        state.reset()
        XCTAssertNil(state.position)
    }

    private func cornerRoute() -> WalkingRoute {
        let start = GeoCoordinate(latitude: 40.65, longitude: -74.3)
        let corner = GeoMath.destination(from: start, bearing: 0, distance: 100)
        let end = GeoMath.destination(from: corner, bearing: 90, distance: 100)
        return WalkingRoute(origin: start, destination: end, distanceMeters: 200, durationSeconds: 160,
                            routeCoordinates: [start, corner, end], routeSteps: [], source: .appleMaps)
    }

    func testPreviewIsSixMetersAlongTheActualSegment() throws {
        let route = cornerRoute()
        let progress = RouteProgressCalculator.progress(along: route, userLocation: route.origin)
        let point = try XCTUnwrap(ARStreetGuidance.routePoint(route: route, progress: progress))
        XCTAssertEqual(GeoMath.distance(from: route.origin, to: point), 6, accuracy: 0.05)
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
