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
    private(set) var catalogIdentity = TourCatalogIdentity.legacy
    private(set) var walkSessionID = UUID()
    private(set) var tourName: String = "Cranford Historical Walk"
    private(set) var dataStatus: String?
    private(set) var stops: [HistoricalStop] = []
    private(set) var loadState: LoadState = .idle
    /// Internal setter: the proximity/completion extension (separate file) mutates it.
    var progress = TourProgress(stopIDs: []) {
        didSet { checkpointWalk() }
    }
    private(set) var isWalkPaused = false
    var isWalkingActive: Bool { phase == .inProgress && !isWalkPaused }
    private let walkResumeStore: any WalkResumeStore
    private(set) var restoredCompletionSummary: TourSummary?

    // MARK: Location
    private(set) var userLocation: LocationSample?
    private(set) var heading: HeadingSample?
    private(set) var locationAuthorization: LocationAuthorization = .notDetermined
    private(set) var isPreciseLocation = true
    private(set) var locationIssue: LocationIssue? = .permissionNotDetermined
    private(set) var lastLocationFailure: LocationFailure?

    /// Accuracy worse than this is reported to the user as "weak GPS".
    static let poorAccuracyThreshold: Double = StopActivationPolicy.maximumAccuracyMeters

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
    @ObservationIgnored var routeRecoveryTask: Task<Void, Never>?
    var routeRecoveryAttempts = 0
    var routeRecoveryDelay: Duration = .seconds(30)
    var retryRouteOnFreshLocation = false

    // MARK: Proximity / AR sign (mutated by TourViewModel+Proximity.swift)
    var proximityMachine: StopProximityStateMachine?
    var walkingProgression = WalkingProgressionPolicy()
    var passiveVisitPolicies: [String: WalkingProgressionPolicy] = [:]
    var heldDepartureStopID: String? {
        didSet { checkpointWalk() }
    }
    /// Only foreground Map can change the itinerary automatically. Browsing and AR hold it.
    var isAutomaticNavigationVisible = false {
        didSet {
            if !isAutomaticNavigationVisible { walkingProgression.interrupt() }
            else { advanceAfterLoggedVisitIfAllowed() }
        }
    }
    var explorationHolds: Set<UUID> = [] {
        didSet {
            if !explorationHolds.isEmpty { walkingProgression.interrupt() }
            else { advanceAfterLoggedVisitIfAllowed() }
        }
    }
    var automaticTransitionFromStopID: String?
    var automaticTransitionProgress: TourProgress?
    var isAutomaticNavigationAllowed: Bool {
        isWalkingActive && isAutomaticNavigationVisible && explorationHolds.isEmpty && !isARSessionActive
    }

    /// Visual confirmation overrides an unverified geocode until the visitor continues.
    var plaqueConfirmedStopID: String?
    var presentedSignStopID: String?
    var signPresentationSource: SignPresentationSource?
    var visitRecords: [StopVisitRecord]
    var activeVisitEvidence: StopVisitEvidence?
    let visitStore: any StopVisitStore
    let activityStore: any StopActivityStore
    /// One foreground celebration, emitted only after a new real plaque sketch is saved.
    /// Collection itself is derived from the existing ledger, so old discoveries need no migration.
    var pendingSketchStopID: String?
    var sketchbookStops: [HistoricalStop] { stops.filter(\.hasPlaqueReference) }
    var sketchbookCollectedCount: Int { sketchbookStops.filter { activities[$0.id].plaqueUnlockedAt != nil }.count }
    func takeUnlockedSketch() -> String? {
        defer { pendingSketchStopID = nil }
        guard let id = pendingSketchStopID,
              sketchbookStops.contains(where: { $0.id == id }), activities[id].plaqueUnlockedAt != nil else { return nil }
        return id
    }
    var activities: StopActivityLedger
    /// AR may inspect a different physical site without changing the walking destination.
    var arStop: HistoricalStop? { arDiscoveryStopID.flatMap(stop(withID:)) ?? currentStop }
    var discovery: StopDiscovery {
        get { arStop.map { discoveriesByStopID[$0.id] ?? StopDiscovery() } ?? StopDiscovery() }
        set { if let id = arStop?.id { discoveriesByStopID[id] = newValue } }
    }
    var discoveriesByStopID: [String: StopDiscovery] = [:]
    /// Hold a selected site's story/discovery through GPS fixes and AR presentation.
    var arDiscoveryStopID: String?
    var isARSessionActive = false {
        didSet {
            if isARSessionActive { walkingProgression.interrupt() }
            else { advanceAfterLoggedVisitIfAllowed() }
        }
    }
    /// Session-local GPS trace, separate from provider directions and saved test captures.
    private(set) var walkedTrailSegments: [[GeoCoordinate]] = []
    @ObservationIgnored private var lastTrailSample: LocationSample?
    var continuedARStopIDs: Set<String> = []
    var arrivalStoryStopID: String?
    #if DEVELOPER_MENU
    /// Testing only. Defaults to recording on each launch; does not affect this walk's progress.
    var isVisitRecordingEnabled = true
    #endif

    // MARK: Navigation
    private(set) var isShowingTour = false

    private let stopService: any HistoricalStopService
    let directionsService: any DirectionsService
    private(set) var locationService: any LocationService
    private var locationTask: Task<Void, Never>?
    private var lastMapLocationRefreshAt: Date?

    init(stopService: any HistoricalStopService, locationService: any LocationService, directionsService: any DirectionsService, visitStore: (any StopVisitStore)? = nil, activityStore: (any StopActivityStore)? = nil, walkResumeStore: (any WalkResumeStore)? = nil) {
        self.walkResumeStore = walkResumeStore ?? InMemoryWalkResumeStore()
        let store = visitStore ?? InMemoryStopVisitStore()
        self.visitStore = store
        self.visitRecords = store.records()
        let activityStorage = activityStore ?? InMemoryStopActivityStore()
        self.activityStore = activityStorage
        var savedActivities = activityStorage.load()
        savedActivities.importVisits(store.records())
        self.activities = savedActivities
        activityStorage.save(savedActivities)
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

    /// Home previews the next leg after a confirmed visit without changing routing.
    /// Explicit backtracking still features the selected previous destination.
    private var homeOffersNextLeg: Bool {
        isCurrentVisitConfirmed && heldDepartureStopID != currentStop?.id
    }
    var homeFeaturedStop: HistoricalStop? {
        guard phase == .inProgress else { return stops.first }
        return homeOffersNextLeg ? (nextStop ?? currentStop) : currentStop
    }

    var homeWalkActionTitle: String {
        switch phase {
        case .notStarted: return "Start walk"
        case .inProgress: return homeOffersNextLeg && nextStop == nil ? "Finish walk" : "Continue walk"
        case .complete: return "Start another walk"
        }
    }

    /// Act on the same leg Home presents. Merely opening Home never advances the walk.
    func performHomeWalkAction() {
        guard loadState == .loaded, !stops.isEmpty else { return }
        if phase == .complete { resetTour() }
        else if homeOffersNextLeg {
            startNextLegAfterConfirmedVisit()
            return
        }
        startTour()
    }

    var startWalkTitle: String {
        stops.first.map { "Start walk: \($0.name)" } ?? "Start walk"
    }

    /// Only this walk's arrival matters; saved story/sketch progress never changes its wording.
    var isHeadingToFirstStop: Bool {
        phase == .inProgress && currentStop?.id == stops.first?.id
            && heldDepartureStopID != currentStop?.id
            && !progress.isCurrentStopVisited && !isAtCurrentStopNow
    }

    var walkActionTitle: String {
        switch phase {
        case .notStarted: return startWalkTitle
        case .inProgress: return isHeadingToFirstStop ? startWalkTitle : "Continue your walk"
        case .complete: return "Walk it again"
        }
    }

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
            catalogIdentity = document.identity
            visitStore.selectTour(catalogIdentity)
            activityStore.selectTour(catalogIdentity)
            walkResumeStore.selectTour(catalogIdentity)
            visitRecords = visitStore.records()
            activities = activityStore.load()
            activities.importVisits(visitRecords)
            activityStore.save(activities)
            tourName = document.tourName
            dataStatus = document.dataStatus
            stops = document.stops
            let ids = document.stops.map(\.id)
            if let saved = walkResumeStore.load(), saved.isValid(for: catalogIdentity, stopIDs: ids) {
                walkSessionID = saved.sessionID ?? UUID()
                progress = saved.progress
                heldDepartureStopID = saved.departureHoldStopID
                isWalkPaused = progress.phase == .inProgress
                restoredCompletionSummary = saved.completionSummary
            } else {
                progress = TourProgress(stopIDs: ids)
                isWalkPaused = false
                walkResumeStore.save(nil)
            }
            loadState = .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    // MARK: Tour lifecycle

    func startTour() {
        guard loadState == .loaded, !stops.isEmpty else { return }
        if progress.phase == .notStarted {
            walkSessionID = UUID()
            progress.start()
        }
        isWalkPaused = false
        isShowingTour = true
        advanceAfterLoggedVisitIfAllowed()
        checkpointWalk()
        startLocationIfPossible()
        loadTourSummaryLegsIfNeeded()
        evaluateRouteRefresh()
        if proximityMachine == nil { resetProximityForCurrentStop() }
    }

    /// Stop guidance without discarding the itinerary, visits, sketches or recorded trail.
    func stopWalk() {
        guard isWalkingActive else { return }
        isWalkPaused = true
        cancelRouting()
        currentRoute = nil
        routeProgress = nil
        routingError = nil
        lastRouteRequest = nil
        lastTrailSample = nil
        interruptVisitDwell()
        checkpointWalk()
    }

    func interruptVisitDwell() {
        walkingProgression.interrupt()
        for id in Array(passiveVisitPolicies.keys) { passiveVisitPolicies[id]?.interrupt() }
    }

    /// Map entry resumes the walk; an explicit detail entry targets that selected site.
    /// Browsing details alone still never changes the destination.
    @discardableResult
    func prepareForARFromDetails(stopID: String? = nil) -> Bool {
        guard loadState == .loaded, !stops.isEmpty else { return false }
        if let stopID {
            guard stop(withID: stopID) != nil else { return false }
            arDiscoveryStopID = stopID
            presentedSignStopID = nil
            plaqueConfirmedStopID = nil
            continuedARStopIDs.remove(stopID)
            restoreDiscovery(for: stopID)
            return arStop != nil
        }
        guard phase != .complete else { return false }
        // Map AR always guides the walking destination, even after browsing another plaque.
        arDiscoveryStopID = nil
        plaqueConfirmedStopID = nil
        presentedSignStopID = nil
        signPresentationSource = nil
        startTour()
        return phase == .inProgress && currentStop != nil
    }

    /// Camera-only discovery never starts/resets routing, requests GPS or changes its itinerary.
    @discardableResult
    func preparePlaqueScanner(stopID: String) -> Bool {
        guard let stop = stop(withID: stopID), stop.hasPlaqueReference else { return false }
        guard prepareForARFromDetails(stopID: stopID) else { return false }
        continuedARStopIDs = []
        return beginPlaqueDiscovery()
    }

    func leaveTour() {
        isShowingTour = false
    }

    /// Explicit replay can start immediately; developer resets return to the welcome state.
    func resetTour(startImmediately: Bool = true) {
        walkedTrailSegments = []
        passiveVisitPolicies = [:]
        lastTrailSample = nil
        walkSessionID = UUID()
        automaticTransitionFromStopID = nil
        automaticTransitionProgress = nil
        heldDepartureStopID = nil
        walkingProgression = WalkingProgressionPolicy()
        isWalkPaused = false
        restoredCompletionSummary = nil
        cancelRouting()
        legRoutes = [:]
        lastRouteRequest = nil
        discoveriesByStopID = [:]
        continuedARStopIDs = []
        arDiscoveryStopID = nil
        progress.reset()
        if startImmediately { progress.start() }
        else { isShowingTour = false }
        destinationDidChange()
        if startImmediately { loadTourSummaryLegsIfNeeded() }
    }

    #if DEVELOPER_MENU
    /// Visit-only and full testing resets are explicit, separate operations.
    func clearRecordedActivitiesAndRestart(includingStoriesAndSketches: Bool) {
        visitStore.removeAll()
        visitRecords = visitStore.records()
        pendingSketchStopID = nil
        if includingStoriesAndSketches { activities = StopActivityLedger() }
        else { activities.clearVisits() }
        activityStore.save(activities)
        resetTour(startImmediately: false)
    }
    #endif

    /// Snapshot only local itinerary context, never GPS history or playback state.
    func checkpointWalk() {
        guard loadState == .loaded else { return }
        guard progress.phase != .notStarted else { walkResumeStore.save(nil); return }
        walkResumeStore.save(WalkResumeRecord(progress: progress,
            completionSummary: progress.phase == .complete ? tourSummary : nil,
            catalogIdentity: catalogIdentity, sessionID: walkSessionID, departureHoldStopID: heldDepartureStopID == currentStop?.id ? heldDepartureStopID : nil))
    }

    // MARK: Location pipeline

    /// Idempotent: subscribes to the location service and asks for permission when needed.
    func startLocationIfPossible() {
        if locationTask == nil {
            // Give the continuous stream time to acquire its first fix before recovery.
            lastMapLocationRefreshAt = Date()
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

    /// Recovery only: healthy continuous updates are never replaced by polling.
    /// Called while the foreground Map is visible, independently of itinerary pause state.
    func refreshMapLocationIfNeeded(now: Date = Date()) {
        refreshLocationIssue()
        guard locationTask != nil, locationAuthorization == .authorized else { return }
        if let sample = userLocation, now.timeIntervalSince(sample.timestamp) < 10 { return }
        if let last = lastMapLocationRefreshAt, now.timeIntervalSince(last) < 15 { return }
        lastMapLocationRefreshAt = now
        locationService.requestFreshLocation()
    }

    func stopLocation() {
        interruptVisitDwell()
        lastTrailSample = nil
        lastMapLocationRefreshAt = nil
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
        walkingProgression.interrupt()
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
            if let previous = userLocation, isWalkingActive,
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
        recordWalkedTrail(sample)
        handleLocationForRouting(sample)
        handleLocationForProximity(sample)
        evaluateAutomaticProgression(sample)
    }

    /// Retain real walking fixes; split at pauses, signal loss and GPS jumps.
    func recordWalkedTrail(_ sample: LocationSample, now: Date = Date()) {
        guard isWalkingActive, locationAuthorization == .authorized,
              !sample.isSimulated, !(locationService is SimulatedLocationService),
              sample.coordinate.isValid, StopActivationPolicy.isFresh(sample.timestamp, now: now),
              sample.horizontalAccuracy.isFinite, (0...25).contains(sample.horizontalAccuracy),
              sample.speed.map({ $0.isFinite && $0 <= 4 }) ?? true else {
            lastTrailSample = nil
            return
        }
        let previous = lastTrailSample
        if let previous, sample.timestamp <= previous.timestamp { return }
        lastTrailSample = sample
        let continues: Bool
        if let previous {
            let elapsed = sample.timestamp.timeIntervalSince(previous.timestamp)
            continues = elapsed <= 10 && GeoMath.distance(from: previous.coordinate, to: sample.coordinate) / elapsed <= 4
        } else { continues = false }
        if continues, let last = walkedTrailSegments.last?.last {
            if GeoMath.distance(from: last, to: sample.coordinate) >= 2 {
                walkedTrailSegments[walkedTrailSegments.count - 1].append(sample.coordinate)
            }
        } else if walkedTrailSegments.last?.count == 1 {
            walkedTrailSegments[walkedTrailSegments.count - 1] = [sample.coordinate]
        } else { walkedTrailSegments.append([sample.coordinate]) }
        // Bound long-session rendering cost without connecting separate GPS segments.
        while walkedTrailSegments.reduce(0, { $0 + $1.count }) > 6000 {
            if walkedTrailSegments[0].count > 2 { walkedTrailSegments[0].removeFirst() }
            else { walkedTrailSegments.removeFirst() }
        }
    }

    func refreshLocationIssue() {
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
                guard StopActivationPolicy.isFresh(userLocation.timestamp) else {
                    locationIssue = .waitingForSignal
                    return
                }
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


@MainActor
protocol WalkResumeStore: AnyObject {
    func selectTour(_ identity: TourCatalogIdentity)
    func load() -> WalkResumeRecord?
    func save(_ record: WalkResumeRecord?)
}

@MainActor
final class LocalWalkResumeStore: WalkResumeStore {
    private let defaults: UserDefaults
    private var key = "cranford.walk-resume.v1"
    func selectTour(_ identity: TourCatalogIdentity) { key = identity.storageKey("cranford.walk-resume.v1", perRevision: true) }
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load() -> WalkResumeRecord? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WalkResumeRecord.self, from: data)
    }
    func save(_ record: WalkResumeRecord?) {
        guard let record else { defaults.removeObject(forKey: key); return }
        guard let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: key)
    }
}

@MainActor
final class InMemoryWalkResumeStore: WalkResumeStore {
    private var selectedKey = ""
    private var saved: [String: WalkResumeRecord] = [:]
    func selectTour(_ identity: TourCatalogIdentity) {
        saved[selectedKey] = record
        selectedKey = identity.storageKey("", perRevision: true)
        record = saved[selectedKey]
    }
    private var record: WalkResumeRecord?
    func load() -> WalkResumeRecord? { record }
    func save(_ record: WalkResumeRecord?) { self.record = record }
}
