import TourCore
import XCTest
@testable import CranfordHistoricalAR

/// End-to-end view-model flow on the host app (spec §9, §11, §12), driven through the simulated
/// location source exactly as Developer Mode drives it. Runs on a Mac via Product > Test.
@MainActor
final class TourCompletionFlowTests: XCTestCase {
    private var tour: TourViewModel!
    private var simulator: SimulatedLocationService!
    private var stops: [HistoricalStop] { HistoricalStop.previewStops }

    override func setUp() async throws {
        let start = GeoMath.destination(from: stops[0].coordinate, bearing: 225, distance: 300)
        simulator = SimulatedLocationService(start: start)
        tour = TourViewModel(
            stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: simulator,
            directionsService: PreviewDirectionsService()
        )
        await tour.loadStopsIfNeeded()
        XCTAssertEqual(tour.loadState, .loaded)
        tour.startTour()
        try await waitUntil("first location arrives") { self.tour.userLocation != nil }
    }

    func testArrivalMarksVisitedAndClosingAdvances() async throws {
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
        XCTAssertFalse(tour.isSignPresented)

        simulator.teleport(to: stops[0].coordinate)
        try await waitUntil("sign presented on arrival") { self.tour.presentedSignStopID == self.stops[0].id }

        XCTAssertTrue(tour.isCompleted(stops[0]), "visited as soon as the sign has been displayed")
        XCTAssertEqual(tour.proximityState, .signPresented, "arrival must retain the mutated proximity state")
        XCTAssertTrue(tour.hasArrivedAtCurrentStop)
        XCTAssertEqual(tour.currentStop?.id, stops[0].id, "destination does not change while the sign is open")
        XCTAssertNil(tour.lastCompletedStop, "panel must not list the current stop as the previous one")

        tour.closeSign()
        XCTAssertNil(tour.presentedSignStop)
        XCTAssertEqual(tour.currentStop?.id, stops[1].id, "closing the sign at a visited stop advances")
        XCTAssertEqual(tour.lastCompletedStop?.id, stops[0].id)
        XCTAssertEqual(tour.proximityState, .approaching)
        try await waitUntil("new route requested for the next stop") { self.tour.currentRoute?.destination == self.stops[1].coordinate }
    }

    func testManualOpenOutsideGeocodeDoesNotSkipStop() async throws {
        let far = GeoMath.destination(from: stops[0].coordinate, bearing: 90, distance: 80)
        simulator.teleport(to: far)
        try await waitUntil("far location applied") {
            guard let distance = self.tour.straightLineDistanceToCurrentStop else { return false }
            return distance > 70 && distance < 90
        }
        XCTAssertFalse(tour.isSignPresented)

        // Plaque recognition uses this entry point when the physical plate is in frame
        // but the unverified geocode is still outside the departure radius.
        tour.openSignManually()
        XCTAssertEqual(tour.presentedSignStopID, stops[0].id)
        XCTAssertTrue(tour.isCompleted(stops[0]))
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)

        let stillFar = GeoMath.destination(from: stops[0].coordinate, bearing: 45, distance: 85)
        simulator.teleport(to: stillFar)
        try await waitUntil("second far sample applied") {
            guard let distance = self.tour.straightLineDistanceToCurrentStop else { return false }
            return distance > 82 && distance < 95
        }
        XCTAssertEqual(tour.presentedSignStopID, stops[0].id, "sign must stay up while GPS is still outside the geocode")
        XCTAssertEqual(tour.currentStop?.id, stops[0].id, "the next GPS sample must not skip the stop")
        XCTAssertEqual(tour.proximityState, .signPresented)
    }

    func testWalkingAwayAfterSeeingSignAdvances() async throws {
        simulator.teleport(to: stops[0].coordinate)
        try await waitUntil("sign presented") { self.tour.isSignPresented }

        // Still inside the departure radius: hysteresis keeps the sign up.
        simulator.teleport(to: GeoMath.destination(from: stops[0].coordinate, bearing: 90, distance: 42))
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(tour.isSignPresented)
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)

        simulator.teleport(to: GeoMath.destination(from: stops[0].coordinate, bearing: 90, distance: 60))
        try await waitUntil("sign dismissed beyond departure radius") { !self.tour.isSignPresented }
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
    }

    func testManualCompletionRunsToTourComplete() async throws {
        for index in stops.indices {
            XCTAssertEqual(tour.currentStop?.id, stops[index].id)
            tour.completeCurrentStopAndAdvance()
        }
        XCTAssertEqual(tour.phase, .complete)
        XCTAssertNil(tour.currentStop)
        XCTAssertNil(tour.proximityMachine)
        XCTAssertNil(tour.currentRoute)
        let figures = tour.completionFigures
        XCTAssertEqual(figures.visitedCount, stops.count)
        XCTAssertEqual(figures.totalStops, stops.count)
        XCTAssertFalse(figures.isDistanceMeasured, "a jumped-through tour reports the routed distance, not GPS movement")

        tour.resetTour()
        XCTAssertEqual(tour.phase, .inProgress)
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
        XCTAssertEqual(tour.progress.completedCount, 0)
    }

    func testSimulatedWalkerReachesStopAndRecordsDistance() async throws {
        simulator.speedMultiplier = 10
        simulator.routeProvider = { [tour] in
            guard let tour, let stop = tour.currentStop else { return nil }
            return SimulatedLocationService.Route(path: tour.currentRoute?.routeCoordinates ?? [], target: stop.coordinate)
        }
        simulator.startWalking()
        try await waitUntil("walker arrives", timeout: 40) { !self.simulator.isWalking }
        XCTAssertTrue(tour.isSignPresented, "crossing the arrival radius presented the sign")
        XCTAssertGreaterThan(tour.progress.walkedMeters, 200)
        XCTAssertLessThan(tour.remainingDistanceMeters ?? .infinity, 5)
    }

    // MARK: Helpers

    private func waitUntil(_ description: String, timeout: TimeInterval = 5, _ condition: @escaping @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("Timed out waiting for: \(description)")
    }
}
