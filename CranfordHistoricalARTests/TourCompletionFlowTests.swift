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

    func testUncertainGPSFixCannotOpenOrSkipTheStop() async throws {
        simulator.horizontalAccuracy = 50
        let near = GeoMath.destination(from: stops[0].coordinate, bearing: 90, distance: 20)
        simulator.teleport(to: near)
        try await waitUntil("sloppy near fix is on screen") {
            guard let distance = self.tour.straightLineDistanceToCurrentStop else { return false }
            return abs(distance - 20) < 3
        }
        XCTAssertFalse(tour.isSignPresented, "±50 m must not count as arrival inside a 35 m radius")
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)

        simulator.horizontalAccuracy = 5
        simulator.teleport(to: near)
        try await waitUntil("confident arrival presents the sign") { self.tour.isSignPresented }
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)

        simulator.horizontalAccuracy = 40
        let outside = GeoMath.destination(from: stops[0].coordinate, bearing: 90, distance: 70)
        simulator.teleport(to: outside)
        try await waitUntil("sloppy far fix is on screen") {
            guard let distance = self.tour.straightLineDistanceToCurrentStop else { return false }
            return abs(distance - 70) < 3
        }
        XCTAssertTrue(tour.isSignPresented, "±40 m beyond 50 m must not count as walking away")
        XCTAssertEqual(tour.currentStop?.id, stops[0].id, "an uncertain fix must not skip the stop")

        simulator.horizontalAccuracy = 5
        simulator.teleport(to: outside)
        try await waitUntil("confident departure advances") { self.tour.currentStop?.id == self.stops[1].id }
        XCTAssertFalse(tour.isSignPresented)
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
