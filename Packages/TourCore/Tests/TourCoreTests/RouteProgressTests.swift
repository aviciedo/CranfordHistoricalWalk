import XCTest
@testable import TourCore

final class RouteProgressTests: XCTestCase {
    func testRemainingDistanceFollowsRouteNotStraightLine() {
        // L-shaped route: 300 m east, then 400 m north. Straight line from start is 500 m,
        // but the walking distance is 700 m.
        let start = cranfordCenter
        let corner = GeoMath.destination(from: start, bearing: 90, distance: 300)
        let end = GeoMath.destination(from: corner, bearing: 0, distance: 400)
        let route = WalkingRoute(origin: start, destination: end, distanceMeters: 700, durationSeconds: 500, routeCoordinates: [start, corner, end], source: .googleRoutesAPI)

        let atStart = RouteProgressCalculator.progress(along: route, userLocation: start)
        XCTAssertEqual(atStart.remainingMeters, 700, accuracy: 1)
        XCTAssertEqual(atStart.remainingSeconds, 500, accuracy: 1)
        XCTAssertEqual(atStart.segmentIndex, 0)
        XCTAssertEqual(atStart.nextWaypoint, corner)

        let halfway = GeoMath.destination(from: start, bearing: 90, distance: 150)
        let p = RouteProgressCalculator.progress(along: route, userLocation: halfway)
        XCTAssertEqual(p.remainingMeters, 550, accuracy: 1)
        XCTAssertEqual(p.traveledMeters, 150, accuracy: 1)
        XCTAssertEqual(p.fractionComplete, 150.0 / 700.0, accuracy: 0.002)

        let nearEnd = GeoMath.destination(from: corner, bearing: 0, distance: 390)
        let q = RouteProgressCalculator.progress(along: route, userLocation: nearEnd)
        XCTAssertEqual(q.remainingMeters, 10, accuracy: 1)
        XCTAssertEqual(q.segmentIndex, 1)
        XCTAssertEqual(q.nextWaypoint, end)
    }

    func testOffRouteDistanceReported() {
        let route = makeRoute(from: cranfordCenter, bearing: 90, segments: 4, segmentMeters: 100)
        let onRoute = GeoMath.destination(from: cranfordCenter, bearing: 90, distance: 220)
        let off = GeoMath.destination(from: onRoute, bearing: 180, distance: 45)
        let p = RouteProgressCalculator.progress(along: route, userLocation: off)
        XCTAssertEqual(p.distanceFromRoute, 45, accuracy: 0.5)
        XCTAssertEqual(p.remainingMeters, 180, accuracy: 1)
    }

    func testRemainingTimeScalesWithProviderDuration() {
        // Provider says 1000 m takes 1000 s (1 m/s); polyline length is also 1000 m.
        let route = makeRoute(from: cranfordCenter, bearing: 0, segments: 10, segmentMeters: 100, speed: 1.0)
        let mid = GeoMath.destination(from: cranfordCenter, bearing: 0, distance: 600)
        let p = RouteProgressCalculator.progress(along: route, userLocation: mid)
        XCTAssertEqual(p.remainingSeconds, 400, accuracy: 2)
    }

    func testProviderDistanceScalingWhenPolylineIsSimplified() {
        // Provider reports 1100 m but the polyline only measures 1000 m (simplified geometry).
        var route = makeRoute(from: cranfordCenter, bearing: 0, segments: 10, segmentMeters: 100, speed: 1.0)
        route.distanceMeters = 1100
        route.durationSeconds = 1100
        let p = RouteProgressCalculator.progress(along: route, userLocation: cranfordCenter)
        XCTAssertEqual(p.remainingMeters, 1100, accuracy: 1)
        XCTAssertEqual(p.remainingSeconds, 1100, accuracy: 1)
    }

    func testCurrentStepIndexAdvances() {
        let start = cranfordCenter
        let corner = GeoMath.destination(from: start, bearing: 90, distance: 300)
        let end = GeoMath.destination(from: corner, bearing: 0, distance: 400)
        let steps = [
            RouteStep(distanceMeters: 300, durationSeconds: 200, startCoordinate: start, endCoordinate: corner, instruction: "Head east"),
            RouteStep(distanceMeters: 400, durationSeconds: 300, startCoordinate: corner, endCoordinate: end, instruction: "Turn left")
        ]
        let route = WalkingRoute(origin: start, destination: end, distanceMeters: 700, durationSeconds: 500, routeCoordinates: [start, corner, end], routeSteps: steps, source: .googleRoutesAPI)
        XCTAssertEqual(RouteProgressCalculator.progress(along: route, userLocation: start).currentStepIndex, 0)
        let onSecond = GeoMath.destination(from: corner, bearing: 0, distance: 50)
        XCTAssertEqual(RouteProgressCalculator.progress(along: route, userLocation: onSecond).currentStepIndex, 1)
    }

    func testDegenerateRouteFallsBackGracefully() {
        let route = WalkingRoute(origin: cranfordCenter, destination: cranfordCenter, distanceMeters: 0, durationSeconds: 0, routeCoordinates: [cranfordCenter], source: .straightLineEstimate)
        let p = RouteProgressCalculator.progress(along: route, userLocation: GeoMath.destination(from: cranfordCenter, bearing: 45, distance: 20))
        XCTAssertEqual(p.remainingMeters, 20, accuracy: 0.1)
        XCTAssertTrue(p.remainingSeconds.isFinite)
    }

    func testStraightLineEstimateIsLabeled() {
        let far = GeoMath.destination(from: cranfordCenter, bearing: 90, distance: 1000)
        let route = WalkingRoute.straightLineEstimate(from: cranfordCenter, to: far)
        XCTAssertEqual(route.source, .straightLineEstimate)
        XCTAssertEqual(route.distanceMeters, 1300, accuracy: 1)
        XCTAssertEqual(route.routeCoordinates.count, 2)
    }
}
