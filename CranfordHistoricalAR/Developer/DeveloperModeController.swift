#if DEVELOPER_MENU
import Foundation
import Observation
import TourCore

/// Developer Mode (spec §19): simulate walking the tour without being in Cranford.
/// Compiled only when `DEVELOPER_MENU` is defined (Debug builds — see project.yml).
///
/// It never reaches into subsystems directly: it swaps the tour's `LocationService` for a
/// `SimulatedLocationService` and calls the same `TourViewModel` entry points the UI uses, so a
/// simulated walk exercises exactly the production code paths.
@MainActor
@Observable
final class DeveloperModeController {
    private let tour: TourViewModel
    private let realLocationService: any LocationService
    private(set) var simulator: SimulatedLocationService?

    var isSimulating: Bool { simulator != nil }
    var isWalking: Bool { simulator?.isWalking ?? false }

    /// Default start: a few hundred meters south-west of the first stop so the first leg is real.
    static let defaultStartOffsetMeters: Double = 350
    static let defaultStartBearing: Double = 225

    init(tour: TourViewModel, realLocationService: any LocationService) {
        self.tour = tour
        self.realLocationService = realLocationService
    }

    // MARK: Simulation lifecycle

    func enableSimulation() {
        guard simulator == nil else { return }
        let start: GeoCoordinate
        if let user = tour.userLocation?.coordinate {
            start = user
        } else if let first = tour.stops.first {
            start = GeoMath.destination(from: first.coordinate, bearing: DeveloperModeController.defaultStartBearing, distance: DeveloperModeController.defaultStartOffsetMeters)
        } else {
            start = GeoCoordinate(latitude: 40.6565, longitude: -74.3040)
        }
        let sim = SimulatedLocationService(start: start)
        sim.routeProvider = { [weak self] in self?.currentSimulationRoute() }
        simulator = sim
        tour.replaceLocationService(with: sim)
    }

    func disableSimulation() {
        guard simulator != nil else { return }
        simulator?.stop()
        simulator = nil
        tour.replaceLocationService(with: realLocationService)
    }

    /// Follow the live walking route when there is one; otherwise head straight for the stop.
    private func currentSimulationRoute() -> SimulatedLocationService.Route? {
        guard let stop = tour.currentStop else { return nil }
        let path = tour.currentRoute?.routeCoordinates ?? []
        return SimulatedLocationService.Route(path: path, target: stop.coordinate)
    }

    // MARK: Movement (spec §19: simulated location, move toward next stop, jump to next stop)

    func walkTowardNextStop() {
        enableSimulation()
        simulator?.startWalking()
    }

    func pauseWalking() {
        simulator?.stopWalking()
    }

    func nudgeTowardNextStop(meters: Double = 25) {
        enableSimulation()
        simulator?.nudge(meters: meters)
    }

    /// Teleports to the current destination, which triggers the real arrival flow (sign appears).
    func jumpToNextStop() {
        enableSimulation()
        guard let stop = tour.currentStop else { return }
        // Land just inside the arrival radius rather than on the exact coordinate so the AR sign
        // still has somewhere to stand in front of the camera.
        let landing = GeoMath.destination(
            from: stop.coordinate,
            bearing: SimulatedArrival.jumpBearing,
            distance: SimulatedArrival.jumpLandingDistance(arrivalRadius: stop.arrivalRadius)
        )
        simulator?.teleport(to: landing)
    }

    func teleport(to coordinate: GeoCoordinate) {
        enableSimulation()
        simulator?.teleport(to: coordinate)
    }

    var speedMultiplier: Double {
        get { simulator?.speedMultiplier ?? 1 }
        set { enableSimulation(); simulator?.speedMultiplier = newValue }
    }

    var simulatedAccuracy: Double {
        get { simulator?.horizontalAccuracy ?? 5 }
        set { enableSimulation(); simulator?.horizontalAccuracy = newValue }
    }

    // MARK: Tour (spec §19: trigger historical sign, reset tour)

    func triggerHistoricalSign() {
        if tour.phase == .notStarted { tour.startTour() }
        tour.openSignManually()
    }

    func skipToNextStop() {
        if tour.phase == .notStarted { tour.startTour() }
        tour.completeCurrentStopAndAdvance()
    }

    func resetTour() {
        tour.resetTour()
        simulator?.stopWalking()
    }

    // MARK: Diagnostics

    struct Diagnostics {
        var currentStop: String
        var proximityState: String
        var distanceToStop: String
        var routeSource: String
        var routingError: String?
        var locationIssue: String?
        var walkedMeters: Double
        var completed: String
    }

    var diagnostics: Diagnostics {
        Diagnostics(
            currentStop: tour.currentStop?.name ?? (tour.phase == .complete ? "Tour complete" : "—"),
            proximityState: tour.proximityState?.rawValue ?? "—",
            distanceToStop: tour.straightLineDistanceToCurrentStop.map { String(format: "%.0f m straight-line", $0) } ?? "—",
            routeSource: tour.currentRoute.map { "\($0.source)" } ?? (tour.isRoutingInFlight ? "requesting…" : "none"),
            routingError: tour.routingError,
            locationIssue: tour.locationIssue?.title,
            walkedMeters: tour.progress.walkedMeters,
            completed: "\(tour.progress.completedCount) / \(tour.progress.totalStops)"
        )
    }
}
#endif
