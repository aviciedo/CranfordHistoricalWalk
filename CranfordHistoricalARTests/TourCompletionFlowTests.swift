import Foundation
import TourCore
import XCTest
#if canImport(CranfordHistoricalAR)
import CoreLocation
@testable import CranfordHistoricalAR
#else
@testable import ActivityModelHarness
#endif

/// The same state-flow tests run against the native model and its Linux Foundation harness.
@MainActor
final class TourCompletionFlowTests: XCTestCase {
    func testHomeZoomUsesCurrentZoomWithoutChangingWalkingOrViewedStop() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        tour.completeCurrentStopAndAdvance()
        let progress = tour.progress
        let activities = tour.activities
        let map = MapViewModel()
        map.show(stop: stops[0])
        map.select(stopID: stops[0].id)
        map.cameraDidSettle(zoom: 15.5)
        map.requestZoom(by: 1)
        XCTAssertEqual(map.cameraRequest?.kind, .zoomTo(16.5))
        XCTAssertEqual(map.cameraMode, .free)
        XCTAssertEqual(map.viewedStopID, stops[0].id)
        XCTAssertEqual(map.selectedStopID, stops[0].id)
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
        XCTAssertEqual(tour.progress, progress)
        XCTAssertEqual(tour.activities, activities)
        map.requestZoom(by: -1)
        XCTAssertEqual(map.cameraRequest?.kind, .zoomTo(15.5))
    }

    func testRapidZoomTapsAccumulateAndRespectLimitsAndPinchChanges() async {
        let map = MapViewModel()
        map.cameraDidSettle(zoom: 15)
        for _ in 0..<3 { map.requestZoom(by: 1) }
        XCTAssertEqual(map.cameraRequest?.kind, .zoomTo(18))
        map.requestZoom(by: 100)
        XCTAssertEqual(map.cameraRequest?.kind, .zoomTo(MapZoomPolicy.maximum))
        XCTAssertFalse(map.canZoomIn)
        let atMaximum = map.cameraRequest
        map.requestZoom(by: 1)
        XCTAssertEqual(map.cameraRequest, atMaximum)
        map.requestZoom(by: -100)
        XCTAssertEqual(map.cameraRequest?.kind, .zoomTo(MapZoomPolicy.minimum))
        XCTAssertFalse(map.canZoomOut)
        let atMinimum = map.cameraRequest
        map.requestZoom(by: -1)
        XCTAssertEqual(map.cameraRequest, atMinimum)
        map.cameraDidSettle(zoom: 13.25) // A pinch updates the next button's starting point.
        map.requestZoom(by: -1)
        XCTAssertEqual(map.cameraRequest?.kind, .zoomTo(12.25))
        let valid = map.cameraRequest
        map.requestZoom(by: .nan)
        map.cameraDidSettle(zoom: .nan)
        XCTAssertEqual(map.cameraRequest, valid)
        XCTAssertEqual(map.zoom, 12.25)
    }

    func testAppleZoomConversionMatchesGoogleScaleAtDifferentLatitudes() async {
        for latitude in [-45.0, 0.0, 40.65, 65.0] {
            for level in [5.0, 15.2, 19.0] {
                let metersPerPoint = 156543.03392 * cos(latitude * Double.pi / 180) / pow(2, level)
                XCTAssertEqual(MapZoomPolicy.level(metersPerPoint: metersPerPoint, latitude: latitude),
                               Float(level), accuracy: 0.0001)
            }
        }
        XCTAssertEqual(MapZoomPolicy.level(metersPerPoint: 0, latitude: 40.65), MapZoomPolicy.initial)
        XCTAssertEqual(MapZoomPolicy.level(metersPerPoint: 1, latitude: .nan), MapZoomPolicy.initial)
    }

    func testManualTabVisitDoesNotReuseAnOlderShowOnMapOrigin() async {
        let navigation = AppNavigation()
        navigation.selectedTab = .stops
        navigation.showOnMap(stopID: "hpab-002")
        navigation.selectedTab = .home
        navigation.selectedTab = .map
        navigation.goBack()
        XCTAssertEqual(navigation.selectedTab, .home)
        XCTAssertNil(navigation.pendingStopReturn)
    }

    func testBackFromShowOnMapRestoresStopInItsOriginatingTab() async {
        let navigation = AppNavigation()
        navigation.selectedTab = .stops
        navigation.showOnMap(stopID: "hpab-002")
        navigation.goBack()
        XCTAssertEqual(navigation.selectedTab, .stops)
        XCTAssertNil(navigation.takeStopReturn(for: .home))
        XCTAssertEqual(navigation.takeStopReturn(for: .stops), "hpab-002")
        XCTAssertNil(navigation.takeStopReturn(for: .stops), "Consume only once")
        navigation.goBack()
        XCTAssertEqual(navigation.selectedTab, .home)
    }

    func testBackFromMapOpenedByItsOwnStopRestoresDetailWithoutChangingTabs() async {
        let navigation = AppNavigation()
        navigation.selectedTab = .map
        navigation.showOnMap(stopID: "hpab-001")
        navigation.goBack()
        XCTAssertEqual(navigation.selectedTab, .map)
        XCTAssertEqual(navigation.takeStopReturn(for: .map), "hpab-001")
        navigation.goBack()
        XCTAssertEqual(navigation.selectedTab, .home)
    }

    func testHomeCancelsPendingStopReopening() async {
        let navigation = AppNavigation()
        navigation.showOnMap(stopID: "hpab-001")
        navigation.goBack()
        navigation.goHome()
        XCTAssertNil(navigation.pendingStopReturn)
        XCTAssertNil(navigation.takeStopReturn(for: .home))
    }

    func testBackUnwindsPreviouslyOpenedTabsWithoutLooping() async {
        let navigation = AppNavigation()
        navigation.selectedTab = .map
        navigation.selectedTab = .map // Reselecting a tab is not another screen.
        navigation.selectedTab = .stops
        navigation.goBack()
        XCTAssertEqual(navigation.selectedTab, .map)
        navigation.goBack()
        XCTAssertEqual(navigation.selectedTab, .home)
        navigation.goBack()
        XCTAssertEqual(navigation.selectedTab, .home)
    }

    func testHomeClearsBackHistoryAndPendingMapFocus() async {
        let navigation = AppNavigation()
        navigation.selectedTab = .stops
        navigation.showOnMap(stopID: "hpab-002")
        navigation.goHome()
        XCTAssertEqual(navigation.selectedTab, .home)
        XCTAssertNil(navigation.focusedStopID)
        navigation.goBack()
        XCTAssertEqual(navigation.selectedTab, .home)
    }

    func testNestedHomeCloseEmitsNewSignalEvenWhenHomeIsAlreadySelected() async {
        let navigation = AppNavigation()
        let initial = navigation.homeReturnID
        navigation.goHome()
        XCTAssertEqual(navigation.homeReturnID, initial + 1)
        navigation.goHome()
        XCTAssertEqual(navigation.homeReturnID, initial + 2)
    }

    func testReturningHomePreservesIndependentWalkingAndPhotoProgress() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        tour.completeCurrentStopAndAdvance()
        let destination = tour.currentStop?.id
        let navigation = AppNavigation()
        navigation.photoSelections[stops[0].id] = 3
        navigation.selectedTab = .stops
        tour.openStory(for: stops[0].id)
        navigation.goHome()
        XCTAssertEqual(tour.currentStop?.id, destination)
        XCTAssertEqual(tour.phase, .inProgress)
        XCTAssertEqual(navigation.photoSelections[stops[0].id], 3)
    }

    func testClosingViewedMapPopupPreservesWalkAndCamera() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        tour.completeCurrentStopAndAdvance()
        let destination = tour.currentStop?.id
        let map = MapViewModel()
        map.show(stop: stops[0])
        let camera = map.cameraRequest
        map.clearViewedStop()
        XCTAssertNil(map.viewedStopID)
        XCTAssertEqual(map.cameraRequest, camera)
        XCTAssertEqual(tour.currentStop?.id, destination)
        XCTAssertEqual(tour.phase, .inProgress)
    }

    func testFirstLegStartWordingIgnoresIndependentStoriesAndBonuses() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        let title = "Start walk: \(stops[0].name)"
        XCTAssertEqual(tour.walkActionTitle, title)
        tour.finishListening(for: stops[1].id)
        tour.activities.foundBonus(at: stops[1].id)
        tour.activities.visited(stops[0].id) // A prior walk must not suppress this walk's start.
        tour.startTour()
        XCTAssertTrue(tour.isHeadingToFirstStop)
        XCTAssertEqual(tour.walkActionTitle, title)
        tour.openStory(for: stops[1].id)
        XCTAssertEqual(tour.walkActionTitle, title)
        confirmArrival(tour)
        XCTAssertFalse(tour.isHeadingToFirstStop)
        XCTAssertEqual(tour.walkActionTitle, "Continue your walk")
        tour.completeCurrentStopAndAdvance()
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
        XCTAssertEqual(tour.walkActionTitle, "Continue your walk")
        while tour.phase == .inProgress { tour.completeCurrentStopAndAdvance() }
        XCTAssertEqual(tour.walkActionTitle, "Walk it again")
    }

    #if DEVELOPER_MENU
    func testVisitOnlyResetKeepsStoriesAndBonusesSeparate() async {
        let visits = InMemoryStopVisitStore()
        let activities = InMemoryStopActivityStore()
        visits.record(StopVisitRecord(stopID: stops[1].id, activatedAt: Date(), evidence: .recognizedPlaque))
        let tour = await makeTour(visitStore: visits, activityStore: activities); defer { cleanUp(tour) }
        tour.finishListening(for: stops[1].id)
        tour.finishStory(for: stops[1].id)
        tour.startTour()
        tour.completeCurrentStopAndAdvance()
        tour.clearRecordedActivitiesAndRestart(includingStoriesAndBonuses: false)
        XCTAssertTrue(visits.records().isEmpty)
        XCTAssertNil(tour.activities[stops[1].id].visitedAt)
        XCTAssertNotNil(tour.activities[stops[1].id].listenedAt)
        XCTAssertNotNil(tour.activities[stops[1].id].readAt)
        XCTAssertNotNil(tour.activities[stops[1].id].bonusFoundAt)
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
        XCTAssertEqual(tour.progress.completedCount, 0)
        XCTAssertEqual(activities.load(), tour.activities)
    }

    func testFullActivityResetClearsGreystoneStatusAndPersistsAcrossRelaunch() async {
        let visits = InMemoryStopVisitStore()
        let activities = InMemoryStopActivityStore()
        visits.record(StopVisitRecord(stopID: stops[1].id, activatedAt: Date(), evidence: .recognizedPlaque))
        let tour = await makeTour(visitStore: visits, activityStore: activities); defer { cleanUp(tour) }
        tour.finishListening(for: stops[1].id)
        tour.finishStory(for: stops[1].id)
        tour.startTour()
        tour.completeCurrentStopAndAdvance()
        tour.openStory(for: stops[1].id)
        XCTAssertNotNil(tour.activities[stops[1].id].bonusFoundAt)
        tour.clearRecordedActivitiesAndRestart(includingStoriesAndBonuses: true)
        XCTAssertTrue(visits.records().isEmpty)
        XCTAssertTrue(tour.visitRecords.isEmpty)
        for stop in stops { XCTAssertEqual(tour.activities[stop.id], StopActivities()) }
        XCTAssertEqual(tour.progress.completedCount, 0)
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
        XCTAssertTrue(tour.discoveriesByStopID[stops[1].id] == nil)
        let reloaded = await makeTour(visitStore: visits, activityStore: activities); defer { cleanUp(reloaded) }
        for stop in stops { XCTAssertEqual(reloaded.activities[stop.id], StopActivities()) }
        XCTAssertEqual(reloaded.walkActionTitle, reloaded.startWalkTitle)
    }
    #endif

    func testAutomaticDepartureAdvancesOnceAndUndoPreservesIndependentActivity() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        tour.isAutomaticNavigationVisible = true
        tour.finishListening(for: stops[0].id)
        tour.activities.foundBonus(at: stops[0].id)
        confirmArrival(tour)
        XCTAssertEqual(tour.currentStop?.id, stops[0].id, "Arrival holds the current place")
        let now = Date()
        let away = GeoCoordinate(latitude: stops[0].latitude + 0.002, longitude: stops[0].longitude)
        for age in [0.0, 5] {
            let fix = LocationSample(coordinate: away, horizontalAccuracy: 3, timestamp: now.addingTimeInterval(age))
            tour.evaluateAutomaticProgression(fix, now: fix.timestamp)
        }
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
        XCTAssertEqual(tour.automaticTransitionFromStopID, stops[0].id)
        XCTAssertFalse(tour.activities[stops[1].id].learningCompleted)
        tour.progress.recordWalked(meters: 80)
        tour.progress.markCurrentStopVisited() // New visit after the transition must survive Undo.
        tour.undoAutomaticTransition()
        XCTAssertTrue(tour.progress.isCompleted(stops[1].id))
        XCTAssertEqual(tour.progress.walkedMeters, 80)
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
        XCTAssertTrue(tour.walkingProgression.isHeld)
        XCTAssertNotNil(tour.activities[stops[0].id].visitedAt)
        XCTAssertTrue(tour.activities[stops[0].id].learningCompleted)
        XCTAssertNotNil(tour.activities[stops[0].id].bonusFoundAt)
        for age in [10.0, 15, 20] {
            let fix = LocationSample(coordinate: away, timestamp: now.addingTimeInterval(age))
            tour.evaluateAutomaticProgression(fix, now: fix.timestamp)
        }
        XCTAssertEqual(tour.currentStop?.id, stops[0].id, "Undo latches the hold")
        tour.completeCurrentStopAndAdvance()
        XCTAssertEqual(tour.currentStop?.id, stops[1].id, "Explicit Continue overrides hold")
        XCTAssertNil(tour.automaticTransitionProgress)
    }

    func testNestedExplorationARAndBackgroundHoldDepartureUntilNewMapFixes() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour(); tour.isAutomaticNavigationVisible = true
        confirmArrival(tour)
        let first = UUID(), nested = UUID()
        tour.explorationHolds = [first, nested]
        let now = Date()
        let away = GeoCoordinate(latitude: stops[0].latitude + 0.002, longitude: stops[0].longitude)
        func fix(_ age: Double) {
            let sample = LocationSample(coordinate: away, timestamp: now.addingTimeInterval(age))
            tour.evaluateAutomaticProgression(sample, now: sample.timestamp)
        }
        fix(0); fix(5)
        tour.explorationHolds.remove(nested)
        fix(10)
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
        tour.explorationHolds.remove(first)
        tour.isARSessionActive = true
        fix(15); fix(20)
        tour.isARSessionActive = false
        tour.isAutomaticNavigationVisible = false
        fix(25); fix(30)
        tour.isAutomaticNavigationVisible = true
        fix(35)
        XCTAssertEqual(tour.currentStop?.id, stops[0].id, "Fresh dwell starts on return")
        fix(40)
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
    }

    func testStableFinalArrivalFinishesTruthfullyWithSkippedSitesAndUndo() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        for _ in 0..<(stops.count - 1) { tour.completeCurrentStopAndAdvance() }
        tour.isAutomaticNavigationVisible = true
        confirmArrival(tour)
        XCTAssertEqual(tour.phase, .complete)
        XCTAssertEqual(tour.completionFigures.visitedCount, 1)
        XCTAssertFalse(tour.isCompleted(stops[0]))
        XCTAssertTrue(tour.isCompleted(stops.last!))
        tour.undoAutomaticTransition()
        XCTAssertEqual(tour.phase, .inProgress)
        XCTAssertEqual(tour.currentStop?.id, stops.last?.id)
        XCTAssertTrue(tour.walkingProgression.isHeld)
        tour.completeCurrentStopAndAdvance()
        XCTAssertEqual(tour.phase, .complete)
    }

    func testFinalArrivalWhileReadingRequiresNewFixAfterReturningToMap() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        for _ in 0..<(stops.count - 1) { tour.completeCurrentStopAndAdvance() }
        let token = UUID(); tour.explorationHolds.insert(token)
        tour.isAutomaticNavigationVisible = true
        confirmArrival(tour)
        XCTAssertEqual(tour.phase, .inProgress)
        let usedFix = tour.walkingProgression.lastFix!
        tour.explorationHolds.remove(token)
        let cached = LocationSample(coordinate: stops.last!.coordinate, timestamp: usedFix)
        tour.evaluateAutomaticProgression(cached, now: usedFix)
        XCTAssertEqual(tour.phase, .inProgress, "A repeated fix cannot finish on presentation dismissal")
        let fresh = LocationSample(coordinate: stops.last!.coordinate, timestamp: usedFix.addingTimeInterval(1))
        tour.evaluateAutomaticProgression(fresh, now: fresh.timestamp)
        XCTAssertEqual(tour.phase, .complete)
    }

    func testRestartClearsAutomaticUndoAndArrivalWithoutDeletingStory() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour(); tour.finishListening(for: stops[0].id)
        confirmArrival(tour)
        tour.walkingProgression.isHeld = true
        tour.automaticTransitionFromStopID = stops[0].id
        tour.automaticTransitionProgress = tour.progress
        tour.resetTour()
        XCTAssertFalse(tour.walkingProgression.hasArrived)
        XCTAssertFalse(tour.walkingProgression.isHeld)
        XCTAssertNil(tour.automaticTransitionFromStopID)
        XCTAssertNil(tour.automaticTransitionProgress)
        XCTAssertTrue(tour.activities[stops[0].id].learningCompleted)
    }

    func testSingleGPSFixDoesNotRecordCurrentArrival() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour(); tour.isAutomaticNavigationVisible = true
        let sample = LocationSample(coordinate: stops[0].coordinate)
        tour.handleLocationForProximity(sample)
        tour.evaluateAutomaticProgression(sample)
        tour.evaluateAutomaticProgression(sample)
        XCTAssertFalse(tour.progress.isCurrentStopVisited)
        XCTAssertNil(tour.activities[stops[0].id].visitedAt)
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
    }

    func testStayHereSurvivesRelaunchAndDoesNotFinishFinalStopOnResume() async {
        let storage = InMemoryWalkResumeStore()
        func model() -> TourViewModel {
            TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
                locationService: ActivityTestLocationService(), directionsService: PreviewDirectionsService(),
                walkResumeStore: storage)
        }
        let first = model(); await first.loadStopsIfNeeded(); defer { cleanUp(first) }
        first.startTour()
        for _ in 0..<(stops.count - 1) { first.completeCurrentStopAndAdvance() }
        confirmArrival(first)
        first.toggleAutomaticDepartureHold()
        XCTAssertEqual(storage.load()?.departureHoldStopID, stops.last?.id)
        let resumed = model(); await resumed.loadStopsIfNeeded(); defer { cleanUp(resumed) }
        XCTAssertTrue(resumed.isWalkPaused)
        resumed.isAutomaticNavigationVisible = true
        resumed.startTour()
        confirmArrival(resumed)
        XCTAssertTrue(resumed.walkingProgression.isHeld)
        XCTAssertEqual(resumed.phase, .inProgress)
        resumed.toggleAutomaticDepartureHold()
        let now = Date().addingTimeInterval(1)
        let sample = LocationSample(coordinate: stops.last!.coordinate, timestamp: now)
        resumed.evaluateAutomaticProgression(sample, now: now)
        XCTAssertEqual(resumed.phase, .complete)
    }

    func testLocationPipelineAdvancesFromMillToGreystoneWithoutManualContinue() async throws {
        let source = ActivityTestLocationService(status: .authorized)
        let tour = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: source, directionsService: PreviewDirectionsService())
        await tour.loadStopsIfNeeded(); defer { cleanUp(tour) }
        tour.startTour(); tour.isAutomaticNavigationVisible = true
        let now = Date()
        let away = GeoCoordinate(latitude: stops[0].latitude + 0.002, longitude: stops[0].longitude)
        for (point, age) in [(stops[0].coordinate, -15.0), (stops[0].coordinate, -12.0), (away, -6.0), (away, 0.0)] {
            let sample = LocationSample(coordinate: point, horizontalAccuracy: 3,
                                        timestamp: now.addingTimeInterval(age))
            source.emit(sample)
            for _ in 0..<100 where tour.userLocation?.timestamp != sample.timestamp {
                try await Task.sleep(for: .milliseconds(2))
            }
            XCTAssertEqual(tour.userLocation?.timestamp, sample.timestamp)
        }
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
        XCTAssertTrue(tour.progress.isCompleted(stops[0].id))
        XCTAssertFalse(tour.progress.isCompleted(stops[1].id))
        XCTAssertEqual(tour.automaticTransitionFromStopID, stops[0].id)
    }

    func testRecognizedPlaqueWithWrongGeocodeCannotArmFalseAutomaticDeparture() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour(); tour.isAutomaticNavigationVisible = true
        XCTAssertTrue(tour.preparePlaqueScanner(stopID: stops[0].id))
        tour.confirmPlaqueArrival(for: stops[0].id)
        XCTAssertEqual(tour.activateCurrentStop(stopID: stops[0].id, trackingReady: true, plaqueIsTracked: true), .allow(.recognizedPlaque))
        XCTAssertTrue(tour.progress.isCurrentStopVisited)
        tour.endARDiscoverySession()
        let actualPlaquePoint = GeoCoordinate(latitude: stops[0].latitude + 0.002, longitude: stops[0].longitude)
        let now = Date()
        for age in [0.0, 5, 10] {
            let sample = LocationSample(coordinate: actualPlaquePoint, timestamp: now.addingTimeInterval(age))
            tour.evaluateAutomaticProgression(sample, now: sample.timestamp)
        }
        XCTAssertEqual(tour.currentStop?.id, stops[0].id, "A wrong geocode must not look like leaving the physical plaque")
        XCTAssertFalse(tour.walkingProgression.hasArrived)
        tour.completeCurrentStopAndAdvance()
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
    }

    private var stops: [HistoricalStop] { HistoricalStop.previewStops }
    private func makeTour(visitStore: (any StopVisitStore)? = nil, activityStore: (any StopActivityStore)? = nil) async -> TourViewModel {
        let model = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: ActivityTestLocationService(), directionsService: PreviewDirectionsService(),
            visitStore: visitStore, activityStore: activityStore)
        await model.loadStopsIfNeeded()
        return model
    }
    /// Two distinct fixes, with deterministic time, exercise the actual dwell policy.
    private func confirmArrival(_ tour: TourViewModel) {
        guard let stop = tour.currentStop else { return }
        let now = Date()
        for age in [-4.0, 0] {
            tour.evaluateAutomaticProgression(LocationSample(coordinate: stop.coordinate,
                horizontalAccuracy: 3, timestamp: now.addingTimeInterval(age)), now: now)
        }
    }

    private func cleanUp(_ model: TourViewModel) { model.stopLocation(); model.cancelRouting() }

    func testRestoredWalkIsPausedAndBrowsingDoesNotRequestPermissions() async {
        let storage = InMemoryWalkResumeStore()
        let first = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: ActivityTestLocationService(), directionsService: PreviewDirectionsService(),
            walkResumeStore: storage)
        await first.loadStopsIfNeeded()
        first.startTour()
        first.completeCurrentStopAndAdvance()
        cleanUp(first)

        let source = ActivityTestLocationService(status: .notDetermined)
        let restored = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: source, directionsService: PreviewDirectionsService(), walkResumeStore: storage)
        await restored.loadStopsIfNeeded()
        defer { cleanUp(restored) }
        XCTAssertEqual(restored.currentStop?.id, stops[1].id)
        XCTAssertEqual(restored.phase, .inProgress)
        XCTAssertTrue(restored.isWalkPaused)
        XCTAssertFalse(restored.isWalkingActive)
        XCTAssertFalse(restored.canContinueCurrentStop)
        XCTAssertFalse(restored.isShowingTour)
        XCTAssertNil(restored.userLocation)
        XCTAssertNil(restored.routingTask)
        restored.openStory(for: stops[0].id)
        let map = MapViewModel()
        map.show(stop: stops[0])
        XCTAssertEqual(map.viewedStopID, stops[0].id)
        XCTAssertEqual(restored.currentStop?.id, stops[1].id)
        XCTAssertTrue(restored.preparePlaqueScanner(stopID: stops[1].id))
        restored.endARDiscoverySession()
        XCTAssertTrue(restored.isWalkPaused)
        XCTAssertEqual(source.permissionRequests, 0)
        XCTAssertEqual(source.startRequests, 0)
        restored.startTour()
        XCTAssertEqual(source.permissionRequests, 1)
        XCTAssertFalse(restored.isWalkPaused)
        XCTAssertEqual(restored.currentStop?.id, stops[1].id)
        XCTAssertFalse(restored.activities[stops[0].id].learningCompleted)
    }

    func testCompletedWalkCanFocusAnyStopWithoutRestartOrPermission() async {
        let storage = InMemoryWalkResumeStore()
        let first = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: ActivityTestLocationService(), directionsService: PreviewDirectionsService(),
            walkResumeStore: storage)
        await first.loadStopsIfNeeded()
        first.startTour()
        for _ in stops { first.completeCurrentStopAndAdvance() }
        cleanUp(first)
        let savedFigures = first.completionFigures
        let source = ActivityTestLocationService(status: .notDetermined)
        let restored = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: source, directionsService: PreviewDirectionsService(), walkResumeStore: storage)
        await restored.loadStopsIfNeeded()
        defer { cleanUp(restored) }
        let map = MapViewModel()
        for stop in stops {
            map.show(stop: stop)
            XCTAssertEqual(map.viewedStopID, stop.id)
            guard case .follow(let coordinate, _) = map.cameraRequest?.kind else {
                XCTFail("Show on map should focus the requested site"); return
            }
            XCTAssertEqual(coordinate.latitude, stop.latitude)
            XCTAssertEqual(coordinate.longitude, stop.longitude)
        }
        XCTAssertEqual(restored.phase, .complete)
        XCTAssertEqual(restored.completionFigures.walkingSeconds, savedFigures.walkingSeconds)
        XCTAssertEqual(restored.completionFigures.distanceMeters, savedFigures.distanceMeters)
        XCTAssertFalse(restored.prepareForARFromDetails(), "Completed AR must not restart a walk")
        XCTAssertEqual(restored.phase, .complete)
        XCTAssertEqual(source.permissionRequests, 0)
        XCTAssertEqual(source.startRequests, 0)
    }

    func testViewedPlaceAndWalkingDestinationRemainSeparate() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        tour.completeCurrentStopAndAdvance()
        let map = MapViewModel()
        map.show(stop: stops[0])
        map.select(stopID: nil)
        XCTAssertEqual(map.viewedStopID, stops[0].id)
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
        map.clearViewedStop()
        XCTAssertNil(map.viewedStopID)
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
    }

    func testWalkResumeLocalStoreSurvivesNewStoreAndHandlesCorruption() async throws {
        let suite = "cranford.walk-resume.test.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let storage = LocalWalkResumeStore(defaults: defaults)
        let first = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: ActivityTestLocationService(), directionsService: PreviewDirectionsService(),
            walkResumeStore: storage)
        await first.loadStopsIfNeeded()
        first.startTour()
        first.completeCurrentStopAndAdvance()
        cleanUp(first)
        let reopened = LocalWalkResumeStore(defaults: defaults)
        XCTAssertEqual(reopened.load()?.progress.currentStopID, stops[1].id)
        defaults.set(Data("invalid".utf8), forKey: "cranford.walk-resume.v1")
        XCTAssertNil(reopened.load())
        reopened.save(nil)
        XCTAssertNil(defaults.data(forKey: "cranford.walk-resume.v1"))
    }

    func testChangedCatalogRejectsSavedWalkingDestinationWithoutPrompting() async {
        let storage = InMemoryWalkResumeStore()
        var progress = TourProgress(stopIDs: ["removed-stop"])
        progress.start()
        storage.save(WalkResumeRecord(progress: progress))
        let source = ActivityTestLocationService(status: .notDetermined)
        let tour = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: source, directionsService: PreviewDirectionsService(), walkResumeStore: storage)
        await tour.loadStopsIfNeeded()
        defer { cleanUp(tour) }
        XCTAssertEqual(tour.phase, .notStarted)
        XCTAssertNil(tour.currentStop)
        XCTAssertNil(storage.load())
        XCTAssertEqual(source.permissionRequests, 0)
    }

    func testEntireWalkNeedsOnlyGPSAndExplicitContinue() async throws {
        let source = ActivityTestLocationService(status: .authorized)
        let tour = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: source, directionsService: PreviewDirectionsService())
        await tour.loadStopsIfNeeded()
        defer { cleanUp(tour) }
        tour.startTour()
        for stop in stops {
            confirmArrival(tour)
            source.emit(LocationSample(coordinate: stop.coordinate, horizontalAccuracy: 3))
            for _ in 0..<100 where tour.userLocation?.coordinate != stop.coordinate {
                try await Task.sleep(for: .milliseconds(2))
            }
            XCTAssertEqual(tour.currentStop?.id, stop.id, "Arrival must not replace the destination")
            XCTAssertTrue(tour.isAtCurrentStopNow)
            XCTAssertNotNil(tour.activities[stop.id].visitedAt)
            XCTAssertFalse(tour.activities[stop.id].learningCompleted)
            XCTAssertNil(tour.activities[stop.id].bonusFoundAt)
            XCTAssertTrue(tour.canContinueCurrentStop)
            tour.completeCurrentStopAndAdvance()
        }
        XCTAssertEqual(tour.phase, .complete)
        XCTAssertFalse(tour.isARSessionActive)
        XCTAssertEqual(source.permissionRequests, 0)
    }

    func testMapCameraUsesWalkingDestinationAfterInspectingAnotherStop() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        tour.completeCurrentStopAndAdvance()
        XCTAssertTrue(tour.prepareForARFromDetails(stopID: stops[0].id))
        XCTAssertEqual(tour.arStop?.id, stops[0].id)
        XCTAssertTrue(tour.prepareForARFromDetails())
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
        XCTAssertEqual(tour.arStop?.id, stops[1].id)
        tour.endARDiscoverySession()
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
    }

    func testSavedVisitIsNotLiveArrival() async {
        var ledger = StopActivityLedger()
        ledger.visited(stops[0].id)
        let storage = InMemoryStopActivityStore()
        storage.save(ledger)
        let tour = await makeTour(activityStore: storage)
        defer { cleanUp(tour) }
        tour.startTour()
        XCTAssertTrue(tour.isCurrentStopVisited)
        XCTAssertFalse(tour.isAtCurrentStopNow)
    }

    func testExploringDoesNotRequestPermissionsOrStartLocation() async {
        let source = ActivityTestLocationService(status: .notDetermined)
        let tour = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: source, directionsService: PreviewDirectionsService())
        await tour.loadStopsIfNeeded()
        defer { cleanUp(tour) }
        tour.openStory(for: stops[0].id)
        tour.finishListening(for: stops[0].id)
        tour.finishStory(for: stops[1].id)
        XCTAssertEqual(source.permissionRequests, 0)
        XCTAssertEqual(source.startRequests, 0)
        XCTAssertEqual(tour.phase, .notStarted)
        tour.startTour()
        XCTAssertEqual(source.permissionRequests, 1)
    }
    func testArrivalWhileInspectingAnotherSitePreservesBothSubjects() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        XCTAssertTrue(tour.prepareForARFromDetails(stopID: stops[1].id))
        confirmArrival(tour)
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
        XCTAssertEqual(tour.arStop?.id, stops[1].id)
        XCTAssertNotNil(tour.activities[stops[0].id].visitedAt)
        XCTAssertFalse(tour.activities[stops[0].id].learningCompleted)
        XCTAssertNil(tour.activities[stops[1].id].bonusFoundAt)
    }
    func testMissingReadingTextCannotFalselyCompleteLearning() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.finishStory(for: stops[2].id)
        XCTAssertFalse(tour.activities[stops[2].id].learningCompleted)
        tour.finishListening(for: stops[2].id)
        XCTAssertFalse(tour.activities[stops[2].id].learningCompleted, "Pending narration cannot be completed")
    }
    func testSelectingPlaqueClearsOldSignButPreservesWalkingDestination() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        tour.presentedSignStopID = stops[0].id
        XCTAssertTrue(tour.prepareForARFromDetails(stopID: stops[1].id))
        XCTAssertNil(tour.presentedSignStopID)
        XCTAssertEqual(tour.arStop?.id, stops[1].id)
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
    }
    func testRemoteListeningAndReadingCompleteOnlyTheirOwnLearningActivities() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.finishListening(for: stops[0].id)
        tour.finishStory(for: stops[1].id)
        XCTAssertEqual(tour.phase, .notStarted)
        XCTAssertNil(tour.currentStop)
        XCTAssertTrue(tour.activities[stops[0].id].learningCompleted)
        XCTAssertTrue(tour.activities[stops[1].id].learningCompleted)
        XCTAssertNil(tour.activities[stops[0].id].visitedAt)
        XCTAssertNil(tour.activities[stops[1].id].bonusFoundAt)
    }
    func testListeningToMillWhileWalkingToParkDoesNotChangeDestination() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        tour.completeCurrentStopAndAdvance()
        let destination = tour.currentStop?.id
        let navigation = AppNavigation()
        navigation.photoSelections[stops[0].id] = 3
        navigation.selectedTab = .stops
        tour.openStory(for: stops[0].id)
        tour.finishListening(for: stops[0].id)
        tour.finishStory(for: stops[0].id)
        tour.openStory(for: stops[4].id)
        navigation.selectedTab = .map
        XCTAssertEqual(tour.currentStop?.id, destination)
        XCTAssertEqual(destination, stops[1].id)
        XCTAssertFalse(tour.activities[stops[1].id].learningCompleted)
        XCTAssertNil(tour.activities[stops[0].id].visitedAt)
        XCTAssertEqual(navigation.photoSelections[stops[0].id], 3)
    }
    func testGPSRecordsVisitWithoutCompletingLearningBonusOrAdvancing() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        let sample = LocationSample(coordinate: stops[0].coordinate, horizontalAccuracy: 3)
        tour.handleLocationForProximity(sample)
        confirmArrival(tour)
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
        XCTAssertNotNil(tour.activities[stops[0].id].visitedAt)
        XCTAssertFalse(tour.activities[stops[0].id].learningCompleted)
        XCTAssertNil(tour.activities[stops[0].id].bonusFoundAt)
        tour.handleLocationForProximity(sample)
        XCTAssertEqual(tour.visitRecords.count, 1)
        tour.completeCurrentStopAndAdvance()
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
    }
    func testSkippedStopDoesNotReceiveVisitOrLearningCredit() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        tour.completeCurrentStopAndAdvance()
        XCTAssertEqual(tour.progress.completedCount, 0)
        XCTAssertEqual(tour.activities[stops[0].id], StopActivities())
    }
    func testWeakStaleAndSimulatedGPSNeverPersistRealActivity() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        for sample in [
            LocationSample(coordinate: stops[0].coordinate, horizontalAccuracy: 80),
            LocationSample(coordinate: stops[0].coordinate, horizontalAccuracy: -1),
            LocationSample(coordinate: stops[0].coordinate, timestamp: Date().addingTimeInterval(-100)),
            LocationSample(coordinate: stops[0].coordinate, isSimulated: true)
        ] { tour.handleLocationForProximity(sample) }
        XCTAssertEqual(tour.activities[stops[0].id], StopActivities())
        XCTAssertTrue(tour.visitRecords.isEmpty)
    }
    func testGPSCanRecordPhysicalSiteWithoutStartingAnItinerary() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.handleLocationForProximity(LocationSample(coordinate: stops[3].coordinate))
        XCTAssertNotNil(tour.activities[stops[3].id].visitedAt)
        XCTAssertEqual(tour.phase, .notStarted)
    }
    func testPlaqueSelectionAndRecognitionDoNotRetargetWalkOrRequireLearning() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        XCTAssertTrue(tour.selectRecognizedPlaque(imageName: SignPlacementPolicy.parkReferenceImageName,
                                                isTracked: true, trackingReady: true))
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
        XCTAssertEqual(tour.arStop?.id, stops[1].id)
        XCTAssertTrue(tour.beginPlaqueDiscovery())
        tour.confirmPlaqueArrival(for: stops[1].id)
        XCTAssertEqual(tour.activateCurrentStop(stopID: stops[1].id, trackingReady: true, plaqueIsTracked: true), .allow(.recognizedPlaque))
        XCTAssertNotNil(tour.activities[stops[1].id].bonusFoundAt)
        XCTAssertNotNil(tour.activities[stops[1].id].visitedAt)
        XCTAssertFalse(tour.activities[stops[1].id].learningCompleted)
        XCTAssertFalse(tour.activities[stops[0].id].learningCompleted)
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
    }
    func testPlaqueCanBeDiscoveredWithoutStartingWalkOrRequestingGPS() async {
        let source = ActivityTestLocationService(status: .notDetermined)
        let tour = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: source, directionsService: PreviewDirectionsService())
        await tour.loadStopsIfNeeded()
        defer { cleanUp(tour) }
        XCTAssertTrue(tour.preparePlaqueScanner(stopID: stops[1].id))
        XCTAssertEqual(tour.arStop?.id, stops[1].id)
        XCTAssertEqual(tour.discovery.stage, .searching)
        XCTAssertEqual(tour.phase, .notStarted)
        XCTAssertFalse(tour.isShowingTour)
        tour.confirmPlaqueArrival(for: stops[1].id)
        XCTAssertEqual(tour.activateCurrentStop(stopID: stops[1].id, trackingReady: true, plaqueIsTracked: true), .allow(.recognizedPlaque))
        tour.endARDiscoverySession()
        XCTAssertNil(tour.currentStop)
        XCTAssertNotNil(tour.activities[stops[1].id].bonusFoundAt)
        XCTAssertFalse(tour.activities[stops[1].id].learningCompleted)
        XCTAssertEqual(tour.activities[stops[0].id], StopActivities())
        XCTAssertEqual(source.permissionRequests, 0)
        XCTAssertEqual(source.startRequests, 0)
    }

    func testScannerCanRecognizeAnotherSupportedStopWithoutRetargetingWalk() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        tour.completeCurrentStopAndAdvance()
        tour.continuedARStopIDs.insert(stops[0].id)
        XCTAssertTrue(tour.preparePlaqueScanner(stopID: stops[1].id))
        XCTAssertTrue(tour.selectRecognizedPlaque(imageName: SignPlacementPolicy.millReferenceImageName,
            isTracked: true, trackingReady: true))
        XCTAssertEqual(tour.arStop?.id, stops[0].id)
        XCTAssertTrue(tour.beginPlaqueDiscovery())
        tour.confirmPlaqueArrival(for: stops[0].id)
        XCTAssertEqual(tour.activateCurrentStop(stopID: stops[0].id, trackingReady: true, plaqueIsTracked: true), .allow(.recognizedPlaque))
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
        XCTAssertNotNil(tour.activities[stops[0].id].bonusFoundAt)
        XCTAssertNil(tour.activities[stops[1].id].bonusFoundAt)
        tour.endARDiscoverySession()
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
    }

    func testScannerDoesNotRestartACompletedWalk() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        for _ in stops { tour.completeCurrentStopAndAdvance() }
        XCTAssertEqual(tour.phase, .complete)
        XCTAssertTrue(tour.preparePlaqueScanner(stopID: stops[1].id))
        tour.confirmPlaqueArrival(for: stops[1].id)
        XCTAssertEqual(tour.activateCurrentStop(stopID: stops[1].id, trackingReady: true, plaqueIsTracked: true), .allow(.recognizedPlaque))
        tour.endARDiscoverySession()
        XCTAssertEqual(tour.phase, .complete)
        XCTAssertNil(tour.currentStop)
        XCTAssertNotNil(tour.activities[stops[1].id].bonusFoundAt)
    }

    func testScannerRetryAndReturnPreserveSavedBonusWithoutCompletingStory() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        XCTAssertTrue(tour.preparePlaqueScanner(stopID: stops[1].id))
        tour.confirmPlaqueArrival(for: stops[1].id)
        XCTAssertEqual(tour.activateCurrentStop(stopID: stops[1].id, trackingReady: true, plaqueIsTracked: true), .allow(.recognizedPlaque))
        let saved = tour.activities[stops[1].id]
        XCTAssertTrue(tour.preparePlaqueScanner(stopID: stops[1].id))
        XCTAssertEqual(tour.activities[stops[1].id], saved)
        XCTAssertTrue(tour.discovery.hasVerifiedPlaque)
        XCTAssertFalse(tour.discovery.hasFinishedStory)
        tour.endARDiscoverySession()
        tour.openStory(for: stops[1].id)
        XCTAssertEqual(tour.activities[stops[1].id], saved)
        XCTAssertEqual(tour.phase, .notStarted)
    }

    func testUnsupportedScannerEntryDoesNotChangeWalkOrARSubject() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        XCTAssertTrue(tour.preparePlaqueScanner(stopID: stops[1].id))
        XCTAssertFalse(tour.preparePlaqueScanner(stopID: stops[2].id))
        XCTAssertFalse(tour.preparePlaqueScanner(stopID: "unknown"))
        XCTAssertEqual(tour.arStop?.id, stops[1].id)
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
    }

    func testKnownUnknownUntrackedAndLimitedReferencesAreIsolated() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        for (name, tracked, ready) in [("unknown", true, true), (SignPlacementPolicy.parkReferenceImageName, false, true), (SignPlacementPolicy.parkReferenceImageName, true, false)] {
            XCTAssertFalse(tour.selectRecognizedPlaque(imageName: name, isTracked: tracked, trackingReady: ready))
        }
        XCTAssertEqual(tour.arStop?.id, stops[0].id)
        XCTAssertEqual(tour.activities[stops[1].id], StopActivities())
    }
    func testGPSVisitCanLaterUnlockBonusWithoutInventingStoryCompletion() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.handleLocationForProximity(LocationSample(coordinate: stops[1].coordinate))
        XCTAssertNil(tour.activities[stops[1].id].bonusFoundAt)
        XCTAssertTrue(tour.prepareForARFromDetails(stopID: stops[1].id))
        tour.beginPlaqueDiscovery()
        tour.confirmPlaqueArrival(for: stops[1].id)
        XCTAssertEqual(tour.activateCurrentStop(stopID: stops[1].id, trackingReady: true, plaqueIsTracked: true), .allow(.recognizedPlaque))
        XCTAssertFalse(tour.activities[stops[1].id].learningCompleted)
        XCTAssertEqual(tour.visitRecords.count, 1)
    }
    func testReadingAndListeningSurviveResetAndStorageReload() async {
        let store = InMemoryStopActivityStore()
        let tour = await makeTour(activityStore: store); defer { cleanUp(tour) }
        tour.finishListening(for: stops[0].id)
        tour.finishStory(for: stops[1].id)
        tour.resetTour()
        let reloaded = await makeTour(activityStore: store); defer { cleanUp(reloaded) }
        XCTAssertNotNil(reloaded.activities[stops[0].id].listenedAt)
        XCTAssertNotNil(reloaded.activities[stops[1].id].readAt)
        XCTAssertNil(reloaded.activities[stops[1].id].visitedAt)
    }
    func testLegacyPlaqueVisitsMigrateOnlyVisitAndBonus() async {
        let visits = InMemoryStopVisitStore()
        visits.record(StopVisitRecord(stopID: stops[0].id, activatedAt: Date(), evidence: .recognizedPlaque))
        let tour = await makeTour(visitStore: visits); defer { cleanUp(tour) }
        XCTAssertNotNil(tour.activities[stops[0].id].visitedAt)
        XCTAssertNotNil(tour.activities[stops[0].id].bonusFoundAt)
        XCTAssertFalse(tour.activities[stops[0].id].learningCompleted)
    }
    func testPersistentActivityStoreHandlesCorruptionAndReload() async {
        let suite = "cranford.activities.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("broken".utf8), forKey: "cranford.stop-activities.v1")
        let store = LocalStopActivityStore(defaults: defaults)
        XCTAssertEqual(store.load(), StopActivityLedger())
        var ledger = StopActivityLedger()
        ledger.read("park")
        ledger.visited("mill")
        ledger.foundBonus(at: "mill")
        store.save(ledger)
        XCTAssertEqual(LocalStopActivityStore(defaults: defaults).load(), ledger)
    }
    func testRestartClearsPriorWalkRoutesWithoutClearingStories() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        tour.finishStory(for: stops[0].id)
        tour.legRoutes[TourViewModel.startLegKey] = WalkingRoute.straightLineEstimate(from: stops[1].coordinate, to: stops[0].coordinate)
        tour.resetTour()
        XCTAssertNil(tour.legRoutes[TourViewModel.startLegKey])
        XCTAssertTrue(tour.activities[stops[0].id].learningCompleted)
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
    }

    func testGoodFixBecomesWaitingAndMarginalFixShowsWarning() async throws {
        let source = ActivityTestLocationService(status: .authorized)
        let tour = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: source, directionsService: PreviewDirectionsService())
        await tour.loadStopsIfNeeded(); defer { cleanUp(tour) }
        tour.startTour()
        source.emit(LocationSample(coordinate: stops[1].coordinate,
            horizontalAccuracy: 3, timestamp: Date().addingTimeInterval(-29.9)))
        for _ in 0..<100 where tour.userLocation == nil { try await Task.sleep(for: .milliseconds(2)) }
        try await Task.sleep(for: .milliseconds(120))
        tour.refreshLocationIssue()
        XCTAssertEqual(tour.locationIssue, .waitingForSignal)
        source.emit(LocationSample(coordinate: stops[1].coordinate, horizontalAccuracy: 30))
        for _ in 0..<100 where tour.userLocation?.horizontalAccuracy != 30 { try await Task.sleep(for: .milliseconds(2)) }
        XCTAssertEqual(tour.locationIssue, .poorAccuracy(meters: 30))
    }

    func testRecoveryHasFiniteBudgetAndDestinationChangeCancelsIt() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        for _ in 0..<20 { tour.scheduleRouteRecovery() }
        XCTAssertEqual(tour.routeRecoveryAttempts, 5)
        XCTAssertNotNil(tour.routeRecoveryTask)
        tour.completeCurrentStopAndAdvance()
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
        XCTAssertEqual(tour.routeRecoveryAttempts, 0)
        XCTAssertNil(tour.routeRecoveryTask)
    }

    func testStationaryRecoveryRequestsRouteWithoutAdvancing() async throws {
        let source = ActivityTestLocationService(status: .authorized)
        let service = FailOnceRecoveryDirections()
        let tour = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: source, directionsService: service)
        await tour.loadStopsIfNeeded(); defer { cleanUp(tour) }
        // Preload summary legs so only live walking requests exercise this failure.
        for i in 1..<stops.count {
            tour.legRoutes[TourViewModel.legKey(from: stops[i-1], to: stops[i])] =
                WalkingRoute.straightLineEstimate(from: stops[i-1].coordinate, to: stops[i].coordinate)
        }
        tour.routeRecoveryDelay = .milliseconds(100)
        tour.startTour()
        source.emit(LocationSample(coordinate: stops[1].coordinate, horizontalAccuracy: 3))
        for _ in 0..<100 where !tour.isRouteAnEstimate { try await Task.sleep(for: .milliseconds(2)) }
        XCTAssertTrue(tour.isRouteAnEstimate)
        for _ in 0..<200 where tour.currentRoute?.source != .simulated { try await Task.sleep(for: .milliseconds(2)) }
        XCTAssertEqual(tour.currentRoute?.source, .simulated)
        XCTAssertNil(tour.routingError)
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
        let calls = await service.calls
        XCTAssertEqual(calls, 2)
    }

    func testTourStoresKeepLegacyDataAndIsolateOtherTourAndRevision() async throws {
        let suite = "catalog-test-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let visits = LocalStopVisitStore(defaults: defaults)
        let activities = LocalStopActivityStore(defaults: defaults)
        let walks = LocalWalkResumeStore(defaults: defaults)
        let date = Date()
        visits.record(StopVisitRecord(stopID: "same", activatedAt: date, evidence: .recognizedPlaque))
        var ledger = StopActivityLedger(); ledger.read("same"); activities.save(ledger)
        var progress = TourProgress(stopIDs: ["same"]); progress.start()
        walks.save(WalkResumeRecord(progress: progress))
        let other = TourCatalogIdentity(tourID: "other")
        visits.selectTour(other); activities.selectTour(other); walks.selectTour(other)
        XCTAssertTrue(visits.records().isEmpty)
        XCTAssertFalse(activities.load()["same"].learningCompleted)
        XCTAssertNil(walks.load())
        ledger = StopActivityLedger(); ledger.listened(to: "other"); activities.save(ledger)
        walks.save(WalkResumeRecord(progress: progress, catalogIdentity: other, sessionID: UUID()))
        let revision = TourCatalogIdentity(tourID: "other", version: 2)
        activities.selectTour(revision); walks.selectTour(revision)
        XCTAssertTrue(activities.load()["other"].learningCompleted)
        XCTAssertNil(walks.load())
        visits.selectTour(.legacy); activities.selectTour(.legacy); walks.selectTour(.legacy)
        XCTAssertEqual(visits.records().first?.activatedAt, date)
        XCTAssertTrue(activities.load()["same"].learningCompleted)
        XCTAssertNotNil(walks.load())
    }

    func testWalkSessionResumesThenRestartCreatesDifferentIdentity() async {
        let store = InMemoryWalkResumeStore()
        let first = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: ActivityTestLocationService(), directionsService: PreviewDirectionsService(), walkResumeStore: store)
        await first.loadStopsIfNeeded(); defer { cleanUp(first) }
        first.startTour(); first.completeCurrentStopAndAdvance()
        let session = first.walkSessionID
        let restored = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: ActivityTestLocationService(), directionsService: PreviewDirectionsService(), walkResumeStore: store)
        await restored.loadStopsIfNeeded(); defer { cleanUp(restored) }
        XCTAssertEqual(restored.walkSessionID, session)
        XCTAssertEqual(restored.currentStop?.id, stops[1].id)
        XCTAssertTrue(restored.isWalkPaused)
        restored.resetTour()
        XCTAssertNotEqual(restored.walkSessionID, session)
        XCTAssertEqual(restored.currentStop?.id, stops[0].id)
    }

    func testBonusRestoredAfterReopenRemainsIndependent() async {
        let store = InMemoryStopActivityStore()
        var ledger = StopActivityLedger(); ledger.foundBonus(at: stops[1].id)
        store.save(ledger)
        let tour = await makeTour(activityStore: store); defer { cleanUp(tour) }
        XCTAssertTrue(tour.prepareForARFromDetails(stopID: stops[1].id))
        XCTAssertTrue(tour.discovery.hasVerifiedPlaque)
        XCTAssertFalse(tour.discovery.hasFinishedStory)
        XCTAssertNil(tour.activities[stops[1].id].visitedAt)
    }
}

@MainActor
private final class ActivityTestLocationService: LocationService {
    private let status: LocationAuthorization
    private let broadcaster = EventBroadcaster<LocationEvent>()
    private(set) var permissionRequests = 0
    private(set) var startRequests = 0
    init(status: LocationAuthorization = .denied) { self.status = status }
    var authorization: LocationAuthorization { status }
    var isPreciseLocationAuthorized: Bool { true }
    var isHeadingAvailable: Bool { false }
    func events() -> AsyncStream<LocationEvent> { broadcaster.stream() }
    func emit(_ sample: LocationSample) { broadcaster.send(.location(sample)) }
    func requestWhenInUseAuthorization() { permissionRequests += 1 }
    func requestTemporaryPreciseLocationIfNeeded() {}
    func start() { startRequests += 1 }
    func requestFreshLocation() {}
    func stop() {}
}

#if canImport(CranfordHistoricalAR)
@MainActor
final class StopVisitStoreTests: XCTestCase {
    #if DEVELOPER_MENU
    func testGPSRefreshWaitsForNewTimestampAndUsesSharedLocationPipeline() async throws {
        let point = HistoricalStop.previewStops[0].coordinate
        let service = DeveloperTestLocationService(sample: LocationSample(coordinate: point))
        let tour = TourViewModel(stopService: InMemoryHistoricalStopService(stops: HistoricalStop.previewStops),
                                 locationService: service, directionsService: PreviewDirectionsService())
        await tour.loadStopsIfNeeded()
        tour.startTour()
        defer { tour.stopLocation(); tour.cancelRouting() }
        for _ in 0..<100 where tour.userLocation == nil { try await Task.sleep(for: .milliseconds(5)) }
        let developer = DeveloperModeController(tour: tour, realLocationService: service)
        developer.refreshGPSNow()
        developer.refreshGPSNow()
        XCTAssertEqual(service.refreshRequests, 1, "Repeated taps cannot overlap requests")
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertTrue(developer.isRefreshingGPS, "The existing coordinate must not count as a fresh fix")
        let fresh = LocationSample(coordinate: point, horizontalAccuracy: 3)
        service.emit(fresh)
        for _ in 0..<100 where developer.isRefreshingGPS { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(developer.isRefreshingGPS)
        XCTAssertEqual(developer.gpsRefreshMessage, "Fresh GPS coordinates received.")
        XCTAssertEqual(tour.userLocation, fresh)
        XCTAssertEqual(tour.currentStop?.id, HistoricalStop.previewStops[0].id)
        developer.enableSimulation()
        developer.refreshGPSNow()
        XCTAssertEqual(service.refreshRequests, 1)
        XCTAssertFalse(developer.isRefreshingGPS)
    }

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
    private let broadcaster = EventBroadcaster<LocationEvent>()
    private(set) var refreshRequests = 0
    func emit(_ sample: LocationSample) { broadcaster.send(.location(sample)) }
    init(sample: LocationSample? = nil) { self.sample = sample }
    var authorization: LocationAuthorization { .authorized }
    var isPreciseLocationAuthorized: Bool { true }
    var isHeadingAvailable: Bool { false }
    func events() -> AsyncStream<LocationEvent> {
        let stream = broadcaster.stream(replayLatest: false)
        if let sample { broadcaster.send(.location(sample)) }
        return stream
    }
    func requestWhenInUseAuthorization() {}
    func requestTemporaryPreciseLocationIfNeeded() {}
    func start() {}
    func requestFreshLocation() { refreshRequests += 1 }
    func stop() {}
}
#endif

#endif

/// Provider selection logic runs on Linux and in the native host without network requests.
final class WalkingProviderFallbackTests: XCTestCase {
    func testPrimaryWalkingRouteWins() async throws {
        let primary = WalkingProviderStub(source: .googleRoutesAPI)
        let fallback = WalkingProviderStub(source: .appleMaps)
        let service = FallbackWalkingDirectionsService(primary: primary, fallback: fallback)
        let route = try await service.walkingRoute(from: point, to: point)
        XCTAssertEqual(route.source, .googleRoutesAPI)
        let calls = await fallback.calls
        XCTAssertEqual(calls, 0)
    }

    func testProviderFailureUsesAppleWalkingRoute() async throws {
        let primary = WalkingProviderStub(source: .googleRoutesAPI, fails: true)
        let fallback = WalkingProviderStub(source: .appleMaps)
        let service = FallbackWalkingDirectionsService(primary: primary, fallback: fallback)
        let route = try await service.walkingRoute(from: point, to: point)
        XCTAssertEqual(route.source, .appleMaps)
        let calls = await fallback.calls
        XCTAssertEqual(calls, 1)
    }

    func testCancellationDoesNotRequestAnotherProvider() async {
        let primary = WalkingProviderStub(source: .googleRoutesAPI, cancels: true)
        let fallback = WalkingProviderStub(source: .appleMaps)
        let service = FallbackWalkingDirectionsService(primary: primary, fallback: fallback)
        do { _ = try await service.walkingRoute(from: point, to: point); XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        let calls = await fallback.calls
        XCTAssertEqual(calls, 0)
    }

    private var point: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: 40.650249, longitude: -74.301047) }
}

private actor WalkingProviderStub: DirectionsService {
    let source: RouteSource
    let fails: Bool
    let cancels: Bool
    private(set) var calls = 0
    init(source: RouteSource, fails: Bool = false, cancels: Bool = false) {
        self.source = source; self.fails = fails; self.cancels = cancels
    }
    func walkingRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> WalkingRoute {
        calls += 1
        if cancels { throw CancellationError() }
        if fails { throw URLError(.cannotConnectToHost) }
        var route = WalkingRoute.straightLineEstimate(
            from: GeoCoordinate(latitude: origin.latitude, longitude: origin.longitude),
            to: GeoCoordinate(latitude: destination.latitude, longitude: destination.longitude))
        route.source = source
        return route
    }
}

private actor FailOnceRecoveryDirections: DirectionsService {
    private(set) var calls = 0
    func walkingRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> WalkingRoute {
        calls += 1
        if calls == 1 { throw NSError(domain: "RecoveryTest", code: 1) }
        var route = WalkingRoute.straightLineEstimate(
            from: GeoCoordinate(latitude: origin.latitude, longitude: origin.longitude),
            to: GeoCoordinate(latitude: destination.latitude, longitude: destination.longitude))
        route.source = .simulated
        return route
    }
}
