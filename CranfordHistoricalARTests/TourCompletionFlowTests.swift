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
        preparePlaqueDiscovery()
        XCTAssertEqual(activateCurrent(plaqueIsTracked: true), .allow(.simulation))
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
        XCTAssertTrue(stops[1].hasPlaqueReference)
        XCTAssertFalse(tour.isCurrentStopVisited)
        XCTAssertEqual(activateCurrent(), .deny(.markerNotReady), "GPS alone cannot unlock the Greystone extra")
        preparePlaqueDiscovery()
        XCTAssertEqual(activateCurrent(plaqueIsTracked: true), .allow(.simulation))
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
            if stops[index].hasPlaqueReference { preparePlaqueDiscovery() }
            XCTAssertEqual(activateCurrent(plaqueIsTracked: stops[index].hasPlaqueReference), .allow(.simulation))
            if index == 0 {
                tour.completeCurrentStopAndAdvance()
                try await waitUntil("walking route targets the supplied Greystone coordinate") {
                    self.tour.currentRoute?.destination == fieldPositions[1]
                }
            }
        }
    }

    func testPlaqueVerificationAfterStoryRequiresACurrentlyTrackedMatch() {
        let mill = stops[0]
        preparePlaqueDiscovery()
        XCTAssertTrue(tour.hasPlaqueConfirmedArrival)
        XCTAssertFalse(tour.isCurrentStopVisited)
        XCTAssertEqual(activateCurrent(), .deny(.markerNotReady), "A latched recognition is not a currently tracked plaque")
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
        XCTAssertEqual(activateCurrent(), .deny(.markerNotReady))
        tour.completeCurrentStopAndAdvance()
        XCTAssertFalse(tour.isCurrentStopVisited)
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
    }

    func testTrackingMustBeReadyBeforeActivation() async throws {
        try await arrive(at: 0)
        preparePlaqueDiscovery()
        XCTAssertEqual(tour.activateCurrentStop(stopID: stops[0].id, trackingReady: false, plaqueIsTracked: true), .deny(.trackingNotReady))
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

    func testFullWalkWithOptionalMillDiscoveryAndOtherMarkerActivations() async throws {
        for index in stops.indices {
            try await arrive(at: index)
            if stops[index].hasPlaqueReference { preparePlaqueDiscovery() }
            XCTAssertEqual(activateCurrent(plaqueIsTracked: stops[index].hasPlaqueReference), .allow(.simulation))
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

    func testGreystoneRequiresItsOwnPlaqueAndIgnoresMillCalibration() async throws {
        try await arrive(at: 0)
        tour.finishStory(for: stops[0].id)
        tour.completeCurrentStopAndAdvance()
        #if DEVELOPER_MENU
        tour.viewingPointOverride = stops[0].coordinate
        #endif
        tour.windowBonusLayout = WindowBonusLayout(right: 8, up: 5, width: 9, height: 7)
        try await arrive(at: 1)
        XCTAssertTrue(tour.discovery.hasArrived, "Mill viewing-point override must not affect Greystone arrival")
        XCTAssertEqual(tour.arrivalStoryStopID, stops[1].id)
        XCTAssertEqual(tour.currentBonusLayout, .abovePlaque)
        XCTAssertFalse(tour.isMillDiscoveryStop)
        XCTAssertEqual(stops[1].plaque?.referenceImageName, SignPlacementPolicy.parkReferenceImageName)
        XCTAssertEqual(activateCurrent(), .deny(.markerNotReady))
        tour.finishStory(for: stops[1].id)
        XCTAssertTrue(tour.beginPlaqueDiscovery())
        tour.confirmPlaqueArrival(for: stops[0].id)
        XCTAssertFalse(tour.hasPlaqueConfirmedArrival)
        XCTAssertEqual(activateCurrent(plaqueIsTracked: true), .deny(.markerNotReady))
        tour.confirmPlaqueArrival(for: stops[1].id)
        XCTAssertEqual(activateCurrent(plaqueIsTracked: true), .allow(.simulation))
        XCTAssertTrue(tour.discovery.hasVerifiedPlaque)
        XCTAssertTrue(tour.discovery.isPracticeUnlock)
        XCTAssertEqual(activateCurrent(plaqueIsTracked: true), .alreadyActivated)
        XCTAssertTrue(tour.visitRecords.isEmpty, "Practice discovery must not persist a real visit")
        tour.completeCurrentStopAndAdvance()
        XCTAssertEqual(tour.currentStop?.id, stops[2].id)
        XCTAssertFalse(tour.discovery.hasVerifiedPlaque)
    }

    func testGreystoneCanContinueAfterReadingWithoutPlaqueVerification() async throws {
        try await arrive(at: 0)
        tour.finishStory(for: stops[0].id)
        tour.completeCurrentStopAndAdvance()
        try await arrive(at: 1)
        tour.finishStory(for: stops[1].id)
        XCTAssertTrue(tour.canContinueCurrentStop)
        XCTAssertFalse(tour.discovery.hasVerifiedPlaque)
        tour.completeCurrentStopAndAdvance()
        XCTAssertEqual(tour.currentStop?.id, stops[2].id)
        XCTAssertNil(tour.lastRecordedVisit(for: stops[1]))
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

    private func preparePlaqueDiscovery() {
        let id = tour.currentStop!.id
        tour.finishStory(for: id)
        XCTAssertTrue(tour.beginPlaqueDiscovery())
        tour.confirmPlaqueArrival(for: id)
    }

    func testArrivalOffersStoryOnceAndGPSCannotUnlockBonus() async throws {
        try await arrive(at: 0)
        XCTAssertEqual(tour.arrivalStoryStopID, stops[0].id)
        XCTAssertEqual(tour.discovery.stage, .story)
        tour.openStory(for: stops[0].id)
        XCTAssertNil(tour.arrivalStoryStopID)
        tour.handleLocationForProximity(LocationSample(coordinate: stops[0].coordinate))
        XCTAssertNil(tour.arrivalStoryStopID, "GPS updates cannot repeatedly reopen the story")
        tour.finishStory(for: stops[0].id)
        XCTAssertTrue(tour.beginPlaqueDiscovery())
        XCTAssertEqual(activateCurrent(), .deny(.markerNotReady))
        XCTAssertFalse(tour.discovery.hasVerifiedPlaque)
        XCTAssertTrue(tour.visitRecords.isEmpty)
    }

    func testReadStoryCanContinueWithoutPlaqueAndWithoutSavingAVerifiedVisit() async throws {
        try await arrive(at: 0)
        tour.finishStory(for: stops[0].id)
        XCTAssertTrue(tour.canContinueCurrentStop)
        XCTAssertFalse(tour.isCurrentStopVisited)
        tour.completeCurrentStopAndAdvance()
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
        XCTAssertTrue(tour.visitRecords.isEmpty)
        XCTAssertFalse(tour.discovery.hasVerifiedPlaque)
        try await waitUntil("route advances after optional discovery is declined") {
            self.tour.currentRoute?.destination == self.stops[1].coordinate
        }
    }

    #if canImport(ARKit)
    func testMillActivationActionOpensStoryWithoutPlayingOrRecording() {
        let player = NarrationPlayer()
        let model = ARViewModel(tour: tour, provider: CoreLocationGeoSpatialProvider(hasCompass: false),
                                imageLoader: CompositeImageLoader(), narrationPlayer: player)
        model.activateMarker()
        XCTAssertTrue(model.isShowingSignDetails)
        XCTAssertEqual(player.status, .idle)
        XCTAssertNil(player.stopID)
        XCTAssertTrue(tour.visitRecords.isEmpty)
        XCTAssertFalse(tour.discovery.hasVerifiedPlaque)
    }
    #endif

    func testResetClearsDiscoveryForAnotherTestWalk() async throws {
        try await arrive(at: 0)
        preparePlaqueDiscovery()
        XCTAssertEqual(activateCurrent(plaqueIsTracked: true), .allow(.simulation))
        XCTAssertTrue(tour.discovery.hasVerifiedPlaque)
        tour.resetTour()
        XCTAssertFalse(tour.discovery.hasVerifiedPlaque)
        XCTAssertFalse(tour.discovery.hasFinishedStory)
        XCTAssertFalse(tour.canContinueCurrentStop)
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
        XCTAssertEqual(tour.arrivalStoryStopID, stops[0].id)
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
    func testViewingPointAndWindowCalibrationPersistWithoutChangingSiteCoordinates() async throws {
        let suite = "cranford.discovery.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let mill = HistoricalStop.previewStops[0]
        let point = GeoMath.destination(from: mill.coordinate, bearing: 180, distance: 15)
        let service = DeveloperTestLocationService(sample: LocationSample(coordinate: point, horizontalAccuracy: 4))
        let tour = TourViewModel(stopService: InMemoryHistoricalStopService(stops: HistoricalStop.previewStops),
                                 locationService: service, directionsService: PreviewDirectionsService())
        await tour.loadStopsIfNeeded()
        tour.startTour()
        defer { tour.stopLocation(); tour.cancelRouting() }
        for _ in 0..<100 where tour.userLocation == nil { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertNotNil(tour.userLocation)
        let developer = DeveloperModeController(tour: tour, realLocationService: service, defaults: defaults)
        XCTAssertTrue(developer.saveViewingPoint())
        XCTAssertEqual(developer.savedViewingPoint, point)
        XCTAssertEqual(developer.savedViewingAccuracy, 4)
        XCTAssertEqual(tour.currentStop?.coordinate, mill.coordinate, "Capture must not silently replace map/routing coordinates")
        developer.bonusRight = 4.2
        developer.bonusWidth = 5.3
        let reloaded = DeveloperModeController(tour: tour, realLocationService: service, defaults: defaults)
        XCTAssertEqual(reloaded.savedViewingPoint, point)
        XCTAssertEqual(reloaded.bonusRight, 4.2)
        XCTAssertEqual(reloaded.bonusWidth, 5.3)
        reloaded.clearVisitsAndResetTour()
        XCTAssertEqual(reloaded.savedViewingPoint, point, "Resetting visits must preserve calibration")
        reloaded.resetWindowLayout()
        XCTAssertEqual(tour.windowBonusLayout, WindowBonusLayout())
        reloaded.clearViewingPoint()
        XCTAssertNil(tour.viewingPointOverride)
    }

    func testGreystoneCalibrationPersistsAndResetsIndependentlyOfMill() async throws {
        let suite = "cranford.park-layout.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let service = DeveloperTestLocationService(sample: nil)
        let tour = TourViewModel(stopService: InMemoryHistoricalStopService(stops: HistoricalStop.previewStops),
                                 locationService: service, directionsService: PreviewDirectionsService())
        await tour.loadStopsIfNeeded()
        let developer = DeveloperModeController(tour: tour, realLocationService: service, defaults: defaults)
        developer.bonusRight = 4.2
        developer.parkRight = 0.05
        developer.parkUp = 0.65
        developer.parkWidth = 0.8
        developer.parkHeight = 0.5
        tour.parkBonusLayout = .abovePlaque // Verify the next controller actually reloads storage.
        let reloaded = DeveloperModeController(tour: tour, realLocationService: service, defaults: defaults)
        XCTAssertEqual(reloaded.parkRight, 0.05)
        XCTAssertEqual(reloaded.parkUp, 0.65)
        XCTAssertEqual(reloaded.parkWidth, 0.8)
        XCTAssertEqual(reloaded.parkHeight, 0.5)
        XCTAssertEqual(reloaded.bonusRight, 4.2)
        reloaded.clearVisitsAndResetTour()
        XCTAssertEqual(reloaded.parkWidth, 0.8, "Resetting visits preserves Greystone calibration")
        reloaded.resetWindowLayout()
        XCTAssertEqual(reloaded.parkWidth, 0.8, "Mill reset must not alter Greystone")
        reloaded.bonusRight = 4.8
        reloaded.resetParkLayout()
        XCTAssertEqual(tour.parkBonusLayout, .abovePlaque)
        XCTAssertEqual(reloaded.bonusRight, 4.8, "Greystone reset must not alter mill calibration")
        let afterReset = DeveloperModeController(tour: tour, realLocationService: service, defaults: defaults)
        XCTAssertEqual(afterReset.parkWidth, WindowBonusLayout.abovePlaque.width)
        XCTAssertEqual(afterReset.bonusRight, 4.8)
    }

    func testSimulatedGPSCannotBeSavedAsTheRealViewingPoint() async throws {
        let suite = "cranford.discovery.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let service = DeveloperTestLocationService(sample: LocationSample(coordinate: HistoricalStop.previewStops[0].coordinate, isSimulated: true))
        let tour = TourViewModel(stopService: InMemoryHistoricalStopService(stops: HistoricalStop.previewStops),
                                 locationService: service, directionsService: PreviewDirectionsService())
        await tour.loadStopsIfNeeded()
        tour.startTour()
        defer { tour.stopLocation(); tour.cancelRouting() }
        for _ in 0..<100 where tour.userLocation == nil { try await Task.sleep(for: .milliseconds(5)) }
        let developer = DeveloperModeController(tour: tour, realLocationService: service, defaults: defaults)
        XCTAssertFalse(developer.saveViewingPoint())
        XCTAssertNil(developer.savedViewingPoint)
    }

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
        tour.finishStory(for: firstID)
        XCTAssertTrue(tour.beginPlaqueDiscovery())
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
        tour.finishStory(for: firstID)
        XCTAssertTrue(tour.beginPlaqueDiscovery())
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
        tour.finishStory(for: "hpab-001")
        XCTAssertTrue(tour.beginPlaqueDiscovery())
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
    private let sample: LocationSample?
    init(sample: LocationSample? = nil) { self.sample = sample }
    var authorization: LocationAuthorization { .authorized }
    var isPreciseLocationAuthorized: Bool { true }
    var isHeadingAvailable: Bool { false }
    func events() -> AsyncStream<LocationEvent> {
        AsyncStream { continuation in
            if let sample { continuation.yield(.location(sample)) }
            continuation.finish()
        }
    }
    func requestWhenInUseAuthorization() {}
    func requestTemporaryPreciseLocationIfNeeded() {}
    func start() {}
    func stop() {}
}
#endif
