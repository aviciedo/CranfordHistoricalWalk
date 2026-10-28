import XCTest
@testable import TourCore

final class TourSummaryAndFormattingTests: XCTestCase {
    func testSummarySumsLegs() throws {
        let stops = try Fixtures.sampleStops()
        var legs: [WalkingRoute?] = []
        var cursor = cranfordCenter
        for stop in stops {
            let d = GeoMath.distance(from: cursor, to: stop.coordinate) * 1.2
            legs.append(WalkingRoute(origin: cursor, destination: stop.coordinate, distanceMeters: d, durationSeconds: d / 1.4, routeCoordinates: [cursor, stop.coordinate], source: .googleRoutesAPI))
            cursor = stop.coordinate
        }
        let summary = TourSummary.make(stops: stops, legs: legs)
        XCTAssertEqual(summary.stopCount, 3)
        XCTAssertTrue(summary.isFromWalkingRoutes)
        XCTAssertEqual(summary.pendingLegCount, 0)
        XCTAssertEqual(summary.totalDistanceMeters, legs.compactMap { $0?.distanceMeters }.reduce(0, +), accuracy: 0.001)
        XCTAssertEqual(summary.totalWalkingSeconds, legs.compactMap { $0?.durationSeconds }.reduce(0, +), accuracy: 0.001)

        let withVisits = TourSummary.make(stops: stops, legs: legs, includeVisitTime: true)
        XCTAssertEqual(withVisits.totalVisitSeconds, 90 + 90 + 120)
    }

    func testAppleAndLegacyRoutesStayRealWhileEstimatesDoNot() throws {
        let stops = try Fixtures.sampleStops()
        let origin = cranfordCenter
        func leg(_ source: RouteSource) -> WalkingRoute {
            WalkingRoute(origin: origin, destination: stops[0].coordinate, distanceMeters: 120,
                         durationSeconds: 90, routeCoordinates: [origin, stops[0].coordinate], source: source)
        }
        for source in [RouteSource.appleMaps, .googleRoutesAPI, .googleDirectionsLegacy] {
            let partial = TourSummary.make(stops: stops, legs: [leg(source)] + Array(repeating: nil, count: stops.count - 1))
            XCTAssertFalse(partial.isFromWalkingRoutes)
            XCTAssertEqual(partial.pendingLegCount, stops.count - 1)
            let complete = TourSummary.make(stops: [stops[0]], legs: [leg(source)])
            XCTAssertTrue(complete.isFromWalkingRoutes, "\(source) is a street route")
            XCTAssertEqual(complete.totalDistanceMeters, 120, accuracy: 0.001)
            XCTAssertEqual(complete.totalWalkingSeconds, 90, accuracy: 0.001)
            let decoded = try JSONDecoder().decode(WalkingRoute.self, from: JSONEncoder().encode(leg(source)))
            XCTAssertEqual(decoded.source, source)
        }
        let estimate = TourSummary.make(stops: [stops[0]], legs: [
            WalkingRoute.straightLineEstimate(from: origin, to: stops[0].coordinate)
        ])
        XCTAssertFalse(estimate.isFromWalkingRoutes)
        XCTAssertEqual(estimate.pendingLegCount, 0)
    }

    func testSummaryFlagsPendingAndEstimatedLegs() throws {
        let stops = try Fixtures.sampleStops()
        var legs: [WalkingRoute?] = Array(repeating: nil, count: stops.count)
        legs[0] = WalkingRoute.straightLineEstimate(from: cranfordCenter, to: stops[0].coordinate)
        let summary = TourSummary.make(stops: stops, legs: legs)
        XCTAssertFalse(summary.isFromWalkingRoutes)
        XCTAssertEqual(summary.pendingLegCount, 2)
    }

    func testDistanceFormatting() {
        XCTAssertEqual(DistanceFormatter.distance(meters: 643.7), "0.4 mi")
        XCTAssertEqual(DistanceFormatter.distance(meters: 100), "330 ft")
        XCTAssertEqual(DistanceFormatter.distance(meters: 0), "0 ft")
        XCTAssertEqual(DistanceFormatter.distance(meters: 20_000), "12 mi")
        XCTAssertEqual(DistanceFormatter.distance(meters: 850, units: .metric), "850 m")
        XCTAssertEqual(DistanceFormatter.distance(meters: 2_340, units: .metric), "2.3 km")
        XCTAssertEqual(DistanceFormatter.distance(meters: .nan), "—")
        XCTAssertEqual(DistanceFormatter.headerDistance(meters: 3379.6), "2.1 MILES")
    }

    func testDurationFormatting() {
        XCTAssertEqual(DistanceFormatter.duration(seconds: 10), "< 1 min")
        XCTAssertEqual(DistanceFormatter.duration(seconds: 61), "2 min")
        XCTAssertEqual(DistanceFormatter.duration(seconds: 480), "8 min")
        XCTAssertEqual(DistanceFormatter.duration(seconds: 3600), "1 hr")
        XCTAssertEqual(DistanceFormatter.duration(seconds: 3900), "1 hr 5 min")
        XCTAssertEqual(DistanceFormatter.approximateDuration(seconds: 42 * 60), "~42 MINUTES")
        XCTAssertEqual(DistanceFormatter.approximateDuration(seconds: 65 * 60), "~1 HR 5 MIN")
    }

    func testCountdownDecreasesMonotonicallyAlongRoute() {
        // Spec §12: 0.6 mi / 11 min -> 0.5 mi / 9 min -> 0.3 mi / 6 min ...
        let route = makeRoute(from: cranfordCenter, bearing: 0, segments: 10, segmentMeters: 100, speed: 1.4)
        var pos = cranfordCenter
        var lastMeters = Double.greatestFiniteMagnitude
        var lastSeconds = Double.greatestFiniteMagnitude
        let sim = WalkSimulator(metersPerSecond: 1.4)
        var arrived = false
        for _ in 0..<100 where !arrived {
            let p = RouteProgressCalculator.progress(along: route, userLocation: pos)
            XCTAssertLessThanOrEqual(p.remainingMeters, lastMeters)
            XCTAssertLessThanOrEqual(p.remainingSeconds, lastSeconds)
            lastMeters = p.remainingMeters
            lastSeconds = p.remainingSeconds
            arrived = sim.step(from: pos, toward: route.destination, deltaTime: 10).didArrive
            pos = sim.step(from: pos, toward: route.destination, deltaTime: 10).coordinate
        }
        XCTAssertTrue(arrived)
        XCTAssertEqual(RouteProgressCalculator.progress(along: route, userLocation: pos).remainingMeters, 0, accuracy: 0.5)
    }
}
