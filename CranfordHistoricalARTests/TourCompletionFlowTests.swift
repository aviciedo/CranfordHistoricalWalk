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

    func testBrowsingAndSwitchingTabsDoNotRetargetTheGuidedWalk() {
        let originalStop = tour.currentStop?.id
        let originalPhase = tour.phase
        let navigation = AppNavigation()
        let map = MapViewModel()

        navigation.showOnMap(stopID: stops[2].id)
        map.show(stop: stops[2])
        XCTAssertEqual(navigation.selectedTab, .map)
        XCTAssertEqual(navigation.focusedStopID, stops[2].id)
        XCTAssertEqual(map.cameraMode, .free)
        XCTAssertEqual(tour.currentStop?.id, originalStop)

        navigation.selectedTab = .stops
        navigation.selectedTab = .home
        navigation.selectedTab = .map
        XCTAssertEqual(tour.phase, originalPhase)
        XCTAssertEqual(tour.currentStop?.id, originalStop)
        XCTAssertEqual(tour.progress.completedCount, 0)
    }

    override func tearDown() async throws {
        simulator.stop()
        tour.stopLocation()
        tour.cancelRouting()
    }

    func testArrivalRevealsMarkerWithoutRecordingOrAdvancing() async throws {
        try await arrive(at: 0)
        XCTAssertFalse(tour.isCurrentStopVisited)
        XCTAssertEqual(tour.proximityState, .signPresented)
        XCTAssertTrue(tour.hasArrivedAtCurrentStop)
        XCTAssertNil(tour.lastCompletedStop)
        XCTAssertTrue(tour.visitRecords.isEmpty)

        tour.completeCurrentStopAndAdvance()
        XCTAssertEqual(tour.currentStop?.id, stops[0].id, "Continue cannot bypass activation")
        tour.closeSign()
        XCTAssertNil(tour.presentedSignStop)
        XCTAssertEqual(tour.currentStop?.id, stops[0].id, "Closing a marker cannot skip this stop")
    }

    func testFirstActivationThenExplicitContinueRoutesToSecondStop() async throws {
        try await arrive(at: 0)
        XCTAssertEqual(activateCurrent(), .allow(.simulation))
        XCTAssertTrue(tour.isCurrentStopVisited)
        XCTAssertEqual(activateCurrent(), .alreadyActivated)
        XCTAssertEqual(tour.progress.completedCount, 1)
        XCTAssertTrue(tour.visitRecords.isEmpty, "Practice must not persist as a real visit")

        tour.closeSign()
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
        tour.completeCurrentStopAndAdvance()
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
        XCTAssertEqual(tour.lastCompletedStop?.id, stops[0].id)
        XCTAssertFalse(tour.isCurrentStopVisited)
        XCTAssertNil(tour.activeVisitEvidence)
        try await waitUntil("walking route to second stop") { self.tour.currentRoute?.destination == self.stops[1].coordinate }

        try await arrive(at: 1)
        XCTAssertFalse(stops[1].hasPlaqueReference)
        XCTAssertFalse(tour.isCurrentStopVisited)
        XCTAssertEqual(activateCurrent(), .allow(.simulation), "Second stop uses on-site marker without a plaque")
        tour.completeCurrentStopAndAdvance()
        XCTAssertEqual(tour.currentStop?.id, stops[2].id)
    }

    func testSuppliedFieldPositionsAgreeWithMapMarkersAndFirstToSecondStopRouting() async throws {
        let fieldPositions = [
            GeoCoordinate(latitude: 40.6503, longitude: -74.3012),
            GeoCoordinate(latitude: 40.6524, longitude: -74.2990)
        ]
        let map = MapViewModel()
        for (index, fieldPosition) in fieldPositions.enumerated() {
            XCTAssertEqual(tour.currentStop?.id, stops[index].id)
            simulator.teleport(to: fieldPosition)
            try await waitUntil("field location reveals stop \(index + 1)") {
                self.tour.userLocation?.coordinate == fieldPosition
                    && self.tour.presentedSignStopID == self.stops[index].id
            }
            let marker = try XCTUnwrap(map.markers(for: tour).first { $0.id == stops[index].id })
            let puck = try XCTUnwrap(map.userPuck(for: tour))
            XCTAssertEqual(puck.coordinate.latitude, fieldPosition.latitude)
            XCTAssertEqual(puck.coordinate.longitude, fieldPosition.longitude)
            XCTAssertEqual(marker.coordinate.latitude, puck.coordinate.latitude)
            XCTAssertEqual(marker.coordinate.longitude, puck.coordinate.longitude)
            XCTAssertEqual(try XCTUnwrap(tour.straightLineDistanceToCurrentStop), 0, accuracy: 0.1)
            XCTAssertFalse(tour.isCurrentStopVisited, "A GPS arrival alone cannot record a visit")
            XCTAssertEqual(activateCurrent(), .allow(.simulation))
            if index == 0 {
                tour.completeCurrentStopAndAdvance()
                try await waitUntil("walking route targets the supplied Greystone coordinate") {
                    self.tour.currentRoute?.destination == fieldPositions[1]
                }
            }
        }
    }

    func testRecognizedPlaqueRevealsMarkerButRequiresATap() {
        let mill = stops[0]
        tour.confirmPlaqueArrival(for: mill.id)
        XCTAssertTrue(tour.hasPlaqueConfirmedArrival)
        XCTAssertFalse(tour.isCurrentStopVisited)
        XCTAssertEqual(activateCurrent(), .deny(.outsideStop), "A latched recognition is not a currently tracked plaque")
        XCTAssertEqual(activateCurrent(plaqueIsTracked: true), .allow(.simulation))

        let wrongGPS = GeoMath.destination(from: mill.coordinate, bearing: 90, distance: 320)
        tour.handleLocationForProximity(LocationSample(coordinate: wrongGPS, horizontalAccuracy: 5))
        XCTAssertTrue(tour.isSignPresented)
        tour.closeSign()
        XCTAssertEqual(tour.currentStop?.id, mill.id)
        tour.completeCurrentStopAndAdvance()
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
        XCTAssertFalse(tour.hasPlaqueConfirmedArrival)
    }

    func testWrongStopCannotRecognizeOrActivate() {
        tour.confirmPlaqueArrival(for: stops[1].id)
        XCTAssertFalse(tour.hasPlaqueConfirmedArrival)
        XCTAssertFalse(tour.isSignPresented)
        XCTAssertEqual(tour.activateCurrentStop(stopID: stops[1].id, trackingReady: true, plaqueIsTracked: true), .deny(.wrongStop))
    }

    func testManualSignFarAwayCannotActivateOrAdvance() {
        tour.openSignManually()
        XCTAssertTrue(tour.isSignPresented)
        XCTAssertEqual(activateCurrent(), .deny(.outsideStop))
        tour.completeCurrentStopAndAdvance()
        XCTAssertFalse(tour.isCurrentStopVisited)
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
    }

    func testTrackingMustBeReadyBeforeActivation() async throws {
        try await arrive(at: 0)
        XCTAssertEqual(tour.activateCurrentStop(stopID: stops[0].id, trackingReady: false, plaqueIsTracked: false), .deny(.trackingNotReady))
        XCTAssertFalse(tour.isCurrentStopVisited)
    }

    func testWalkingAwayFromUnactivatedMarkerDoesNotVisitOrAdvance() async throws {
        try await arrive(at: 0)
        simulator.teleport(to: GeoMath.destination(from: stops[0].coordinate, bearing: 90, distance: 42))
        try await waitUntil("GPS reaches hysteresis band") { (self.tour.straightLineDistanceToCurrentStop ?? 0) > 40 }
        XCTAssertTrue(tour.isSignPresented)
        simulator.teleport(to: GeoMath.destination(from: stops[0].coordinate, bearing: 90, distance: 60))
        try await waitUntil("marker dismissed outside departure radius") { !self.tour.isSignPresented }
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
        XCTAssertFalse(tour.isCurrentStopVisited)
    }

    func testEveryStopNeedsActivationBeforeTourCompletes() async throws {
        for index in stops.indices {
            try await arrive(at: index)
            XCTAssertEqual(activateCurrent(), .allow(.simulation))
            tour.completeCurrentStopAndAdvance()
        }
        XCTAssertEqual(tour.phase, .complete)
        XCTAssertNil(tour.currentStop)
        XCTAssertNil(tour.proximityMachine)
        XCTAssertNil(tour.currentRoute)
        XCTAssertEqual(tour.completionFigures.visitedCount, stops.count)
        XCTAssertTrue(tour.visitRecords.isEmpty)
        tour.resetTour()
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
        XCTAssertEqual(tour.progress.completedCount, 0)
    }

    private func arrive(at index: Int) async throws {
        XCTAssertEqual(tour.currentStop?.id, stops[index].id)
        simulator.teleport(to: stops[index].coordinate)
        try await waitUntil("current location and marker at stop \(index + 1)") {
            self.tour.presentedSignStopID == self.stops[index].id
                && self.tour.userLocation?.coordinate == self.stops[index].coordinate
        }
    }

    private func activateCurrent(plaqueIsTracked: Bool = false) -> StopActivationDecision {
        tour.activateCurrentStop(stopID: tour.currentStop!.id, trackingReady: true, plaqueIsTracked: plaqueIsTracked)
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
        XCTAssertFalse(tour.isCurrentStopVisited, "Walking alone does not activate the stop")
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

@MainActor
final class StopVisitStoreTests: XCTestCase {
    #if DEVELOPER_MENU
    func testClearingVisitsSurvivesReloadAndPreservesOtherSettings() throws {
        let suite = "cranford.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "unrelated-test-setting")
        let store = LocalStopVisitStore(defaults: defaults)
        store.record(StopVisitRecord(stopID: "hpab-001", activatedAt: Date(), evidence: .recognizedPlaque))
        store.record(StopVisitRecord(stopID: "hpab-002", activatedAt: Date(), evidence: .onSiteARMarker))
        XCTAssertEqual(store.records().count, 2)

        store.removeAll()
        XCTAssertTrue(store.records().isEmpty)
        XCTAssertTrue(LocalStopVisitStore(defaults: defaults).records().isEmpty)
        XCTAssertTrue(defaults.bool(forKey: "unrelated-test-setting"))

        let memory = InMemoryStopVisitStore()
        memory.record(StopVisitRecord(stopID: "hpab-001", activatedAt: Date(), evidence: .recognizedPlaque))
        XCTAssertEqual(memory.records().count, 1)
        memory.removeAll()
        XCTAssertTrue(memory.records().isEmpty)
    }

    func testSavingOffPreservesHistoryAndAllowsActivationAndContinueThenSavingCanResume() async throws {
        let store = InMemoryStopVisitStore()
        let oldVisit = StopVisitRecord(stopID: "hpab-002", activatedAt: Date(), evidence: .onSiteARMarker)
        store.record(oldVisit)
        let service = DeveloperTestLocationService()
        let tour = TourViewModel(stopService: InMemoryHistoricalStopService(stops: HistoricalStop.previewStops),
                                 locationService: service, directionsService: PreviewDirectionsService(), visitStore: store)
        await tour.loadStopsIfNeeded()
        tour.startTour()
        defer { tour.stopLocation(); tour.cancelRouting() }
        let developer = DeveloperModeController(tour: tour, realLocationService: service)
        XCTAssertTrue(developer.isVisitRecordingEnabled)
        developer.isVisitRecordingEnabled = false

        let firstID = try XCTUnwrap(tour.currentStop?.id)
        tour.confirmPlaqueArrival(for: firstID)
        XCTAssertEqual(tour.activateCurrentStop(stopID: firstID, trackingReady: true, plaqueIsTracked: true), .allow(.recognizedPlaque))
        XCTAssertTrue(tour.isCurrentStopVisited)
        XCTAssertEqual(tour.progress.completedCount, 1)
        XCTAssertEqual(store.records(), [oldVisit])
        XCTAssertEqual(tour.visitRecords, [oldVisit])
        tour.completeCurrentStopAndAdvance()
        XCTAssertEqual(tour.currentStop?.id, "hpab-002")

        developer.isVisitRecordingEnabled = true
        developer.resetTour()
        tour.confirmPlaqueArrival(for: firstID)
        XCTAssertEqual(tour.activateCurrentStop(stopID: firstID, trackingReady: true, plaqueIsTracked: true), .allow(.recognizedPlaque))
        XCTAssertEqual(Set(store.records().map(\.stopID)), [firstID, oldVisit.stopID])
        XCTAssertEqual(tour.visitRecords.count, 2)
    }

    func testDeveloperClearResetsSavedVisitsAndProgressAndPausesSimulator() async throws {
        let store = InMemoryStopVisitStore()
        store.record(StopVisitRecord(stopID: "hpab-001", activatedAt: Date(), evidence: .recognizedPlaque))
        let service = DeveloperTestLocationService()
        let tour = TourViewModel(stopService: InMemoryHistoricalStopService(stops: HistoricalStop.previewStops),
                                 locationService: service, directionsService: PreviewDirectionsService(), visitStore: store)
        await tour.loadStopsIfNeeded()
        tour.startTour()
        defer { tour.stopLocation(); tour.cancelRouting() }
        let developer = DeveloperModeController(tour: tour, realLocationService: service)
        tour.confirmPlaqueArrival(for: "hpab-001")
        XCTAssertEqual(tour.activateCurrentStop(stopID: "hpab-001", trackingReady: true, plaqueIsTracked: true), .allow(.recognizedPlaque))
        tour.completeCurrentStopAndAdvance()
        tour.progress.recordWalked(meters: 100)
        developer.isVisitRecordingEnabled = false
        developer.walkTowardNextStop()
        XCTAssertTrue(developer.isWalking)
        XCTAssertEqual(tour.currentStop?.id, "hpab-002")

        developer.clearVisitsAndResetTour()
        XCTAssertTrue(store.records().isEmpty)
        XCTAssertTrue(tour.visitRecords.isEmpty)
        XCTAssertEqual(tour.currentStop?.id, "hpab-001")
        XCTAssertEqual(tour.progress.completedCount, 0)
        XCTAssertEqual(tour.progress.walkedMeters, 0)
        XCTAssertFalse(tour.isCurrentStopVisited)
        XCTAssertNil(tour.lastCompletedStop)
        XCTAssertNil(tour.activeVisitEvidence)
        XCTAssertFalse(developer.isWalking)
        XCTAssertTrue(developer.isSimulating, "Clearing visits must not change the chosen location source")
        XCTAssertFalse(developer.isVisitRecordingEnabled, "Repeat test walks must keep the selected saving setting")
    }
    #endif

    func testRealVisitSurvivesAStoreReloadAndPracticeCannotReplaceIt() throws {
        let suite = "cranford.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let first = StopVisitRecord(stopID: "hpab-001", activatedAt: date, evidence: .recognizedPlaque)
        LocalStopVisitStore(defaults: defaults).record(first)
        LocalStopVisitStore(defaults: defaults).record(StopVisitRecord(stopID: "hpab-001", activatedAt: date.addingTimeInterval(10), evidence: .simulation))
        XCTAssertEqual(LocalStopVisitStore(defaults: defaults).records(), [first])
        let second = StopVisitRecord(stopID: "hpab-002", activatedAt: date.addingTimeInterval(60), evidence: .onSiteARMarker)
        LocalStopVisitStore(defaults: defaults).record(second)
        XCTAssertEqual(Set(LocalStopVisitStore(defaults: defaults).records().map(\.stopID)), ["hpab-001", "hpab-002"])
    }

    func testLatestRealActivationReplacesEarlierVisitForSameStop() throws {
        let suite = "cranford.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LocalStopVisitStore(defaults: defaults)
        store.record(StopVisitRecord(stopID: "hpab-001", activatedAt: Date(timeIntervalSince1970: 100), evidence: .onSiteARMarker))
        let latest = StopVisitRecord(stopID: "hpab-001", activatedAt: Date(timeIntervalSince1970: 200), evidence: .recognizedPlaque)
        store.record(latest)
        XCTAssertEqual(store.records(), [latest])
    }

    func testCorruptSavedDataAndPracticeAreIgnored() throws {
        let suite = "cranford.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("invalid json".utf8), forKey: "cranford.stop-visits.v1")
        let store = LocalStopVisitStore(defaults: defaults)
        XCTAssertTrue(store.records().isEmpty)
        store.record(StopVisitRecord(stopID: "hpab-001", activatedAt: Date(), evidence: .simulation))
        XCTAssertTrue(store.records().isEmpty)
    }
}

#if DEVELOPER_MENU
/// An authorized device source with no GPS fix, so these tests exercise real plaque evidence
/// rather than the simulator's intentionally non-persistent practice evidence.
@MainActor
private final class DeveloperTestLocationService: LocationService {
    var authorization: LocationAuthorization { .authorized }
    var isPreciseLocationAuthorized: Bool { true }
    var isHeadingAvailable: Bool { false }
    func events() -> AsyncStream<LocationEvent> { AsyncStream { $0.finish() } }
    func requestWhenInUseAuthorization() {}
    func requestTemporaryPreciseLocationIfNeeded() {}
    func start() {}
    func stop() {}
}
#endif
