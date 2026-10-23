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
    private let defaults: UserDefaults
    private static let viewingKey = "cranford.developer.mill-viewing-point.v1"
    private static let windowKey = "cranford.developer.mill-window-layout.v1"
    private static let parkKey = "cranford.developer.greystone-bonus-layout.v1"
    private(set) var viewingPointMessage: String?
    private(set) var isRefreshingGPS = false
    private(set) var gpsRefreshMessage: String?
    @ObservationIgnored private var gpsRefreshTask: Task<Void, Never>?
    private(set) var savedViewingAccuracy: Double?
    var savedViewingPoint: GeoCoordinate? { tour.viewingPointOverride }

    var isSimulating: Bool { simulator != nil }
    var isWalking: Bool { simulator?.isWalking ?? false }

    func refreshGPSNow() {
        guard !isRefreshingGPS else { return }
        guard !isSimulating else {
            gpsRefreshMessage = "Turn off Simulated location to refresh device GPS."
            return
        }
        tour.startLocationIfPossible()
        guard realLocationService.authorization == .authorized else {
            gpsRefreshMessage = "Allow location access in iPhone Settings, then try again."
            return
        }
        let requestedAt = Date()
        isRefreshingGPS = true
        gpsRefreshMessage = "Requesting a fresh GPS fix…"
        realLocationService.requestFreshLocation()
        gpsRefreshTask = Task { [weak self] in
            for _ in 0..<75 {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled, let self else { return }
                if self.isSimulating {
                    self.gpsRefreshMessage = "GPS refresh stopped: Simulated location is on."
                    self.isRefreshingGPS = false
                    return
                }
                if let sample = self.tour.userLocation, sample.timestamp >= requestedAt,
                   !sample.isSimulated, sample.horizontalAccuracy.isFinite, sample.horizontalAccuracy >= 0 {
                    self.gpsRefreshMessage = "Fresh GPS coordinates received."
                    self.isRefreshingGPS = false
                    return
                }
            }
            self?.gpsRefreshMessage = "No fresh fix yet. Move outdoors and try again."
            self?.isRefreshingGPS = false
        }
    }

    /// Default start: a few hundred meters south-west of the first stop so the first leg is real.
    static let defaultStartOffsetMeters: Double = 350
    static let defaultStartBearing: Double = 225

    init(tour: TourViewModel, realLocationService: any LocationService, defaults: UserDefaults = .standard) {
        self.tour = tour
        self.realLocationService = realLocationService
        self.defaults = defaults
        if let values = defaults.array(forKey: Self.viewingKey) as? [Double], values.count == 3,
           values.allSatisfy(\.isFinite), values[2] >= 0, values[2] <= 25 {
            let point = GeoCoordinate(latitude: values[0], longitude: values[1])
            if point.isValid { tour.viewingPointOverride = point; savedViewingAccuracy = values[2] }
        }
        if let values = defaults.array(forKey: Self.windowKey) as? [Double], values.count == 4 {
            let layout = WindowBonusLayout(right: values[0], up: values[1], width: values[2], height: values[3])
            if layout.dimensions(plaqueWidthMeters: 0.18) != nil { tour.windowBonusLayout = layout }
        }
        if let values = defaults.array(forKey: Self.parkKey) as? [Double], values.count == 4 {
            let layout = WindowBonusLayout(right: values[0], up: values[1], width: values[2], height: values[3])
            if layout.dimensions(plaqueWidthMeters: SignPlacementPolicy.assumedParkReferenceWidthMeters) != nil {
                tour.parkBonusLayout = layout
            }
        }
    }

    @discardableResult
    func saveViewingPoint() -> Bool {
        guard !isSimulating, let sample = tour.userLocation, !sample.isSimulated,
              StopActivationPolicy.isFresh(sample.timestamp), sample.coordinate.isValid,
              sample.horizontalAccuracy.isFinite, sample.horizontalAccuracy >= 0, sample.horizontalAccuracy <= 25,
              let mill = tour.stops.first(where: { $0.plaque?.referenceImageName == SignPlacementPolicy.millReferenceImageName }),
              GeoMath.distance(from: sample.coordinate, to: mill.coordinate) <= 200 else {
            viewingPointMessage = "Stand at the mill's permitted viewing point with simulation off. Wait for a fresh device location accurate to 25 m or better."
            return false
        }
        tour.viewingPointOverride = sample.coordinate
        savedViewingAccuracy = sample.horizontalAccuracy
        defaults.set([sample.coordinate.latitude, sample.coordinate.longitude, sample.horizontalAccuracy], forKey: Self.viewingKey)
        viewingPointMessage = "Viewing point saved on this device. It adjusts story arrival, not the building's map marker or Google route."
        return true
    }

    func clearViewingPoint() {
        tour.viewingPointOverride = nil
        savedViewingAccuracy = nil
        defaults.removeObject(forKey: Self.viewingKey)
        viewingPointMessage = "Using the approximate site coordinates again."
    }

    var bonusRight: Double {
        get { tour.windowBonusLayout.right }
        set { var layout = tour.windowBonusLayout; layout.right = newValue; saveLayout(layout) }
    }
    var bonusUp: Double {
        get { tour.windowBonusLayout.up }
        set { var layout = tour.windowBonusLayout; layout.up = newValue; saveLayout(layout) }
    }
    var bonusWidth: Double {
        get { tour.windowBonusLayout.width }
        set { var layout = tour.windowBonusLayout; layout.width = newValue; saveLayout(layout) }
    }
    var bonusHeight: Double {
        get { tour.windowBonusLayout.height }
        set { var layout = tour.windowBonusLayout; layout.height = newValue; saveLayout(layout) }
    }
    private func saveLayout(_ layout: WindowBonusLayout) {
        guard layout.dimensions(plaqueWidthMeters: 0.18) != nil else { return }
        tour.windowBonusLayout = layout
        defaults.set([layout.right, layout.up, layout.width, layout.height], forKey: Self.windowKey)
    }
    func resetWindowLayout() {
        tour.windowBonusLayout = WindowBonusLayout()
        defaults.removeObject(forKey: Self.windowKey)
    }

    var parkRight: Double {
        get { tour.parkBonusLayout.right }
        set { var layout = tour.parkBonusLayout; layout.right = newValue; saveParkLayout(layout) }
    }
    var parkUp: Double {
        get { tour.parkBonusLayout.up }
        set { var layout = tour.parkBonusLayout; layout.up = newValue; saveParkLayout(layout) }
    }
    var parkWidth: Double {
        get { tour.parkBonusLayout.width }
        set { var layout = tour.parkBonusLayout; layout.width = newValue; saveParkLayout(layout) }
    }
    var parkHeight: Double {
        get { tour.parkBonusLayout.height }
        set { var layout = tour.parkBonusLayout; layout.height = newValue; saveParkLayout(layout) }
    }
    private func saveParkLayout(_ layout: WindowBonusLayout) {
        guard layout.dimensions(plaqueWidthMeters: SignPlacementPolicy.assumedParkReferenceWidthMeters) != nil else { return }
        tour.parkBonusLayout = layout
        defaults.set([layout.right, layout.up, layout.width, layout.height], forKey: Self.parkKey)
    }
    func resetParkLayout() {
        tour.parkBonusLayout = .abovePlaque
        defaults.removeObject(forKey: Self.parkKey)
    }

    func markStoryRead() {
        if tour.phase == .notStarted { tour.startTour() }
        if let stop = tour.currentStop { tour.finishStory(for: stop.id) }
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
        let landing = GeoMath.destination(from: stop.coordinate, bearing: 200, distance: min(8, stop.arrivalRadius / 3))
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
        if tour.isPlaqueDiscoveryStop, let stop = tour.currentStop {
            tour.discovery.arrive()
            tour.arrivalStoryStopID = stop.id
            return
        }
        tour.openSignManually()
    }

    func skipToNextStop() {
        if tour.phase == .notStarted { tour.startTour() }
        tour.progress.markCurrentStopVisited()
        tour.activeVisitEvidence = .simulation
        tour.completeCurrentStopAndAdvance()
    }

    func resetTour() {
        simulator?.stopWalking()
        tour.resetTour()
    }

    /// Suppresses saved history only; marker activation and Continue still exercise the real flow.
    var isVisitRecordingEnabled: Bool {
        get { tour.isVisitRecordingEnabled }
        set { tour.isVisitRecordingEnabled = newValue }
    }

    func clearVisitsAndResetTour() {
        simulator?.stopWalking()
        tour.clearRecordedActivitiesAndRestart(includingStoriesAndBonuses: false)
    }

    func clearAllActivitiesAndResetTour() {
        simulator?.stopWalking()
        tour.clearRecordedActivitiesAndRestart(includingStoriesAndBonuses: true)
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
