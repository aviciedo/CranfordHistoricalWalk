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
    func testEveryConfiguredPlaqueUsesTheSamePassportUnlockLifecycle() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        let plaqueStops = tour.sketchbookStops
        XCTAssertGreaterThanOrEqual(plaqueStops.count, 2)
        for (index, stop) in plaqueStops.enumerated() {
            let storeDate = Date(timeIntervalSince1970: Double(1000 + index))
            XCTAssertTrue(tour.preparePlaqueScanner(stopID: stop.id))
            XCTAssertNil(tour.pendingSketchStopID)
            XCTAssertEqual(tour.recognizeSketchPlaque(imageName: stop.plaque?.referenceImageName,
                isTracked: true, trackingReady: true, now: storeDate), .allow(.recognizedPlaque))
            XCTAssertEqual(tour.activities[stop.id].plaqueUnlockedAt, storeDate)
            XCTAssertEqual(tour.pendingSketchStopID, stop.id)
            // Repeated ARKit updates must neither change the award nor restart celebration.
            XCTAssertEqual(tour.recognizeSketchPlaque(imageName: stop.plaque?.referenceImageName,
                isTracked: true, trackingReady: true), .alreadyActivated)
            XCTAssertEqual(tour.activities[stop.id].plaqueUnlockedAt, storeDate)
            tour.endARDiscoverySession()
            XCTAssertEqual(tour.takeUnlockedSketch(), stop.id)
            XCTAssertNil(tour.takeUnlockedSketch())
            XCTAssertTrue(tour.preparePlaqueScanner(stopID: stop.id))
            XCTAssertEqual(tour.recognizeSketchPlaque(imageName: stop.plaque?.referenceImageName,
                isTracked: true, trackingReady: true), .alreadyActivated)
            XCTAssertNil(tour.pendingSketchStopID)
            XCTAssertEqual(tour.sketchbookCollectedCount, index + 1)
            tour.endARDiscoverySession()
        }
        XCTAssertEqual(tour.phase, .notStarted, "The same camera-only flow applies without a walk")
    }

    func testSharedPassportRecognitionRejectsUntrackedUnknownAndLimitedImages() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        for stop in tour.sketchbookStops {
            XCTAssertTrue(tour.preparePlaqueScanner(stopID: stop.id))
            XCTAssertEqual(tour.recognizeSketchPlaque(imageName: stop.plaque?.referenceImageName,
                isTracked: false, trackingReady: true), .deny(.markerNotReady))
            XCTAssertEqual(tour.recognizeSketchPlaque(imageName: stop.plaque?.referenceImageName,
                isTracked: true, trackingReady: false), .deny(.trackingNotReady))
            XCTAssertEqual(tour.recognizeSketchPlaque(imageName: "unknown",
                isTracked: true, trackingReady: true), .deny(.markerNotReady))
            XCTAssertNil(tour.activities[stop.id].plaqueUnlockedAt)
            XCTAssertNil(tour.pendingSketchStopID)
        }
    }

    func testPassportUsesExistingBonusHistoryWithoutReplayingCelebration() async {
        let store = InMemoryStopActivityStore()
        var ledger = StopActivityLedger()
        ledger.collectSketch(at: stops[0].id)
        ledger.visited(stops[1].id)
        ledger.read(stops[1].id)
        store.save(ledger)
        let tour = await makeTour(activityStore: store); defer { cleanUp(tour) }
        XCTAssertEqual(tour.sketchbookStops.map(\.id), [stops[0].id, stops[1].id])
        XCTAssertEqual(tour.sketchbookCollectedCount, 1, "Visits and reading do not award stamps")
        XCTAssertNil(tour.pendingSketchStopID)
        XCTAssertNil(tour.takeUnlockedSketch())
        XCTAssertEqual(tour.phase, .notStarted)
    }

    func testNewRealPlaqueQueuesExactlyOnePassportRevealAndSurvivesNewWalk() async {
        let store = InMemoryStopActivityStore()
        let tour = await makeTour(activityStore: store); defer { cleanUp(tour) }
        XCTAssertTrue(tour.preparePlaqueScanner(stopID: stops[1].id))
        tour.confirmPlaqueArrival(for: stops[1].id)
        XCTAssertEqual(tour.activateCurrentStop(stopID: stops[1].id, trackingReady: true, plaqueIsTracked: true), .allow(.recognizedPlaque))
        XCTAssertEqual(tour.sketchbookCollectedCount, 1)
        XCTAssertNotNil(store.load()[stops[1].id].plaqueUnlockedAt, "Persist before announcing the stamp")
        XCTAssertEqual(tour.pendingSketchStopID, stops[1].id)
        tour.endARDiscoverySession()
        XCTAssertEqual(tour.takeUnlockedSketch(), stops[1].id, "Retain event through AR teardown")
        XCTAssertNil(tour.takeUnlockedSketch(), "Consume only once")
        XCTAssertTrue(tour.preparePlaqueScanner(stopID: stops[1].id))
        tour.confirmPlaqueArrival(for: stops[1].id)
        XCTAssertEqual(tour.activateCurrentStop(stopID: stops[1].id, trackingReady: true, plaqueIsTracked: true), .alreadyActivated)
        XCTAssertNil(tour.pendingSketchStopID)
        XCTAssertEqual(tour.sketchbookCollectedCount, 1)
        tour.endARDiscoverySession()
        XCTAssertEqual(tour.phase, .notStarted, "Plaque discovery alone never starts a walk")
        tour.resetTour()
        XCTAssertEqual(tour.sketchbookCollectedCount, 1)
        XCTAssertEqual(tour.phase, .inProgress, "Explicit Start another walk retains the existing restart behavior")
        XCTAssertFalse(tour.activities[stops[1].id].learningCompleted)
        let reloaded = await makeTour(activityStore: store); defer { cleanUp(reloaded) }
        XCTAssertEqual(reloaded.sketchbookCollectedCount, 1)
        XCTAssertNil(reloaded.pendingSketchStopID, "Relaunch preserves stamps without an unsolicited celebration")
    }

    func testPracticeAndDisabledRecordingDoNotAwardPassportStamps() async {
        let practice = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: SimulatedLocationService(start: stops[0].coordinate), directionsService: PreviewDirectionsService())
        await practice.loadStopsIfNeeded(); defer { cleanUp(practice) }
        XCTAssertTrue(practice.preparePlaqueScanner(stopID: stops[0].id))
        practice.confirmPlaqueArrival(for: stops[0].id)
        XCTAssertEqual(practice.activateCurrentStop(stopID: stops[0].id, trackingReady: true, plaqueIsTracked: true), .allow(.simulation))
        XCTAssertEqual(practice.sketchbookCollectedCount, 0)
        XCTAssertNil(practice.pendingSketchStopID)
        #if DEVELOPER_MENU
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.isVisitRecordingEnabled = false
        XCTAssertTrue(tour.preparePlaqueScanner(stopID: stops[1].id))
        tour.confirmPlaqueArrival(for: stops[1].id)
        _ = tour.activateCurrentStop(stopID: stops[1].id, trackingReady: true, plaqueIsTracked: true)
        XCTAssertEqual(tour.sketchbookCollectedCount, 0)
        XCTAssertNil(tour.pendingSketchStopID)
        #endif
    }

    func testPassportVisitOnlyAndFullResetsRemainIndependent() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        XCTAssertTrue(tour.preparePlaqueScanner(stopID: stops[0].id))
        tour.confirmPlaqueArrival(for: stops[0].id)
        _ = tour.activateCurrentStop(stopID: stops[0].id, trackingReady: true, plaqueIsTracked: true)
        #if DEVELOPER_MENU
        tour.clearRecordedActivitiesAndRestart(includingStoriesAndSketches: false)
        XCTAssertEqual(tour.sketchbookCollectedCount, 1)
        XCTAssertNil(tour.activities[stops[0].id].visitedAt)
        XCTAssertNil(tour.pendingSketchStopID)
        tour.clearRecordedActivitiesAndRestart(includingStoriesAndSketches: true)
        XCTAssertEqual(tour.sketchbookCollectedCount, 0)
        XCTAssertNil(tour.pendingSketchStopID)
        #endif
    }

    func testSavedVisitAndBonusNeverSuppressReturnWalkingArrows() async {
        let store = InMemoryStopActivityStore()
        var ledger = StopActivityLedger()
        ledger.visited(stops[0].id)
        ledger.collectSketch(at: stops[0].id)
        store.save(ledger)
        let tour = await makeTour(activityStore: store); defer { cleanUp(tour) }
        tour.startTour()
        XCTAssertTrue(tour.isARStopVisited, "Saved accomplishments remain intact")
        XCTAssertTrue(tour.discovery.hasArrived, "Saved bonus discovery must not masquerade as current presence")
        XCTAssertFalse(tour.shouldSuppressWalkingAR, "Still guide the user toward a previously visited destination")
        XCTAssertFalse(tour.hasPlaqueConfirmedArrival)
        confirmArrival(tour)
        XCTAssertFalse(tour.shouldSuppressWalkingAR, "GPS arrival alone must not hide directions before finding the plaque")
        tour.confirmPlaqueArrival(for: stops[0].id)
        XCTAssertTrue(tour.shouldSuppressWalkingAR, "Current-session plaque confirmation ends walking guidance")
    }

    func testWalkingArrowsResumeOnAdvanceAndPreviousWithoutErasingVisits() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        confirmArrival(tour)
        tour.confirmPlaqueArrival(for: stops[0].id)
        XCTAssertTrue(tour.shouldSuppressWalkingAR)
        tour.completeCurrentStopAndAdvance()
        XCTAssertFalse(tour.shouldSuppressWalkingAR)
        XCTAssertTrue(tour.goToPreviousStop())
        XCTAssertTrue(tour.isARStopVisited)
        XCTAssertFalse(tour.shouldSuppressWalkingAR, "Previous must guide back even though the visit persists")
    }

    func testQuietMapEmphasizesOnlyDestinationWithoutHidingOtherStops() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        let map = MapViewModel()
        let welcome = map.markers(for: tour, emphasizesDestinationOnly: true)
        XCTAssertEqual(welcome.count, stops.count)
        XCTAssertEqual(welcome.filter(\.isIllustrated).map(\.id), [stops[0].id])
        tour.startTour()
        tour.completeCurrentStopAndAdvance()
        tour.progress.markCurrentStopVisited()
        let active = map.markers(for: tour, emphasizesDestinationOnly: true)
        XCTAssertEqual(active.filter(\.isIllustrated).map(\.id), [stops[1].id])
        XCTAssertEqual(active.first { $0.id == stops[1].id }?.state, .visited,
                       "A visited active destination still deserves the illustration")
        XCTAssertTrue(map.markers(for: tour).allSatisfy(\.isIllustrated), "Other map consumers keep their existing artwork")
    }

    func testQuietMapSelectionChangesOnlyVisualEmphasis() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        let map = MapViewModel()
        map.show(stop: stops[3])
        XCTAssertEqual(map.markers(for: tour, emphasizesDestinationOnly: true).filter(\.isIllustrated).map(\.id), [stops[0].id], "Browsing a stop must not replace the walking destination illustration")
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
        map.clearViewedStop()
        XCTAssertEqual(map.markers(for: tour, emphasizesDestinationOnly: true).filter(\.isIllustrated).map(\.id), [stops[0].id])
        XCTAssertEqual(tour.progress.completedCount, 0)
    }

    func testHomeWelcomeFeaturesFirstStopWithoutStartingOrRequestingGPS() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        let source = tour.locationService as? ActivityTestLocationService
        XCTAssertEqual(tour.homeFeaturedStop?.id, stops[0].id)
        XCTAssertEqual(tour.homeWalkActionTitle, "Start walk")
        XCTAssertEqual(tour.phase, .notStarted)
        XCTAssertEqual(source?.permissionRequests, 0)
        XCTAssertEqual(source?.startRequests, 0)
        let navigation = AppNavigation()
        navigation.selectedTab = .map
        navigation.selectedTab = .stops
        navigation.selectedTab = .home
        XCTAssertEqual(tour.phase, .notStarted)
        XCTAssertEqual(source?.permissionRequests, 0)
    }

    func testHomeIllustrationFollowsWalkingDestinationAndPreviousRatherThanBrowsedStory() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        XCTAssertEqual(tour.homeWalkActionTitle, "Continue walk")
        XCTAssertEqual(tour.homeFeaturedStop?.id, stops[0].id)
        tour.completeCurrentStopAndAdvance()
        XCTAssertEqual(tour.homeFeaturedStop?.id, stops[1].id)
        tour.openStory(for: stops[4].id)
        XCTAssertEqual(tour.homeFeaturedStop?.id, stops[1].id)
        XCTAssertTrue(tour.goToPreviousStop())
        XCTAssertEqual(tour.homeFeaturedStop?.id, stops[0].id)
        XCTAssertEqual(tour.homeWalkActionTitle, "Continue walk")
    }

    func testHomeCompletionAndRestartKeepSavedLearningIndependent() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        tour.finishStory(for: stops[0].id)
        for _ in stops { tour.completeCurrentStopAndAdvance() }
        XCTAssertEqual(tour.phase, .complete)
        XCTAssertEqual(tour.homeWalkActionTitle, "Start another walk")
        XCTAssertEqual(tour.homeFeaturedStop?.id, stops[0].id)
        XCTAssertNil(tour.currentStop, "Completion must not invent another destination")
        tour.resetTour(); tour.startTour()
        XCTAssertEqual(tour.homeFeaturedStop?.id, stops[0].id)
        XCTAssertTrue(tour.activities[stops[0].id].learningCompleted)
    }

    func testAutomaticVisitWaitsThreeMinutesBeforeAdvancing() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour(); tour.isAutomaticNavigationVisible = true
        let start = Date().addingTimeInterval(-180)
        for seconds in 0...180 {
            let date = start.addingTimeInterval(Double(seconds))
            tour.evaluateAutomaticProgression(LocationSample(coordinate: stops[0].coordinate,
                horizontalAccuracy: 3, timestamp: date), now: date)
            if seconds < 180 {
                XCTAssertEqual(tour.currentStop?.id, stops[0].id)
                XCTAssertFalse(tour.isCurrentVisitConfirmed)
                XCTAssertNil(tour.activities[stops[0].id].visitedAt)
                XCTAssertEqual(tour.homeFeaturedStop?.id, stops[0].id)
            }
        }
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
        XCTAssertNotNil(tour.activities[stops[0].id].visitedAt)
    }

    func testNarrationCompletionBypassesDwellFromAnywhereWithoutInventingPhysicalVisit() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour(); tour.isAutomaticNavigationVisible = true
        XCTAssertNil(tour.userLocation)
        tour.finishListening(for: stops[0].id)
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
        XCTAssertNotNil(tour.activities[stops[0].id].listenedAt)
        XCTAssertNil(tour.activities[stops[0].id].visitedAt)
        tour.finishListening(for: stops[0].id)
        XCTAssertEqual(tour.currentStop?.id, stops[1].id, "A repeated callback cannot skip another destination")
        tour.stopWalk()
        tour.finishListening(for: stops[1].id)
        XCTAssertTrue(tour.isWalkPaused)
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
    }

    func testOnSiteNarrationCompletionAlsoRecordsThePhysicalVisit() async throws {
        let source = ActivityTestLocationService(status: .authorized)
        let tour = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: source, directionsService: PreviewDirectionsService())
        await tour.loadStopsIfNeeded(); defer { cleanUp(tour) }
        tour.startTour(); tour.isAutomaticNavigationVisible = true
        let sample = LocationSample(coordinate: stops[0].coordinate, horizontalAccuracy: 3)
        source.emit(sample)
        for _ in 0..<100 where tour.userLocation == nil { try await Task.sleep(for: .milliseconds(2)) }
        XCTAssertNotNil(tour.userLocation)
        XCTAssertNil(tour.activities[stops[0].id].visitedAt)
        tour.finishListening(for: stops[0].id)
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
        XCTAssertNotNil(tour.activities[stops[0].id].visitedAt)
        XCTAssertNil(tour.activities[stops[0].id].plaqueUnlockedAt)
    }

    func testRealPlaqueBypassesDwellAndRetainsSketchRevealAfterAdvancement() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour(); tour.isAutomaticNavigationVisible = true
        XCTAssertTrue(tour.preparePlaqueScanner(stopID: stops[0].id))
        XCTAssertEqual(tour.recognizeSketchPlaque(imageName: stops[0].plaque?.referenceImageName,
            isTracked: true, trackingReady: true), .allow(.recognizedPlaque))
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
        XCTAssertNotNil(tour.activities[stops[0].id].visitedAt)
        XCTAssertEqual(tour.pendingSketchStopID, stops[0].id)
    }

    func testEarlyDepartureRequiresMovementTowardNextStop() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour(); tour.isAutomaticNavigationVisible = true
        let start = Date().addingTimeInterval(-30)
        let bearing = GeoMath.bearing(from: stops[0].coordinate, to: stops[1].coordinate)
        let wrongWay = GeoMath.destination(from: stops[0].coordinate, bearing: bearing + 180, distance: 75)
        let towardNext = GeoMath.destination(from: stops[0].coordinate, bearing: bearing, distance: 75)
        for (time, point) in [(0.0, stops[0].coordinate), (3.0, stops[0].coordinate),
                              (4.0, wrongWay), (9.0, wrongWay), (10.0, towardNext), (14.0, towardNext)] {
            let date = start.addingTimeInterval(time)
            tour.evaluateAutomaticProgression(LocationSample(coordinate: point, horizontalAccuracy: 3, timestamp: date), now: date)
            XCTAssertEqual(tour.currentStop?.id, stops[0].id)
            XCTAssertNil(tour.activities[stops[0].id].visitedAt)
        }
        let date = start.addingTimeInterval(15)
        tour.evaluateAutomaticProgression(LocationSample(coordinate: towardNext, horizontalAccuracy: 3, timestamp: date), now: date)
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
        XCTAssertNotNil(tour.activities[stops[0].id].visitedAt)
    }

    func testHomePreviewsGreystoneAfterMillVisitWithoutChangingDestinationUntilTap() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.performHomeWalkAction()
        XCTAssertEqual(tour.homeFeaturedStop?.id, stops[0].id)
        confirmArrival(tour)
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
        XCTAssertEqual(tour.homeFeaturedStop?.name, "Greystone")
        XCTAssertEqual(tour.homeFeaturedStop?.id, stops[1].id)
        XCTAssertEqual(tour.homeWalkActionTitle, "Continue walk")
        tour.openStory(for: stops[4].id)
        XCTAssertEqual(tour.homeFeaturedStop?.id, stops[1].id, "Browsing cannot replace the next-leg preview")
        tour.performHomeWalkAction()
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
        XCTAssertEqual(tour.homeFeaturedStop?.id, stops[1].id)
        XCTAssertFalse(tour.isCurrentVisitConfirmed)
        XCTAssertNotNil(tour.activities[stops[0].id].visitedAt)
    }

    func testHomeArtworkDestinationFollowsEveryConfirmedVisit() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.performHomeWalkAction()
        for index in stops.indices {
            XCTAssertEqual(tour.homeFeaturedStop?.id, stops[index].id)
            confirmArrival(tour)
            let expected = stops[min(index + 1, stops.count - 1)].id
            XCTAssertEqual(tour.homeFeaturedStop?.id, expected,
                           "Artwork should preview the next stop immediately after logging the visit")
            XCTAssertEqual(tour.currentStop?.id, stops[index].id,
                           "Home preview alone must not change routing")
            if index + 1 < stops.count {
                tour.performHomeWalkAction()
                XCTAssertEqual(tour.currentStop?.id, expected)
            }
        }
    }

    func testHomeNextLegPreviewSurvivesPausedRelaunchAndContinueMatchesIllustration() async {
        let storage = InMemoryWalkResumeStore()
        func model() async -> TourViewModel {
            let tour = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
                locationService: ActivityTestLocationService(), directionsService: PreviewDirectionsService(),
                walkResumeStore: storage)
            await tour.loadStopsIfNeeded()
            return tour
        }
        let first = await model(); defer { cleanUp(first) }
        first.performHomeWalkAction(); confirmArrival(first)
        let resumed = await model(); defer { cleanUp(resumed) }
        XCTAssertTrue(resumed.isWalkPaused)
        XCTAssertEqual(resumed.currentStop?.id, stops[0].id)
        XCTAssertEqual(resumed.homeFeaturedStop?.id, stops[1].id)
        resumed.performHomeWalkAction()
        XCTAssertFalse(resumed.isWalkPaused)
        XCTAssertEqual(resumed.currentStop?.id, stops[1].id)
        XCTAssertEqual(storage.load()?.progress.currentStopID, stops[1].id)
    }

    func testHomeAtConfirmedFinalStopOffersFinishWithoutPreviewingAnotherStop() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.performHomeWalkAction()
        for _ in 0..<(stops.count - 1) { tour.completeCurrentStopAndAdvance() }
        confirmArrival(tour)
        XCTAssertEqual(tour.homeFeaturedStop?.id, stops.last?.id)
        XCTAssertEqual(tour.homeWalkActionTitle, "Finish walk")
        tour.performHomeWalkAction()
        XCTAssertEqual(tour.phase, .complete)
        XCTAssertEqual(tour.homeWalkActionTitle, "Start another walk")
        tour.performHomeWalkAction()
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
        XCTAssertEqual(tour.homeFeaturedStop?.id, stops[0].id)
    }

    func testWalkingFrameFocusesDestinationWithoutGPSAndKeepsDepartureAfterAdvance() async throws {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        let map = MapViewModel()
        map.showUserAndDestination(tour: tour)
        guard case .fitWalkingLeg(let first) = map.cameraRequest?.kind else { return XCTFail("Expected walking frame") }
        XCTAssertEqual(first, [stops[0].coordinate])
        XCTAssertEqual(map.cameraMode, .navigation)
        tour.completeCurrentStopAndAdvance()
        map.showUserAndDestination(tour: tour)
        guard case .fitWalkingLeg(let next) = map.cameraRequest?.kind else { return XCTFail("Expected next leg") }
        XCTAssertTrue(next.contains(stops[0].coordinate))
        XCTAssertTrue(next.contains(stops[1].coordinate))
        XCTAssertFalse(next.contains(stops[4].coordinate))
        XCTAssertNil(map.userPuck(for: tour), "Do not invent a user position without GPS")
        XCTAssertTrue(tour.goToPreviousStop())
        map.showUserAndDestination(tour: tour)
        guard case .fitWalkingLeg(let back) = map.cameraRequest?.kind else { return XCTFail("Expected return leg") }
        XCTAssertTrue(back.contains(stops[1].coordinate), "Backtracking retains the actual previous destination")
        XCTAssertTrue(back.contains(stops[0].coordinate))
    }

    func testWalkingFrameRestoresItineraryDepartureAndClearsItForNewWalk() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        tour.completeCurrentStopAndAdvance()
        let map = MapViewModel() // Map first appears mid-tour.
        map.showUserAndDestination(tour: tour)
        guard case .fitWalkingLeg(let points) = map.cameraRequest?.kind else { return XCTFail("Expected leg") }
        XCTAssertTrue(points.contains(stops[0].coordinate))
        tour.resetTour()
        tour.startTour()
        map.showUserAndDestination(tour: tour)
        guard case .fitWalkingLeg(let reset) = map.cameraRequest?.kind else { return XCTFail("Expected fresh leg") }
        XCTAssertEqual(reset, [stops[0].coordinate])
    }

    func testLateWalkingRouteFramesCurvesButNeverStealsManualCamera() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        let map = MapViewModel()
        map.showUserAndDestination(tour: tour)
        let before = map.cameraRequest?.id
        let origin = GeoCoordinate(latitude: 40.648, longitude: -74.304)
        let corner = GeoCoordinate(latitude: 40.647, longitude: -74.30)
        tour.currentRoute = WalkingRoute(origin: origin, destination: stops[0].coordinate,
            distanceMeters: 600, durationSeconds: 400, routeCoordinates: [origin, corner, stops[0].coordinate], source: .appleMaps)
        map.updateWalkingFrame(tour: tour, routeChanged: true)
        XCTAssertNotEqual(map.cameraRequest?.id, before)
        guard case .fitWalkingLeg(let points) = map.cameraRequest?.kind else { return XCTFail("Expected route bounds") }
        XCTAssertTrue(points.contains(corner), "Bounds must include the actual street geometry")
        map.userDidMoveCamera()
        let manuallyPositioned = map.cameraRequest
        map.updateWalkingFrame(tour: tour, routeChanged: true)
        XCTAssertEqual(map.cameraRequest, manuallyPositioned)
        map.showUserAndDestination(tour: tour)
        XCTAssertEqual(map.cameraMode, .navigation)
        XCTAssertNotEqual(map.cameraRequest, manuallyPositioned)
    }

    func testMapResizeRefitsActiveDestinationWithoutChangingTourOrArtwork() async throws {
        let tour = await makeTour(); defer { cleanUp(tour) }
        let map = MapViewModel()
        tour.startTour()
        map.showUserAndDestination(tour: tour)
        let initial = try XCTUnwrap(map.cameraRequest)
        let destinationID = tour.currentStop?.id
        let markers = map.markers(for: tour, emphasizesDestinationOnly: true)
        XCTAssertEqual(markers.filter(\.isIllustrated).map(\.id), [try XCTUnwrap(destinationID)])
        // Starting/stopping guidance changes available map height with no GPS movement.
        for _ in 0..<3 {
            let previous = try XCTUnwrap(map.cameraRequest)
            map.mapViewportDidChange()
            let resized = try XCTUnwrap(map.cameraRequest)
            XCTAssertGreaterThan(resized.id, previous.id)
            XCTAssertEqual(resized.kind, initial.kind)
            XCTAssertFalse(resized.animated, "Apply the fit to the new bounds without another camera animation")
            XCTAssertEqual(tour.currentStop?.id, destinationID)
            XCTAssertEqual(map.markers(for: tour, emphasizesDestinationOnly: true), markers)
        }
        map.userDidMoveCamera()
        let manualCamera = map.cameraRequest
        map.mapViewportDidChange()
        XCTAssertEqual(map.cameraRequest, manualCamera, "Resizing must respect a manual pan/zoom")
    }

    func testMapResizeRefitsOverviewAndIgnoresUninitializedCamera() async {
        let map = MapViewModel()
        map.mapViewportDidChange()
        XCTAssertNil(map.cameraRequest)
        map.requestOverview()
        let previous = map.cameraRequest
        map.mapViewportDidChange()
        XCTAssertNotEqual(map.cameraRequest?.id, previous?.id)
        XCTAssertEqual(map.cameraRequest?.kind, .fitAll)
        XCTAssertEqual(map.cameraRequest?.animated, false)
    }

    func testDenseGPSAdvancesFirstStopAndScreenHoldReleases() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        tour.isAutomaticNavigationVisible = true
        let hold = UUID()
        tour.explorationHolds.insert(hold)
        confirmArrival(tour)
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
        XCTAssertTrue(tour.isCurrentVisitConfirmed)
        tour.explorationHolds.remove(hold)
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
    }

    func testSparseGPSCannotCompleteThreeMinuteVisit() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        tour.isAutomaticNavigationVisible = true
        let point = stops[0].coordinate
        let originTime = Date().addingTimeInterval(-250)
        for sec in [0, 3] + Array(stride(from: 18, through: 243, by: 15)) {
            let time = originTime.addingTimeInterval(Double(sec))
            tour.evaluateAutomaticProgression(.init(coordinate: point, horizontalAccuracy: 3, timestamp: time), now: time)
        }
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
        XCTAssertTrue(tour.walkingProgression.hasArrived)
        XCTAssertLessThan(tour.walkingProgression.accumulatedVisitSeconds, 10)
    }

    func testEachAutomaticProgressionHoldReleasesExactlyOnce() async {
        for gate in ["map", "exploration", "ar", "departure"] {
            let tour = await makeTour(); defer { cleanUp(tour) }
            tour.startTour()
            tour.isAutomaticNavigationVisible = gate != "map"
            let token = UUID()
            if gate == "exploration" { tour.explorationHolds.insert(token) }
            if gate == "ar" { tour.isARSessionActive = true }
            if gate == "departure" { tour.heldDepartureStopID = stops[0].id; tour.walkingProgression.isHeld = true }
            confirmArrival(tour)
            XCTAssertEqual(tour.currentStop?.id, stops[0].id, "Hold: \(gate)")
            XCTAssertTrue(tour.isCurrentVisitConfirmed)
            if gate == "map" { tour.isAutomaticNavigationVisible = true }
            if gate == "exploration" { tour.explorationHolds.remove(token) }
            if gate == "ar" { tour.isARSessionActive = false }
            if gate == "departure" {
                tour.heldDepartureStopID = nil; tour.walkingProgression.isHeld = false
                tour.advanceAfterLoggedVisitIfAllowed()
            }
            XCTAssertEqual(tour.currentStop?.id, stops[1].id)
            tour.advanceAfterLoggedVisitIfAllowed()
            XCTAssertEqual(tour.currentStop?.id, stops[1].id, "The same visit must not cascade")
            tour.undoAutomaticTransition()
            tour.advanceAfterLoggedVisitIfAllowed()
            XCTAssertEqual(tour.currentStop?.id, stops[0].id, "Undo holds against immediate re-advancement")
        }
    }

    func testMapNumberHighlightFollowsOnlyTheActiveWalkingDestination() async throws {
        let tour = await makeTour(); defer { cleanUp(tour) }
        let map = MapViewModel()
        func highlightedIDs() -> [String] {
            map.markers(for: tour, emphasizesDestinationOnly: true).filter(\.isWalkingDestination).map(\.id)
        }
        XCTAssertTrue(highlightedIDs().isEmpty, "Browsing must not highlight a walking destination")
        tour.startTour()
        XCTAssertEqual(highlightedIDs(), [stops[0].id])
        let active = try XCTUnwrap(map.markers(for: tour).first)
        tour.stopWalk()
        XCTAssertTrue(highlightedIDs().isEmpty)
        let paused = try XCTUnwrap(map.markers(for: tour).first)
        XCTAssertEqual(active.state, paused.state)
        XCTAssertNotEqual(active, paused, "Renderers must invalidate their cached artwork on stop/resume")
        tour.startTour()
        map.select(stopID: stops[2].id)
        XCTAssertEqual(highlightedIDs(), [stops[0].id], "Inspecting a different stop must not move the destination color")
        tour.progress.markCurrentStopVisited()
        XCTAssertEqual(highlightedIDs(), [stops[0].id], "A prior visit cannot override the active destination")
        tour.completeCurrentStopAndAdvance()
        XCTAssertEqual(highlightedIDs(), [stops[1].id])
        tour.stopWalk()
        XCTAssertTrue(highlightedIDs().isEmpty)
    }

    func testMapPrimaryActionStartsStopsAndContinuesTheSameWalk() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        XCTAssertEqual(tour.phase, .notStarted)
        tour.performMapWalkAction()
        XCTAssertTrue(tour.isWalkingActive)
        tour.completeCurrentStopAndAdvance()
        tour.finishStory(for: stops[0].id)
        let destination = tour.currentStop?.id
        let session = tour.walkSessionID
        let progress = tour.progress
        let activities = tour.activities
        for _ in 0..<2 {
            tour.performMapWalkAction()
            XCTAssertTrue(tour.isWalkPaused)
            XCTAssertNil(tour.currentRoute)
            XCTAssertTrue(MapViewModel().walkingRouteCoordinates(for: tour).isEmpty)
            tour.performMapWalkAction()
            XCTAssertTrue(tour.isWalkingActive)
            XCTAssertEqual(tour.currentStop?.id, destination)
            XCTAssertEqual(tour.walkSessionID, session)
            XCTAssertEqual(tour.progress, progress)
            XCTAssertEqual(tour.activities, activities)
        }
    }

    func testMapContinueAfterConfirmedPausedVisitStartsExactlyOneNextLeg() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.performMapWalkAction()
        confirmArrival(tour)
        XCTAssertTrue(tour.isCurrentVisitConfirmed)
        tour.performMapWalkAction()
        XCTAssertTrue(tour.isWalkPaused)
        tour.isAutomaticNavigationVisible = true
        tour.performMapWalkAction()
        XCTAssertTrue(tour.isWalkingActive)
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
        XCTAssertFalse(tour.isCurrentVisitConfirmed)
        XCTAssertNotNil(tour.activities[stops[0].id].visitedAt)
    }

    func testStopWalkClearsGuidanceAndResumesWithoutLosingProgress() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        tour.completeCurrentStopAndAdvance()
        let destination = tour.currentStop?.id
        let session = tour.walkSessionID
        let progress = tour.progress
        let activities = tour.activities
        let trail = tour.walkedTrailSegments
        var route = WalkingRoute.straightLineEstimate(from: stops[0].coordinate, to: stops[1].coordinate)
        route.source = .googleRoutesAPI
        tour.currentRoute = route
        let map = MapViewModel()
        XCTAssertFalse(map.walkingRouteCoordinates(for: tour).isEmpty)

        tour.stopWalk()
        XCTAssertTrue(tour.isWalkPaused)
        XCTAssertFalse(tour.isWalkingActive)
        XCTAssertNil(tour.currentRoute)
        XCTAssertNil(tour.routeProgress)
        XCTAssertFalse(tour.isRoutingInFlight)
        XCTAssertTrue(map.walkingRouteCoordinates(for: tour).isEmpty)
        // Even cached/late geometry cannot reappear while guidance is stopped.
        tour.currentRoute = route
        XCTAssertTrue(map.walkingRouteCoordinates(for: tour).isEmpty)
        tour.currentRoute = nil
        tour.stopWalk() // Repeated taps are harmless.
        XCTAssertEqual(tour.progress, progress)
        XCTAssertEqual(tour.activities, activities)
        XCTAssertEqual(tour.walkedTrailSegments, trail)
        XCTAssertEqual(tour.currentStop?.id, destination)
        XCTAssertEqual(tour.walkSessionID, session)

        tour.startTour()
        XCTAssertTrue(tour.isWalkingActive)
        XCTAssertEqual(tour.currentStop?.id, destination)
        XCTAssertEqual(tour.walkSessionID, session)
    }

    func testWalkingPolylineRejectsEstimatesAndOldDestinationRoutes() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        let map = MapViewModel()
        let origin = stops[0].coordinate
        tour.currentRoute = .straightLineEstimate(from: origin, to: origin)
        XCTAssertTrue(map.walkingRouteCoordinates(for: tour).isEmpty)
        var route = WalkingRoute.straightLineEstimate(from: origin, to: origin)
        route.source = .googleRoutesAPI
        tour.currentRoute = route
        XCTAssertEqual(map.walkingRouteCoordinates(for: tour).count, 2)
        tour.completeCurrentStopAndAdvance()
        tour.currentRoute = route // A stale provider completion must not draw the old leg.
        XCTAssertTrue(map.walkingRouteCoordinates(for: tour).isEmpty)
        route.destination = stops[1].coordinate
        route.routeCoordinates = [origin, GeoCoordinate(latitude: .nan, longitude: 0)]
        tour.currentRoute = route
        XCTAssertTrue(map.walkingRouteCoordinates(for: tour).isEmpty)
    }

    func testFutureRouteHidesWhenStoppedWithoutErasingRecordedTrail() async {
        let source = ActivityTestLocationService(status: .authorized)
        let tour = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: source, directionsService: PreviewDirectionsService())
        await tour.loadStopsIfNeeded(); defer { cleanUp(tour) }
        tour.startTour()
        let destination = stops[0].coordinate
        let origin = GeoCoordinate(latitude: destination.latitude - 0.001, longitude: destination.longitude)
        let now = Date()
        for (i, latitude) in [origin.latitude, origin.latitude + 0.00003].enumerated() {
            let time = now.addingTimeInterval(Double(i * 2))
            tour.recordWalkedTrail(LocationSample(coordinate: .init(latitude: latitude, longitude: origin.longitude),
                horizontalAccuracy: 3, timestamp: time), now: time)
        }
        var providerRoute = WalkingRoute.straightLineEstimate(from: origin, to: destination)
        providerRoute.source = .googleRoutesAPI
        tour.currentRoute = providerRoute
        let map = MapViewModel()
        let savedTrail = map.walkedTrailCoordinates(for: tour)
        XCTAssertFalse(savedTrail.isEmpty)
        XCTAssertEqual(map.walkingRouteCoordinates(for: tour), providerRoute.routeCoordinates)
        tour.stopWalk()
        tour.currentRoute = providerRoute // Even a late provider result must not redraw paused guidance.
        XCTAssertTrue(map.walkingRouteCoordinates(for: tour).isEmpty)
        XCTAssertEqual(map.walkedTrailCoordinates(for: tour), savedTrail)
        tour.startTour()
        tour.currentRoute = providerRoute
        XCTAssertEqual(map.walkingRouteCoordinates(for: tour), providerRoute.routeCoordinates)
        XCTAssertEqual(map.walkedTrailCoordinates(for: tour), savedTrail)
    }

    func testWalkingLineShortensAlongProviderRouteAsProgressMovesForward() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        let end = stops[0].coordinate
        let origin = GeoCoordinate(latitude: end.latitude - 0.002, longitude: end.longitude)
        let middle = GeoCoordinate(latitude: end.latitude - 0.001, longitude: end.longitude)
        var route = WalkingRoute.straightLineEstimate(from: origin, to: end)
        route.source = .googleRoutesAPI
        route.routeCoordinates = [origin, middle, end]
        tour.currentRoute = route
        let map = MapViewModel()
        let firstGPS = GeoCoordinate(latitude: end.latitude - 0.0015, longitude: end.longitude + 0.00002)
        tour.routeProgress = RouteProgressCalculator.progress(along: route, userLocation: firstGPS)
        let first = map.walkingRouteCoordinates(for: tour)
        XCTAssertEqual(first.count, 3)
        XCTAssertEqual(first.first?.longitude, end.longitude, "Line stays on the route; no fake GPS connector")
        XCTAssertEqual(first.last, end)
        let laterGPS = GeoCoordinate(latitude: end.latitude - 0.0005, longitude: end.longitude)
        tour.routeProgress = RouteProgressCalculator.progress(along: route, userLocation: laterGPS)
        let later = map.walkingRouteCoordinates(for: tour)
        XCTAssertEqual(later.count, 2)
        XCTAssertEqual(later.first?.latitude ?? 0, laterGPS.latitude, accuracy: 0.000001)
        XCTAssertEqual(later.last, end)
        XCTAssertEqual(tour.currentRoute?.routeCoordinates, [origin, middle, end], "Trimming never mutates the provider route")
        tour.routeProgress = RouteProgressCalculator.progress(along: route, userLocation: end)
        XCTAssertTrue(map.walkingRouteCoordinates(for: tour).isEmpty)
    }

    func testWalkedTrailRemainsAcrossLegChangesAndClearsOnlyForNewWalk() async {
        let source = ActivityTestLocationService(status: .authorized)
        let tour = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: source, directionsService: PreviewDirectionsService())
        await tour.loadStopsIfNeeded(); defer { cleanUp(tour) }
        tour.startTour()
        let now = Date()
        func fix(_ latitude: Double, _ seconds: Double) {
            tour.recordWalkedTrail(LocationSample(coordinate: GeoCoordinate(latitude: latitude, longitude: -74.32),
                horizontalAccuracy: 3, timestamp: now.addingTimeInterval(seconds)), now: now.addingTimeInterval(seconds))
        }
        fix(40.67, 0); fix(40.67003, 2); fix(40.67006, 4)
        let map = MapViewModel()
        XCTAssertEqual(map.walkedTrailCoordinates(for: tour).first?.count, 3)
        let firstLeg = tour.walkedTrailSegments
        tour.completeCurrentStopAndAdvance()
        XCTAssertEqual(tour.walkedTrailSegments, firstLeg)
        fix(40.67009, 6)
        XCTAssertEqual(map.walkedTrailCoordinates(for: tour).first?.count, 4)
        tour.resetTour(startImmediately: false)
        XCTAssertTrue(tour.walkedTrailSegments.isEmpty)
    }

    func testWalkedTrailBreaksAtSignalLossAndJumpsAndIgnoresPractice() async {
        let source = ActivityTestLocationService(status: .authorized)
        let tour = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: source, directionsService: PreviewDirectionsService())
        await tour.loadStopsIfNeeded(); defer { cleanUp(tour) }
        tour.startTour()
        let now = Date()
        func fix(_ latitude: Double, _ seconds: Double, accuracy: Double = 3, simulated: Bool = false) {
            tour.recordWalkedTrail(LocationSample(coordinate: GeoCoordinate(latitude: latitude, longitude: -74.32),
                horizontalAccuracy: accuracy, timestamp: now.addingTimeInterval(seconds), isSimulated: simulated),
                now: now.addingTimeInterval(seconds))
        }
        fix(40.67, 0); fix(40.67003, 2)
        fix(40.67006, 3, accuracy: 100)
        fix(40.67009, 4); fix(40.67012, 6)
        fix(40.68, 7); fix(40.68003, 9)
        XCTAssertEqual(tour.walkedTrailSegments.map(\.count), [2, 2, 2], "No invented connectors across lost signal or a GPS jump")
        let saved = tour.walkedTrailSegments
        fix(40.68006, 11, simulated: true)
        XCTAssertEqual(tour.walkedTrailSegments, saved)
        tour.stopLocation()
        tour.recordWalkedTrail(LocationSample(coordinate: .init(latitude: 40.68009, longitude: -74.32),
            timestamp: now.addingTimeInterval(-60)), now: now)
        XCTAssertEqual(tour.walkedTrailSegments, saved)
    }

    func testGPSDotMovesOffRouteWithoutSnappingAndCameraIgnoresSmallJitter() async throws {
        let source = ActivityTestLocationService(status: .authorized)
        let tour = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: source, directionsService: PreviewDirectionsService())
        await tour.loadStopsIfNeeded(); tour.startTour()
        defer { cleanUp(tour) }
        let map = MapViewModel()
        // Far from all stops: this test must not trigger an arrival.
        let origin = GeoCoordinate(latitude: 40.67, longitude: -74.32)
        let initial = LocationSample(coordinate: origin, horizontalAccuracy: 3)
        source.emit(initial)
        for _ in 0..<100 where tour.userLocation == nil { try await Task.sleep(for: .milliseconds(2)) }
        map.showUserAndDestination(tour: tour)
        let camera = map.cameraRequest
        let small = LocationSample(coordinate: GeoCoordinate(latitude: origin.latitude + 0.00002, longitude: origin.longitude), horizontalAccuracy: 3)
        source.emit(small)
        for _ in 0..<100 where tour.userLocation?.timestamp != small.timestamp { try await Task.sleep(for: .milliseconds(2)) }
        map.updateWalkingFrame(tour: tour)
        XCTAssertEqual(map.cameraRequest, camera)
        XCTAssertEqual(map.userPuck(for: tour)?.coordinate.latitude, small.coordinate.latitude)
        let moved = LocationSample(coordinate: GeoCoordinate(latitude: origin.latitude + 0.0003, longitude: origin.longitude + 0.0003), horizontalAccuracy: 5)
        source.emit(moved)
        for _ in 0..<100 where tour.userLocation?.timestamp != moved.timestamp { try await Task.sleep(for: .milliseconds(2)) }
        map.updateWalkingFrame(tour: tour)
        XCTAssertNotEqual(map.cameraRequest, camera)
        XCTAssertEqual(map.userPuck(for: tour)?.coordinate.longitude, moved.coordinate.longitude)
        XCTAssertEqual(map.userPuck(for: tour)?.accuracyMeters, 5)
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
        XCTAssertEqual(tour.progress.completedCount, 0)
    }

    func testMapGPSUpdatesSmallMovementsBeforeStartAndDuringPausedWalk() async throws {
        for hasStarted in [false, true] {
            let walks = InMemoryWalkResumeStore()
            if hasStarted {
                let first = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
                    locationService: ActivityTestLocationService(), directionsService: PreviewDirectionsService(),
                    walkResumeStore: walks)
                await first.loadStopsIfNeeded()
                first.startTour(); first.completeCurrentStopAndAdvance()
                cleanUp(first)
            }
            let source = ActivityTestLocationService(status: .authorized)
            let tour = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
                locationService: source, directionsService: PreviewDirectionsService(), walkResumeStore: walks)
            await tour.loadStopsIfNeeded(); defer { cleanUp(tour) }
            let phase = tour.phase, destination = tour.currentStop?.id
            let map = MapViewModel()
            XCTAssertNil(map.userPuck(for: tour), "Never invent a dot before GPS arrives")
            tour.startLocationIfPossible() // Map entry does not call startTour.
            XCTAssertGreaterThan(source.startRequests, 0)
            map.userDidMoveCamera()
            let camera = map.cameraRequest
            let time = Date()
            for step in 0..<4 {
                let sample = LocationSample(coordinate: GeoCoordinate(latitude: 40.67 + Double(step) * 0.000003,
                    longitude: -74.32), horizontalAccuracy: 4, timestamp: time.addingTimeInterval(Double(step) * 0.01))
                source.emit(sample)
                for _ in 0..<100 where tour.userLocation?.timestamp != sample.timestamp {
                    try await Task.sleep(for: .milliseconds(2))
                }
                map.updateWalkingFrame(tour: tour)
                XCTAssertEqual(map.userPuck(for: tour)?.coordinate.latitude, sample.coordinate.latitude)
                XCTAssertEqual(map.userPuck(for: tour)?.accuracyMeters, 4)
                XCTAssertEqual(map.cameraRequest, camera, "Panning does not freeze the dot or move the camera")
            }
            XCTAssertEqual(tour.phase, phase)
            XCTAssertEqual(tour.currentStop?.id, destination)
            XCTAssertEqual(tour.isWalkPaused, hasStarted)
            XCTAssertFalse(tour.isWalkingActive)
        }
    }

    func testMapLocationRecoveryOnlyRefreshesStalledAuthorizedStream() async throws {
        let source = ActivityTestLocationService(status: .authorized)
        let tour = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: source, directionsService: PreviewDirectionsService())
        await tour.loadStopsIfNeeded(); defer { cleanUp(tour) }
        let now = Date()
        tour.refreshMapLocationIfNeeded(now: now)
        XCTAssertEqual(source.refreshRequests, 0, "No recovery before Map subscribes")
        tour.startLocationIfPossible()
        tour.refreshMapLocationIfNeeded(now: now)
        XCTAssertEqual(source.refreshRequests, 0, "Allow the first continuous fix to arrive")
        let sample = LocationSample(coordinate: GeoCoordinate(latitude: 40.67, longitude: -74.32), timestamp: now)
        source.emit(sample)
        for _ in 0..<100 where tour.userLocation == nil { try await Task.sleep(for: .milliseconds(2)) }
        tour.refreshMapLocationIfNeeded(now: now.addingTimeInterval(5))
        XCTAssertEqual(source.refreshRequests, 0, "Healthy continuous GPS is not interrupted")
        tour.refreshMapLocationIfNeeded(now: now.addingTimeInterval(20))
        XCTAssertEqual(source.refreshRequests, 1)
        tour.refreshMapLocationIfNeeded(now: now.addingTimeInterval(25))
        XCTAssertEqual(source.refreshRequests, 1, "Throttle recovery while awaiting a fix")
        tour.stopLocation()
        tour.refreshMapLocationIfNeeded(now: now.addingTimeInterval(50))
        XCTAssertEqual(source.refreshRequests, 1, "A stopped stream must not restart itself")
        XCTAssertEqual(tour.homeWalkActionTitle, "Start walk")
    }

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
        tour.activities.collectSketch(at: stops[1].id)
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
    func testDeveloperHistoryResetRequiresStartThenResumesDestinationAcrossRelaunch() async {
        for includingStoriesAndSketches in [false, true] {
            let walks = InMemoryWalkResumeStore()
            let activities = InMemoryStopActivityStore()
            let visits = InMemoryStopVisitStore()
            func makeModel() async -> TourViewModel {
                let model = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
                    locationService: ActivityTestLocationService(), directionsService: PreviewDirectionsService(),
                    visitStore: visits, activityStore: activities, walkResumeStore: walks)
                await model.loadStopsIfNeeded()
                return model
            }
            let tour = await makeModel(); defer { cleanUp(tour) }
            tour.startTour()
            tour.completeCurrentStopAndAdvance()
            XCTAssertNotNil(walks.load())
            tour.clearRecordedActivitiesAndRestart(includingStoriesAndSketches: includingStoriesAndSketches)
            XCTAssertEqual(tour.phase, .notStarted)
            XCTAssertEqual(tour.homeWalkActionTitle, "Start walk")
            XCTAssertNil(tour.currentStop, "An unstarted walk has no active destination")
            XCTAssertEqual(tour.homeFeaturedStop?.id, stops[0].id)
            XCTAssertFalse(tour.isWalkingActive)
            XCTAssertNil(walks.load(), "Reset must remove the old resume checkpoint")
            tour.checkpointWalk()

            let fresh = await makeModel(); defer { cleanUp(fresh) }
            XCTAssertEqual(fresh.homeWalkActionTitle, "Start walk", "Relaunch after reset stays unstarted")
            fresh.startTour()
            XCTAssertEqual(fresh.homeWalkActionTitle, "Continue walk")
            XCTAssertEqual(fresh.currentStop?.id, stops[0].id)
            fresh.completeCurrentStopAndAdvance()
            let destination = fresh.currentStop?.id
            XCTAssertEqual(destination, stops[1].id)

            let resumed = await makeModel(); defer { cleanUp(resumed) }
            XCTAssertEqual(resumed.homeWalkActionTitle, "Continue walk")
            XCTAssertTrue(resumed.isWalkPaused)
            XCTAssertEqual(resumed.currentStop?.id, destination)
            resumed.startTour()
            XCTAssertFalse(resumed.isWalkPaused)
            XCTAssertEqual(resumed.currentStop?.id, destination, "Resume must not restart at Stop 1")
            let developer = DeveloperModeController(tour: resumed, realLocationService: resumed.locationService)
            developer.resetTour()
            XCTAssertEqual(resumed.homeWalkActionTitle, "Start walk")
            XCTAssertFalse(resumed.isWalkingActive)
            XCTAssertNil(walks.load(), "Plain developer Reset tour also clears the resume checkpoint")
        }
    }

    func testVisitOnlyResetKeepsStoriesAndBonusesSeparate() async {
        let visits = InMemoryStopVisitStore()
        let activities = InMemoryStopActivityStore()
        visits.record(StopVisitRecord(stopID: stops[1].id, activatedAt: Date(), evidence: .recognizedPlaque))
        let tour = await makeTour(visitStore: visits, activityStore: activities); defer { cleanUp(tour) }
        tour.finishListening(for: stops[1].id)
        tour.finishStory(for: stops[1].id)
        tour.startTour()
        tour.completeCurrentStopAndAdvance()
        tour.clearRecordedActivitiesAndRestart(includingStoriesAndSketches: false)
        XCTAssertTrue(visits.records().isEmpty)
        XCTAssertNil(tour.activities[stops[1].id].visitedAt)
        XCTAssertNotNil(tour.activities[stops[1].id].listenedAt)
        XCTAssertNotNil(tour.activities[stops[1].id].readAt)
        XCTAssertNotNil(tour.activities[stops[1].id].plaqueUnlockedAt)
        XCTAssertNil(tour.currentStop, "An unstarted walk has no active destination")
        XCTAssertEqual(tour.homeFeaturedStop?.id, stops[0].id)
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
        XCTAssertNotNil(tour.activities[stops[1].id].plaqueUnlockedAt)
        tour.clearRecordedActivitiesAndRestart(includingStoriesAndSketches: true)
        XCTAssertTrue(visits.records().isEmpty)
        XCTAssertTrue(tour.visitRecords.isEmpty)
        for stop in stops { XCTAssertEqual(tour.activities[stop.id], StopActivities()) }
        XCTAssertEqual(tour.progress.completedCount, 0)
        XCTAssertNil(tour.currentStop, "An unstarted walk has no active destination")
        XCTAssertEqual(tour.homeFeaturedStop?.id, stops[0].id)
        XCTAssertTrue(tour.discoveriesByStopID[stops[1].id] == nil)
        let reloaded = await makeTour(visitStore: visits, activityStore: activities); defer { cleanUp(reloaded) }
        for stop in stops { XCTAssertEqual(reloaded.activities[stop.id], StopActivities()) }
        XCTAssertEqual(reloaded.walkActionTitle, reloaded.startWalkTitle)
    }
    #endif

    func testRecognizedPlaqueOffersNextLegWithoutWaitingForGPSArrival() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        XCTAssertFalse(tour.isCurrentVisitConfirmed)
        tour.startTour()
        tour.startNextLegAfterConfirmedVisit()
        XCTAssertEqual(tour.currentStop?.id, stops[0].id, "The arrival CTA cannot skip an unconfirmed stop")
        XCTAssertTrue(tour.preparePlaqueScanner(stopID: stops[0].id))
        tour.confirmPlaqueArrival(for: stops[0].id)
        XCTAssertEqual(tour.activateCurrentStop(stopID: stops[0].id, trackingReady: true, plaqueIsTracked: true), .allow(.recognizedPlaque))
        XCTAssertFalse(tour.walkingProgression.hasArrived)
        XCTAssertTrue(tour.isCurrentVisitConfirmed, "Recognition must enable the next-leg CTA without GPS dwell")
        XCTAssertEqual(tour.nextStop?.name, "Greystone")
        tour.endARDiscoverySession()
        tour.startNextLegAfterConfirmedVisit()
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
        XCTAssertNotNil(tour.activities[stops[0].id].plaqueUnlockedAt)
    }

    func testConfirmedVisitNextLegButtonResumesPausedWalkAtNextDestination() async {
        let walks = InMemoryWalkResumeStore()
        let first = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: ActivityTestLocationService(), directionsService: PreviewDirectionsService(), walkResumeStore: walks)
        await first.loadStopsIfNeeded(); defer { cleanUp(first) }
        first.startTour(); confirmArrival(first)
        let restored = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: ActivityTestLocationService(), directionsService: PreviewDirectionsService(), walkResumeStore: walks)
        await restored.loadStopsIfNeeded(); defer { cleanUp(restored) }
        XCTAssertTrue(restored.isWalkPaused)
        XCTAssertTrue(restored.isCurrentVisitConfirmed)
        XCTAssertEqual(restored.nextStop?.name, "Greystone")
        restored.isAutomaticNavigationVisible = true
        restored.startNextLegAfterConfirmedVisit()
        XCTAssertFalse(restored.isWalkPaused)
        XCTAssertEqual(restored.currentStop?.id, stops[1].id)
        XCTAssertEqual(walks.load()?.progress.currentStopID, stops[1].id)
    }

    func testLoggedVisitAutomaticallySelectsNextLegAndPreservesIndependentActivity() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.finishListening(for: stops[0].id)
        tour.startTour(); tour.isAutomaticNavigationVisible = true
        tour.activities.collectSketch(at: stops[0].id)
        confirmArrival(tour)
        XCTAssertFalse(tour.isCurrentVisitConfirmed)
        XCTAssertEqual(tour.currentStop?.name, "Greystone")
        let map = MapViewModel()
        let markers = map.markers(for: tour, emphasizesDestinationOnly: true)
        XCTAssertEqual(markers.filter(\.isIllustrated).map(\.id), [stops[1].id])
        XCTAssertFalse(markers.first { $0.id == stops[0].id }?.isIllustrated ?? true)
        XCTAssertEqual(markers.first { $0.id == stops[0].id }?.state, .visited)
        let now = Date()
        let away = GeoCoordinate(latitude: stops[0].latitude + 0.002, longitude: stops[0].longitude)
        for age in [0.0, 5, 10] {
            let fix = LocationSample(coordinate: away, horizontalAccuracy: 3, timestamp: now.addingTimeInterval(age))
            tour.evaluateAutomaticProgression(fix, now: fix.timestamp)
        }
        XCTAssertEqual(tour.currentStop?.id, stops[1].id, "Repeated fixes must not advance an unvisited next stop")
        XCTAssertEqual(tour.automaticTransitionFromStopID, stops[0].id)
        tour.startNextLegAfterConfirmedVisit()
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
        XCTAssertFalse(tour.isCurrentVisitConfirmed)
        XCTAssertTrue(tour.activities[stops[0].id].learningCompleted)
        XCTAssertNotNil(tour.activities[stops[0].id].visitedAt)
        XCTAssertNotNil(tour.activities[stops[0].id].plaqueUnlockedAt)
        XCTAssertFalse(tour.activities[stops[1].id].learningCompleted)
        tour.startNextLegAfterConfirmedVisit()
        XCTAssertEqual(tour.currentStop?.id, stops[1].id, "A repeated tap cannot skip an unvisited stop")
    }

    func testLoggedVisitAdvancesOnlyAfterReturningFromExplorationARAndBackground() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour(); tour.isAutomaticNavigationVisible = true
        let first = UUID(), nested = UUID()
        tour.explorationHolds = [first, nested]
        confirmArrival(tour)
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
        tour.isARSessionActive = true
        tour.explorationHolds.remove(first)
        fix(15); fix(20)
        tour.isAutomaticNavigationVisible = false
        tour.isARSessionActive = false
        fix(25); fix(30)
        tour.isAutomaticNavigationVisible = true
        fix(35)
        XCTAssertEqual(tour.currentStop?.id, stops[1].id, "Returning to Map applies the already-logged visit without another fix")
        fix(40)
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
        tour.startNextLegAfterConfirmedVisit()
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
    }

    func testStableFinalArrivalOffersExplicitFinishWithoutInventingSkippedVisits() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        for _ in 0..<(stops.count - 1) { tour.completeCurrentStopAndAdvance() }
        tour.isAutomaticNavigationVisible = true
        confirmArrival(tour)
        XCTAssertEqual(tour.phase, .inProgress)
        XCTAssertTrue(tour.isCurrentVisitConfirmed)
        XCTAssertNil(tour.nextStop)
        tour.startNextLegAfterConfirmedVisit()
        XCTAssertEqual(tour.phase, .complete)
        XCTAssertEqual(tour.completionFigures.visitedCount, 1)
        XCTAssertFalse(tour.isCompleted(stops[0]))
        XCTAssertTrue(tour.isCompleted(stops.last!))
    }

    func testFinalArrivalWhileReadingWaitsForFinishTapAfterReturningToMap() async {
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
        XCTAssertEqual(tour.phase, .inProgress, "Fresh GPS still cannot finish without a tap")
        tour.startNextLegAfterConfirmedVisit()
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

    func testLegacyDepartureHoldSurvivesRelaunchAndFinishRequiresTap() async {
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
        XCTAssertEqual(resumed.phase, .inProgress)
        resumed.startNextLegAfterConfirmedVisit()
        XCTAssertEqual(resumed.phase, .complete)
    }

    func testLocationPipelineLogsMillAndAutomaticallyRoutesToGreystone() async throws {
        let source = ActivityTestLocationService(status: .authorized)
        let tour = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: source, directionsService: WalkingProviderStub(source: .googleRoutesAPI))
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
        XCTAssertFalse(tour.isCurrentVisitConfirmed)
        XCTAssertEqual(tour.homeFeaturedStop?.name, "Greystone")
        tour.startNextLegAfterConfirmedVisit()
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
        XCTAssertTrue(tour.progress.isCompleted(stops[0].id))
        XCTAssertFalse(tour.progress.isCompleted(stops[1].id))
        XCTAssertEqual(tour.automaticTransitionFromStopID, stops[0].id)
        for _ in 0..<100 where tour.currentRoute?.destination != stops[1].coordinate {
            try await Task.sleep(for: .milliseconds(2))
        }
        XCTAssertEqual(tour.currentRoute?.destination, stops[1].coordinate)
        XCTAssertGreaterThan(tour.remainingDistanceMeters ?? 0, 0)
        XCTAssertGreaterThan(tour.remainingSeconds ?? 0, 0)
        XCTAssertEqual(MapViewModel().walkingRouteCoordinates(for: tour).last, stops[1].coordinate)
    }

    func testRecognizedPlaqueAdvancesOnceFromLoggedVisitWithoutRequiringGeocodeDeparture() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour(); tour.isAutomaticNavigationVisible = true
        tour.isARSessionActive = true
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
        XCTAssertEqual(tour.currentStop?.id, stops[1].id, "Physical recognition logs the visit; geocode departure is not required")
        XCTAssertFalse(tour.walkingProgression.hasArrived)
        tour.advanceAfterLoggedVisitIfAllowed()
        XCTAssertEqual(tour.currentStop?.id, stops[1].id, "No second advancement without another logged visit")
    }

    func testPreviousStopUsesTourOrderAndPreservesAllRecordedProgress() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        tour.progress.markCurrentStopVisited()
        tour.finishListening(for: stops[0].id)
        tour.activities.collectSketch(at: stops[1].id)
        for _ in 0..<3 { tour.completeCurrentStopAndAdvance() }
        tour.progress.markCurrentStopVisited()
        tour.progress.recordWalked(meters: 123)
        let activities = tour.activities
        let visited = tour.progress.completedStopIDs
        let started = tour.progress.startedAt
        XCTAssertEqual(tour.previousStop?.id, stops[2].id, "Previous includes skipped places")
        XCTAssertTrue(tour.goToPreviousStop())
        XCTAssertEqual(tour.currentStop?.id, stops[2].id)
        XCTAssertEqual(tour.nextStop?.id, stops[3].id)
        XCTAssertEqual(tour.progress.completedStopIDs, visited)
        XCTAssertEqual(tour.activities, activities)
        XCTAssertEqual(tour.progress.walkedMeters, 123)
        XCTAssertEqual(tour.progress.startedAt, started)
        XCTAssertFalse(tour.progress.isCurrentStopVisited, "Backtracking must not credit a skipped visit")
        XCTAssertTrue(tour.walkingProgression.isHeld)
        XCTAssertEqual(tour.heldDepartureStopID, stops[2].id)
        XCTAssertFalse(tour.walkingProgression.hasArrived, "Selecting a destination is not live arrival")
    }

    func testPreviousStopIsUnavailableAtFirstStopBeforeStartAndAfterCompletion() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        let unopened = tour.progress
        XCTAssertNil(tour.previousStop)
        XCTAssertFalse(tour.goToPreviousStop())
        XCTAssertEqual(tour.progress, unopened)
        tour.startTour()
        let first = tour.progress
        XCTAssertFalse(tour.goToPreviousStop())
        XCTAssertEqual(tour.progress, first)
        while tour.phase == .inProgress { tour.completeCurrentStopAndAdvance() }
        let completed = tour.progress
        XCTAssertNil(tour.previousStop)
        XCTAssertFalse(tour.goToPreviousStop())
        XCTAssertEqual(tour.progress, completed)
    }

    func testPreviousStopHoldsAutomaticProgressionUntilExplicitContinue() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour(); tour.isAutomaticNavigationVisible = true
        tour.completeCurrentStopAndAdvance()
        XCTAssertTrue(tour.goToPreviousStop())
        confirmArrival(tour)
        let now = Date()
        let away = GeoCoordinate(latitude: stops[0].latitude + 0.002, longitude: stops[0].longitude)
        for age in [0.0, 5, 10] {
            let sample = LocationSample(coordinate: away, timestamp: now.addingTimeInterval(age))
            tour.evaluateAutomaticProgression(sample, now: sample.timestamp)
        }
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
        tour.completeCurrentStopAndAdvance()
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
        XCTAssertNil(tour.heldDepartureStopID)
        XCTAssertFalse(tour.walkingProgression.isHeld)
    }

    func testPreviousStopClearsStaleUndoAndARSubjectThenSupportsRepeatedBacktracking() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        for _ in 0..<3 { tour.completeCurrentStopAndAdvance() }
        tour.automaticTransitionFromStopID = stops[2].id
        tour.automaticTransitionProgress = tour.progress
        tour.arDiscoveryStopID = stops[1].id
        tour.continuedARStopIDs.insert(stops[2].id)
        XCTAssertTrue(tour.goToPreviousStop())
        XCTAssertNil(tour.automaticTransitionFromStopID)
        XCTAssertNil(tour.automaticTransitionProgress)
        XCTAssertEqual(tour.arStop?.id, stops[2].id)
        XCTAssertFalse(tour.continuedARStopIDs.contains(stops[2].id))
        XCTAssertTrue(tour.goToPreviousStop())
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
        XCTAssertTrue(tour.goToPreviousStop())
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
        XCTAssertFalse(tour.isHeadingToFirstStop, "Returning to Mill is not starting a new walk")
        XCTAssertEqual(tour.walkActionTitle, "Continue your walk")
        XCTAssertFalse(tour.goToPreviousStop())
    }

    func testPreviousStopAndHoldPersistWithoutResumingPausedWalkOrRequestingGPS() async {
        let storage = InMemoryWalkResumeStore()
        let source = ActivityTestLocationService(status: .notDetermined)
        func model() -> TourViewModel {
            TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
                locationService: source, directionsService: PreviewDirectionsService(), walkResumeStore: storage)
        }
        let first = model(); await first.loadStopsIfNeeded(); defer { cleanUp(first) }
        first.progress.start()
        for _ in 0..<3 { first.completeCurrentStopAndAdvance() }
        let paused = model(); await paused.loadStopsIfNeeded(); defer { cleanUp(paused) }
        XCTAssertTrue(paused.isWalkPaused)
        XCTAssertTrue(paused.goToPreviousStop())
        XCTAssertTrue(paused.isWalkPaused)
        XCTAssertFalse(paused.isWalkingActive)
        XCTAssertNil(paused.routingTask)
        XCTAssertEqual(source.permissionRequests, 0)
        XCTAssertEqual(source.startRequests, 0)
        let restored = model(); await restored.loadStopsIfNeeded(); defer { cleanUp(restored) }
        XCTAssertEqual(restored.currentStop?.id, stops[2].id)
        XCTAssertTrue(restored.isWalkPaused)
        XCTAssertEqual(restored.heldDepartureStopID, stops[2].id)
        XCTAssertEqual(storage.load()?.departureHoldStopID, stops[2].id)
    }

    func testPreviousStopRequestsRouteToThePrecedingDestination() async throws {
        let source = ActivityTestLocationService(status: .authorized)
        let tour = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: source, directionsService: PreviewDirectionsService())
        await tour.loadStopsIfNeeded(); defer { cleanUp(tour) }
        tour.startTour()
        source.emit(LocationSample(coordinate: stops[0].coordinate, horizontalAccuracy: 3))
        for _ in 0..<100 where tour.userLocation == nil { try await Task.sleep(for: .milliseconds(2)) }
        XCTAssertNotNil(tour.userLocation)
        for _ in 0..<3 { tour.completeCurrentStopAndAdvance() }
        XCTAssertTrue(tour.goToPreviousStop())
        for _ in 0..<100 where tour.currentRoute?.destination != stops[2].coordinate {
            try await Task.sleep(for: .milliseconds(2))
        }
        XCTAssertEqual(tour.currentStop?.id, stops[2].id)
        XCTAssertEqual(tour.currentRoute?.destination, stops[2].coordinate)
        XCTAssertEqual(tour.lastRouteRequest?.destination, stops[2].coordinate)
    }

    #if DEVELOPER_MENU
    func testGPSCapturesSaveMultipleLabeledReadingsAndSurviveReloadWithoutRetargeting() async throws {
        let suite = "gps-multiple-\(UUID())", defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let (tour, developer, source) = try await makeGPSCaptureContext(defaults: defaults)
        defer { cleanUp(tour) }
        let progress = tour.progress, activities = tour.activities
        XCTAssertTrue(developer.saveGPSCapture(stopID: stops[0].id, label: "Public gate"))
        let next = LocationSample(coordinate: GeoCoordinate(latitude: 40.6701, longitude: -74.3201),
                                  horizontalAccuracy: 3, timestamp: Date().addingTimeInterval(0.5))
        try await receiveGPS(next, source: source, tour: tour)
        XCTAssertTrue(developer.saveGPSCapture(stopID: stops[0].id, label: " River path ", now: next.timestamp))
        XCTAssertEqual(developer.captures(for: stops[0].id).map(\.label), ["River path", "Public gate"])
        XCTAssertEqual(tour.progress, progress)
        XCTAssertEqual(tour.activities, activities)
        XCTAssertEqual(tour.stops[0].coordinate, stops[0].coordinate)
        let restored = DeveloperModeController(tour: tour, realLocationService: source, defaults: defaults)
        XCTAssertEqual(restored.gpsCaptures, developer.gpsCaptures)
        XCTAssertEqual(restored.gpsCaptures.first?.horizontalAccuracy, 3)
        XCTAssertEqual(restored.gpsCaptures.first?.fixTimestamp, next.timestamp)
    }

    func testGPSCaptureRejectsRepeatedStaleInvalidAndSimulatedReadings() async throws {
        let suite = "gps-quality-\(UUID())", defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let (tour, developer, source) = try await makeGPSCaptureContext(defaults: defaults)
        defer { cleanUp(tour) }
        XCTAssertFalse(developer.saveGPSCapture(stopID: "unknown", label: "Wrong stop"))
        XCTAssertFalse(developer.saveGPSCapture(stopID: stops[0].id, label: "Stale", now: Date().addingTimeInterval(31)))
        XCTAssertTrue(developer.saveGPSCapture(stopID: stops[0].id, label: "First"))
        XCTAssertFalse(developer.saveGPSCapture(stopID: stops[0].id, label: "Duplicate"))
        let invalid = LocationSample(coordinate: GeoCoordinate(latitude: 40.67, longitude: -74.32),
                                    horizontalAccuracy: -1, timestamp: Date().addingTimeInterval(0.5))
        try await receiveGPS(invalid, source: source, tour: tour)
        XCTAssertFalse(developer.saveGPSCapture(stopID: stops[1].id, label: "Invalid", now: invalid.timestamp))
        let simulated = LocationSample(coordinate: invalid.coordinate, horizontalAccuracy: 3,
                                      timestamp: invalid.timestamp.addingTimeInterval(0.5), isSimulated: true)
        try await receiveGPS(simulated, source: source, tour: tour)
        XCTAssertFalse(developer.saveGPSCapture(stopID: stops[1].id, label: "Xcode", now: simulated.timestamp))
        tour.replaceLocationService(with: SimulatedLocationService(start: invalid.coordinate))
        XCTAssertFalse(developer.saveGPSCapture(stopID: stops[1].id, label: "Injected simulator"))
        XCTAssertEqual(developer.gpsCaptures.count, 1)
    }

    func testGPSCaptureKeepsWeakAccuracyMetadataAndUsesFallbackLabel() async throws {
        let suite = "gps-weak-\(UUID())", defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let sample = LocationSample(coordinate: GeoCoordinate(latitude: 40.67, longitude: -74.32), horizontalAccuracy: 70)
        let (tour, developer, _) = try await makeGPSCaptureContext(defaults: defaults, sample: sample)
        defer { cleanUp(tour) }
        XCTAssertTrue(developer.saveGPSCapture(stopID: stops[2].id, label: "  "))
        let saved = try XCTUnwrap(developer.gpsCaptures.first)
        XCTAssertEqual(saved.horizontalAccuracy, 70)
        XCTAssertEqual(saved.label, "Capture 1")
        XCTAssertTrue(saved.copyText.contains("± 70.0 m"))
        XCTAssertNotNil(developer.captureIssue(stopID: stops[2].id))
    }

    func testGPSCaptureCorruptOrFutureArchiveIsPreservedWithoutOverwrite() async throws {
        for value in [Data("broken".utf8), Data("{\"version\":2,\"records\":[]}".utf8)] {
            let suite = "gps-corrupt-\(UUID())", defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            defaults.set(value, forKey: "cranford.developer.gps-captures.v1")
            let (tour, developer, _) = try await makeGPSCaptureContext(defaults: defaults)
            defer { cleanUp(tour) }
            XCTAssertFalse(developer.saveGPSCapture(stopID: stops[0].id, label: "New"))
            developer.deleteGPSCapture(id: UUID())
            XCTAssertEqual(defaults.data(forKey: "cranford.developer.gps-captures.v1"), value)
            XCTAssertTrue(developer.gpsCaptures.isEmpty)
        }
    }

    func testLegacyViewingPointImportsOnceAndDoesNotReturnAfterExplicitDeletion() async throws {
        let suite = "gps-import-\(UUID())", defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set([40.67, -74.32, 4.0], forKey: "cranford.developer.mill-viewing-point.v1")
        defaults.set([4.2, 0.55, 5.3, 3.0], forKey: "cranford.developer.mill-window-layout.v1")
        defaults.set([0.05, 0.65, 0.8, 0.5], forKey: "cranford.developer.greystone-bonus-layout.v1")
        let (tour, developer, source) = try await makeGPSCaptureContext(defaults: defaults)
        defer { cleanUp(tour) }
        XCTAssertEqual(developer.gpsCaptures.count, 1)
        let imported = try XCTUnwrap(developer.gpsCaptures.first)
        XCTAssertEqual(imported.source, .legacyViewingPoint)
        XCTAssertNil(imported.fixTimestamp); XCTAssertNil(imported.preciseLocation)
        XCTAssertEqual(tour.stops[0].coordinate, stops[0].coordinate)
        let reloaded = DeveloperModeController(tour: tour, realLocationService: source, defaults: defaults)
        XCTAssertEqual(reloaded.gpsCaptures.count, 1)
        reloaded.deleteGPSCapture(id: imported.id)
        XCTAssertTrue(DeveloperModeController(tour: tour, realLocationService: source, defaults: defaults).gpsCaptures.isEmpty)
        XCTAssertNotNil(defaults.array(forKey: "cranford.developer.mill-viewing-point.v1"))
    }

    func testTourActivityResetsDoNotDeleteGPSCaptures() async throws {
        let suite = "gps-reset-\(UUID())", defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let (tour, developer, source) = try await makeGPSCaptureContext(defaults: defaults)
        defer { cleanUp(tour) }
        XCTAssertTrue(developer.saveGPSCapture(stopID: stops[1].id, label: "Park entrance"))
        let records = developer.gpsCaptures
        developer.clearVisitsAndResetTour(); developer.clearAllActivitiesAndResetTour(); developer.resetTour()
        XCTAssertEqual(developer.gpsCaptures, records)
        XCTAssertEqual(DeveloperModeController(tour: tour, realLocationService: source, defaults: defaults).gpsCaptures, records)
    }

    func testGPSCSVFileExportAndFailurePreserveSavedReadings() async throws {
        let suite = "gps-export-\(UUID())", defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let (tour, developer, _) = try await makeGPSCaptureContext(defaults: defaults)
        defer { cleanUp(tour) }
        XCTAssertNil(developer.makeCSVExport())
        XCTAssertTrue(developer.saveGPSCapture(stopID: stops[0].id, label: "Gate, \"east\""))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = try XCTUnwrap(developer.makeCSVExport(directory: folder))
        XCTAssertEqual(file.lastPathComponent, "Cranford-GPS-captures.csv")
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), developer.capturesCSV)
        let records = developer.gpsCaptures
        let blocker = folder.appendingPathComponent("a-file")
        try Data("not a directory".utf8).write(to: blocker)
        XCTAssertNil(developer.makeCSVExport(directory: blocker))
        XCTAssertEqual(developer.gpsCaptures, records)
    }

    func testGPSCaptureFilteringAndDeletionPreserveOtherTours() async throws {
        let suite = "gps-tour-scope-\(UUID())", defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let date = Date()
        let other = GPSCapture(tour: TourCatalogIdentity(tourID: "other-tour"), stopID: "other-stop", stopName: "Other place",
            label: "Other", coordinate: GeoCoordinate(latitude: 40.67, longitude: -74.32), horizontalAccuracy: 4,
            fixTimestamp: date, savedAt: date, preciseLocation: true)
        defaults.set(try JSONEncoder().encode(GPSCaptureArchive(records: [other])), forKey: "cranford.developer.gps-captures.v1")
        let (tour, developer, _) = try await makeGPSCaptureContext(defaults: defaults)
        defer { cleanUp(tour) }
        XCTAssertTrue(developer.currentTourCaptures.isEmpty)
        XCTAssertTrue(developer.saveGPSCapture(stopID: stops[0].id, label: "Cranford"))
        XCTAssertFalse(developer.capturesCSV.contains("other-tour"))
        let active = try XCTUnwrap(developer.currentTourCaptures.first)
        developer.deleteGPSCapture(id: active.id)
        XCTAssertEqual(developer.gpsCaptures, [other])
    }

    func testGPSCaptureCannotUseCachedCoordinatesAfterLocationPermissionIsDenied() async throws {
        let suite = "gps-permission-\(UUID())", defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let (tour, developer, _) = try await makeGPSCaptureContext(defaults: defaults, authorization: .denied)
        defer { cleanUp(tour) }
        XCTAssertNotNil(tour.userLocation)
        XCTAssertFalse(developer.saveGPSCapture(stopID: stops[0].id, label: "Denied"))
        XCTAssertTrue(developer.gpsCaptures.isEmpty)
    }

    func testGPSCaptureRefreshWaitsForANewFixAndRejectsOverlappingRequests() async throws {
        let suite = "gps-refresh-\(UUID())", defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let (tour, developer, source) = try await makeGPSCaptureContext(defaults: defaults)
        defer { cleanUp(tour) }
        developer.refreshGPSNow(); developer.refreshGPSNow()
        XCTAssertEqual(source.refreshRequests, 1)
        try await Task.sleep(for: .milliseconds(230))
        XCTAssertTrue(developer.isRefreshingGPS, "The existing location is not a newly requested fix")
        let fresh = LocationSample(coordinate: GeoCoordinate(latitude: 40.67, longitude: -74.32), horizontalAccuracy: 3)
        try await receiveGPS(fresh, source: source, tour: tour)
        for _ in 0..<100 where developer.isRefreshingGPS { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertFalse(developer.isRefreshingGPS)
        XCTAssertEqual(developer.gpsRefreshMessage, "Fresh GPS coordinates received.")
        XCTAssertTrue(developer.saveGPSCapture(stopID: stops[0].id, label: "Refreshed"))
        XCTAssertEqual(developer.gpsCaptures.first?.fixTimestamp, fresh.timestamp)
    }

    private func makeGPSCaptureContext(defaults: UserDefaults,
        sample: LocationSample = LocationSample(coordinate: GeoCoordinate(latitude: 40.67, longitude: -74.32), horizontalAccuracy: 4),
        authorization: LocationAuthorization = .authorized) async throws -> (TourViewModel, DeveloperModeController, ActivityTestLocationService) {
        let source = ActivityTestLocationService(status: authorization)
        let tour = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: source, directionsService: PreviewDirectionsService())
        await tour.loadStopsIfNeeded(); tour.startLocationIfPossible()
        try await receiveGPS(sample, source: source, tour: tour)
        return (tour, DeveloperModeController(tour: tour, realLocationService: source, defaults: defaults), source)
    }

    private func receiveGPS(_ sample: LocationSample, source: ActivityTestLocationService, tour: TourViewModel) async throws {
        source.emit(sample)
        for _ in 0..<100 where tour.userLocation?.timestamp != sample.timestamp {
            try await Task.sleep(for: .milliseconds(2))
        }
        XCTAssertEqual(tour.userLocation?.timestamp, sample.timestamp)
    }
    #endif

    private var stops: [HistoricalStop] { HistoricalStop.previewStops }
    private func makeTour(visitStore: (any StopVisitStore)? = nil, activityStore: (any StopActivityStore)? = nil) async -> TourViewModel {
        let model = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: ActivityTestLocationService(), directionsService: PreviewDirectionsService(),
            visitStore: visitStore, activityStore: activityStore)
        await model.loadStopsIfNeeded()
        return model
    }
    /// Reliable on-site fixes exercise the full three-minute visit dwell.
    private func confirmArrival(_ tour: TourViewModel) {
        guard let stop = tour.currentStop else { return }
        let now = Date()
        for seconds in stride(from: -180.0, through: 0.0, by: 3.0) {
            let date = now.addingTimeInterval(seconds)
            tour.evaluateAutomaticProgression(LocationSample(coordinate: stop.coordinate,
                horizontalAccuracy: 3, timestamp: date), now: date)
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
            XCTAssertNil(tour.activities[stop.id].plaqueUnlockedAt)
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
        XCTAssertNil(tour.activities[stops[1].id].plaqueUnlockedAt)
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
        XCTAssertNil(tour.activities[stops[1].id].plaqueUnlockedAt)
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
        XCTAssertNil(tour.activities[stops[0].id].plaqueUnlockedAt)
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
        let start = Date().addingTimeInterval(-180)
        for seconds in 0...180 {
            let date = start.addingTimeInterval(Double(seconds))
            tour.handleLocationForProximity(LocationSample(coordinate: stops[3].coordinate, timestamp: date), now: date)
            if seconds < 180 { XCTAssertNil(tour.activities[stops[3].id].visitedAt) }
        }
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
        XCTAssertNotNil(tour.activities[stops[1].id].plaqueUnlockedAt)
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
        XCTAssertNotNil(tour.activities[stops[1].id].plaqueUnlockedAt)
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
        XCTAssertNotNil(tour.activities[stops[0].id].plaqueUnlockedAt)
        XCTAssertNil(tour.activities[stops[1].id].plaqueUnlockedAt)
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
        XCTAssertNotNil(tour.activities[stops[1].id].plaqueUnlockedAt)
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
        XCTAssertNil(tour.activities[stops[1].id].plaqueUnlockedAt)
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
        XCTAssertNotNil(tour.activities[stops[0].id].plaqueUnlockedAt)
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
        ledger.collectSketch(at: "mill")
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
        var ledger = StopActivityLedger(); ledger.collectSketch(at: stops[1].id)
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
    private(set) var refreshRequests = 0
    init(status: LocationAuthorization = .denied) { self.status = status }
    var authorization: LocationAuthorization { status }
    var isPreciseLocationAuthorized: Bool { true }
    var isHeadingAvailable: Bool { false }
    func events() -> AsyncStream<LocationEvent> { broadcaster.stream() }
    func emit(_ sample: LocationSample) { broadcaster.send(.location(sample)) }
    func requestWhenInUseAuthorization() { permissionRequests += 1 }
    func requestTemporaryPreciseLocationIfNeeded() {}
    func start() { startRequests += 1 }
    func requestFreshLocation() { refreshRequests += 1 }
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
        tour.replaceLocationService(with: SimulatedLocationService(start: point))
        developer.refreshGPSNow()
        XCTAssertEqual(service.refreshRequests, 1)
        XCTAssertFalse(developer.isRefreshingGPS)
    }

    func testRemovedPlacementSettingsAreIgnoredAndViewingPointBecomesACapture() async throws {
        let suite = "cranford.legacy-placements.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set([4.2, 0.55, 5.3, 3.0], forKey: "cranford.developer.mill-window-layout.v1")
        defaults.set([0.05, 0.65, 0.8, 0.5], forKey: "cranford.developer.greystone-bonus-layout.v1")
        defaults.set([40.65, -74.30, 4.0], forKey: "cranford.developer.mill-viewing-point.v1")
        let service = DeveloperTestLocationService(sample: nil)
        let tour = TourViewModel(stopService: InMemoryHistoricalStopService(stops: HistoricalStop.previewStops),
                                 locationService: service, directionsService: PreviewDirectionsService())
        await tour.loadStopsIfNeeded()
        defer { tour.stopLocation(); tour.cancelRouting() }
        let developer = DeveloperModeController(tour: tour, realLocationService: service, defaults: defaults)
        XCTAssertEqual(developer.gpsCaptures.count, 1)
        XCTAssertEqual(developer.gpsCaptures.first?.source, .legacyViewingPoint)
        XCTAssertNil(developer.gpsCaptures.first?.fixTimestamp)
        developer.clearVisitsAndResetTour()
        XCTAssertEqual(developer.gpsCaptures.count, 1)
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
        XCTAssertEqual(tour.homeWalkActionTitle, "Start walk")
        tour.startTour()
        tour.finishStory(for: firstID)
        XCTAssertTrue(tour.beginPlaqueDiscovery())
        tour.confirmPlaqueArrival(for: firstID)
        XCTAssertEqual(tour.activateCurrentStop(stopID: firstID, trackingReady: true, plaqueIsTracked: true), .allow(.recognizedPlaque))
        XCTAssertEqual(Set(store.records().map(\.stopID)), [firstID, oldVisit.stopID])
        XCTAssertEqual(tour.visitRecords.count, 2)
    }

    func testDeveloperVisitResetPreservesStoriesAndBonusesAndPausesSimulator() async throws {
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
        XCTAssertEqual(tour.activateCurrentStop(stopID: "hpab-001", trackingReady: true, plaqueIsTracked: true), .alreadyActivated,
                       "A migrated saved plaque bonus must not be awarded again")
        tour.completeCurrentStopAndAdvance()
        tour.progress.recordWalked(meters: 100)
        developer.isVisitRecordingEnabled = false
        let simulator = SimulatedLocationService(start: HistoricalStop.previewStops[1].coordinate)
        tour.replaceLocationService(with: simulator)
        simulator.startWalking()
        XCTAssertTrue(simulator.isWalking)
        XCTAssertEqual(tour.currentStop?.id, "hpab-002")

        developer.clearVisitsAndResetTour()
        XCTAssertTrue(store.records().isEmpty)
        XCTAssertTrue(tour.visitRecords.isEmpty)
        XCTAssertNotNil(tour.activities["hpab-001"].plaqueUnlockedAt, "Visit-only reset preserves the earned stamp")
        XCTAssertNotNil(tour.activities["hpab-001"].readAt, "Visit-only reset preserves story completion")
        XCTAssertNil(tour.currentStop)
        XCTAssertEqual(tour.homeFeaturedStop?.id, "hpab-001")
        XCTAssertEqual(tour.homeWalkActionTitle, "Start walk")
        XCTAssertEqual(tour.progress.completedCount, 0)
        XCTAssertEqual(tour.progress.walkedMeters, 0)
        XCTAssertFalse(tour.isCurrentStopVisited)
        XCTAssertNil(tour.lastCompletedStop)
        XCTAssertNil(tour.activeVisitEvidence)
        XCTAssertFalse(simulator.isWalking)
        XCTAssertTrue(tour.locationService is SimulatedLocationService, "A reset preserves an injected test source")
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
