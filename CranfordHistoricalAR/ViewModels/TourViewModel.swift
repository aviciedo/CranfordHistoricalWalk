import Foundation
import Observation
import TourCore

/// Single source of truth for the tour (spec §17): stops, progress, the user's location and
/// heading. Stage 2 adds the location pipeline; routing and AR state follow in later stages.
@MainActor
@Observable
final class TourViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    /// User-facing location problems (spec §21). `nil` means everything is fine.
    enum LocationIssue: Equatable {
        case permissionNotDetermined
        case permissionDenied
        case permissionRestricted
        case reducedAccuracy
        case waitingForSignal
        case poorAccuracy(meters: Double)
        case failure(String)

        var title: String {
            switch self {
            case .permissionNotDetermined: return "Location access needed"
            case .permissionDenied: return "Location access is off"
            case .permissionRestricted: return "Location access is restricted"
            case .reducedAccuracy: return "Precise location is off"
            case .waitingForSignal: return "Finding your location…"
            case .poorAccuracy: return "GPS signal is weak"
            case .failure: return "Location problem"
            }
        }

        var message: String {
            switch self {
            case .permissionNotDetermined:
                return "Cranford Historical AR needs your location to guide you between stops and reveal AR signs when you arrive."
            case .permissionDenied:
                return "Turn on location access in Settings to see where you are and follow the walking route. You can still browse the stops."
            case .permissionRestricted:
                return "Location services are restricted on this device, so live navigation is unavailable."
            case .reducedAccuracy:
                return "Precise location helps AR arrows and signs line up with the streets. Enable it in Settings or allow it once when prompted."
            case .waitingForSignal:
                return "Walk outdoors with a clear view of the sky for the best GPS signal."
            case .poorAccuracy(let meters):
                return "Position is accurate to about \(Int(meters)) m. Distances may be approximate until the signal improves."
            case .failure(let text):
                return text
            }
        }

        var isBlocking: Bool {
            switch self {
            case .permissionDenied, .permissionRestricted: return true
            default: return false
            }
        }
    }

    // MARK: Tour data
    private(set) var tourName: String = "Cranford Historical Walk"
    private(set) var dataStatus: String?
    private(set) var stops: [HistoricalStop] = []
    private(set) var loadState: LoadState = .idle
    /// Internal setter: the proximity/completion extension (separate file) mutates it.
    var progress = TourProgress(stopIDs: [])

    // MARK: Location
    private(set) var userLocation: LocationSample?
    private(set) var heading: HeadingSample?
    private(set) var locationAuthorization: LocationAuthorization = .notDetermined
    private(set) var isPreciseLocation = true
    private(set) var locationIssue: LocationIssue? = .permissionNotDetermined
    private(set) var lastLocationFailure: LocationFailure?

    /// Accuracy worse than this is reported to the user as "weak GPS".
    static let poorAccuracyThreshold: Double = 40

    // MARK: Routing (mutated by TourViewModel+Routing.swift)
    var currentRoute: WalkingRoute?
    var routeProgress: RouteProgress?
    var isRoutingInFlight = false
    var routingError: String?
    var lastRouteRequest: RouteRequestRecord?
    /// Stop→stop legs used for the tour summary, keyed by `legKey(from:to:)` / `startLegKey`.
    var legRoutes: [String: WalkingRoute] = [:]
    var refreshPolicy = RouteRefreshPolicy.default
    @ObservationIgnored var routingTask: Task<Void, Never>?
    @ObservationIgnored var summaryLegsTask: Task<Void, Never>?
    @ObservationIgnored var routingGeneration = 0

    // MARK: Proximity / AR sign (mutated by TourViewModel+Proximity.swift)
    var proximityMachine: StopProximityStateMachine?
    /// Visual confirmation overrides an unverified geocode until the visitor continues.
    var plaqueConfirmedStopID: String?
    var presentedSignStopID: String?
    var signPresentationSource: SignPresentationSource?
    var visitRecords: [StopVisitRecord]
    var activeVisitEvidence: StopVisitEvidence?
    let visitStore: any StopVisitStore
    var discovery = StopDiscovery()
    var arrivalStoryStopID: String?
    var windowBonusLayout = WindowBonusLayout()
    var parkBonusLayout = WindowBonusLayout.abovePlaque
    #if DEVELOPER_MENU
    /// Testing only. Defaults to recording on each launch; does not affect this walk's progress.
    var isVisitRecordingEnabled = true
    var viewingPointOverride: GeoCoordinate?
    #endif

    // MARK: Navigation
    private(set) var isShowingTour = false

    private let stopService: any HistoricalStopService
    let directionsService: any DirectionsService
    private(set) var locationService: any LocationService
    private var locationTask: Task<Void, Never>?

    init(stopService: any HistoricalStopService, locationService: any LocationService, directionsService: any DirectionsService, visitStore: (any StopVisitStore)? = nil) {
        let store = visitStore ?? InMemoryStopVisitStore()
        self.visitStore = store
        self.visitRecords = store.records()
        self.stopService = stopService
        self.locationService = locationService
        self.directionsService = directionsService
        self.locationAuthorization = locationService.authorization
        self.isPreciseLocation = locationService.isPreciseLocationAuthorized
        refreshLocationIssue()
    }

    // MARK: Derived state

    var phase: TourPhase { progress.phase }

    var currentStop: HistoricalStop? { progress.currentStopID.flatMap(stop(withID:)) }
    var nextStop: HistoricalStop? { progress.nextStopID.flatMap(stop(withID:)) }
    var lastCompletedStop: HistoricalStop? { progress.previousCompletedStopID.flatMap(stop(withID:)) }

    func stop(withID id: String) -> HistoricalStop? { stops.first { $0.id == id } }
    func isCompleted(_ stop: HistoricalStop) -> Bool { progress.isCompleted(stop.id) }

    /// Heading to draw on the map/AR: compass when reliable, else GPS course while moving.
    var displayHeading: Double? {
        if let heading, heading.isReliable { return heading.bestHeading }
        if let userLocation, let course = userLocation.course, (userLocation.speed ?? 0) > 0.5 { return course }
        return nil
    }

    var hasReliableHeading: Bool { displayHeading != nil }

    /// Straight-line distance to the current stop. Used for proximity only — never for the
    /// navigation panel, which uses the walking route (spec §5).
    var straightLineDistanceToCurrentStop: Double? {
        guard let userLocation, let currentStop else { return nil }
        return GeoMath.distance(from: userLocation.coordinate, to: currentStop.coordinate)
    }

    var hasUsableLocation: Bool {
        guard let userLocation else { return false }
        return userLocation.horizontalAccuracy >= 0 && Date().timeIntervalSince(userLocation.timestamp) < 60
    }

    // MARK: Loading

    func loadStopsIfNeeded() async {
        guard loadState == .idle || loadState.isFailure else { return }
        loadState = .loading
        do {
            let document = try await stopService.loadTour()
            tourName = document.tourName
            dataStatus = document.dataStatus
            stops = document.stops
            progress = TourProgress(stopIDs: document.stops.map(\.id))
            loadState = .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    // MARK: Tour lifecycle

    func startTour() {
        guard loadState == .loaded, !stops.isEmpty else { return }
        if progress.phase == .notStarted {
            progress.start()
        }
        isShowingTour = true
        startLocationIfPossible()
        loadTourSummaryLegsIfNeeded()
        evaluateRouteRefresh()
        if proximityMachine == nil { resetProximityForCurrentStop() }
    }

    /// Explicit AR entry starts the first destination, resumes the current one, or restarts
    /// a completed walk. Browsing a different detail never jumps the guided destination.
    @discardableResult
    func prepareForARFromDetails() -> Bool {
        guard loadState == .loaded, !stops.isEmpty else { return false }
        if phase == .complete { resetTour() }
        startTour()
        return phase == .inProgress && currentStop != nil
    }

    func leaveTour() {
        isShowingTour = false
    }

    func resetTour() {
        cancelRouting()
        progress.reset()
        progress.start()
        destinationDidChange()
        loadTourSummaryLegsIfNeeded()
    }

    // MARK: Location pipeline

    /// Idempotent: subscribes to the location service and asks for permission when needed.
    func startLocationIfPossible() {
        if locationTask == nil {
            let stream = locationService.events()
            locationTask = Task { [weak self] in
                for await event in stream {
                    guard let self, !Task.isCancelled else { return }
                    self.handle(event)
                }
            }
        }
        switch locationService.authorization {
        case .notDetermined:
            locationService.requestWhenInUseAuthorization()
        case .authorized:
            locationService.start()
            locationService.requestTemporaryPreciseLocationIfNeeded()
        case .denied, .restricted:
            break
        }
        refreshLocationIssue()
    }

    func stopLocation() {
        locationTask?.cancel()
        locationTask = nil
        locationService.stop()
    }

    /// Swaps the live source (used by Developer Mode to inject a simulator). Re-subscribes.
    func replaceLocationService(with service: any LocationService) {
        let wasRunning = locationTask != nil
        stopLocation()
        locationService = service
        locationAuthorization = service.authorization
        isPreciseLocation = service.isPreciseLocationAuthorized
        userLocation = nil
        heading = nil
        if wasRunning || isShowingTour { startLocationIfPossible() }
    }

    private func handle(_ event: LocationEvent) {
        switch event {
        case .authorization(let status, let precise):
            locationAuthorization = status
            isPreciseLocation = precise
            if status == .authorized {
                locationService.start()
                locationService.requestTemporaryPreciseLocationIfNeeded()
            }
            refreshLocationIssue()

        case .location(let sample):
            guard sample.coordinate.isValid, StopActivationPolicy.isFresh(sample.timestamp),
                  userLocation.map({ sample.timestamp >= $0.timestamp }) ?? true else { return }
            if let previous = userLocation, progress.phase == .inProgress,
               sample.horizontalAccuracy >= 0, sample.horizontalAccuracy <= TourViewModel.poorAccuracyThreshold,
               previous.horizontalAccuracy >= 0, previous.horizontalAccuracy <= TourViewModel.poorAccuracyThreshold {
                let moved = GeoMath.distance(from: previous.coordinate, to: sample.coordinate)
                // Ignore GPS jitter when accumulating walked distance.
                if moved > max(2, sample.horizontalAccuracy * 0.5) { progress.recordWalked(meters: moved) }
            }
            userLocation = sample
            lastLocationFailure = nil
            refreshLocationIssue()
            didUpdateLocation(sample)

        case .heading(let sample):
            heading = sample

        case .failure(let failure):
            lastLocationFailure = failure
            refreshLocationIssue()
        }
    }

    /// Fan-out for location-dependent subsystems. Kept separate so `handle` stays readable.
    func didUpdateLocation(_ sample: LocationSample) {
        handleLocationForRouting(sample)
        handleLocationForProximity(sample)
    }

    private func refreshLocationIssue() {
        switch locationAuthorization {
        case .notDetermined:
            locationIssue = .permissionNotDetermined
        case .denied:
            locationIssue = .permissionDenied
        case .restricted:
            locationIssue = .permissionRestricted
        case .authorized:
            if let failure = lastLocationFailure, userLocation == nil {
                switch failure {
                case .denied: locationIssue = .permissionDenied
                case .locationUnknown: locationIssue = .waitingForSignal
                case .network: locationIssue = .failure("Location needs a network connection right now.")
                case .other(let text): locationIssue = .failure(text)
                }
            } else if !isPreciseLocation {
                locationIssue = .reducedAccuracy
            } else if let userLocation {
                locationIssue = userLocation.horizontalAccuracy > TourViewModel.poorAccuracyThreshold
                    ? .poorAccuracy(meters: userLocation.horizontalAccuracy)
                    : nil
            } else {
                locationIssue = .waitingForSignal
            }
        }
    }
}

extension TourViewModel.LoadState {
    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}
