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
    func testPassportUsesExistingBonusHistoryWithoutReplayingCelebration() async {
        let store = InMemoryStopActivityStore()
        var ledger = StopActivityLedger()
        ledger.foundBonus(at: stops[0].id)
        ledger.visited(stops[1].id)
        ledger.read(stops[1].id)
        store.save(ledger)
        let tour = await makeTour(activityStore: store); defer { cleanUp(tour) }
        XCTAssertEqual(tour.passportStops.map(\.id), [stops[0].id, stops[1].id])
        XCTAssertEqual(tour.passportCollectedCount, 1, "Visits and reading do not award stamps")
        XCTAssertNil(tour.pendingPassportStampStopID)
        XCTAssertNil(tour.takePassportStamp())
        XCTAssertEqual(tour.phase, .notStarted)
    }

    func testNewRealPlaqueQueuesExactlyOnePassportRevealAndSurvivesNewWalk() async {
        let store = InMemoryStopActivityStore()
        let tour = await makeTour(activityStore: store); defer { cleanUp(tour) }
        XCTAssertTrue(tour.preparePlaqueScanner(stopID: stops[1].id))
        tour.confirmPlaqueArrival(for: stops[1].id)
        XCTAssertEqual(tour.activateCurrentStop(stopID: stops[1].id, trackingReady: true, plaqueIsTracked: true), .allow(.recognizedPlaque))
        XCTAssertEqual(tour.passportCollectedCount, 1)
        XCTAssertNotNil(store.load()[stops[1].id].bonusFoundAt, "Persist before announcing the stamp")
        XCTAssertEqual(tour.pendingPassportStampStopID, stops[1].id)
        tour.endARDiscoverySession()
        XCTAssertEqual(tour.takePassportStamp(), stops[1].id, "Retain event through AR teardown")
        XCTAssertNil(tour.takePassportStamp(), "Consume only once")
        XCTAssertTrue(tour.preparePlaqueScanner(stopID: stops[1].id))
        tour.confirmPlaqueArrival(for: stops[1].id)
        XCTAssertEqual(tour.activateCurrentStop(stopID: stops[1].id, trackingReady: true, plaqueIsTracked: true), .alreadyActivated)
        XCTAssertNil(tour.pendingPassportStampStopID)
        XCTAssertEqual(tour.passportCollectedCount, 1)
        tour.endARDiscoverySession()
        XCTAssertEqual(tour.phase, .notStarted, "Plaque discovery alone never starts a walk")
        tour.resetTour()
        XCTAssertEqual(tour.passportCollectedCount, 1)
        XCTAssertEqual(tour.phase, .inProgress, "Explicit Start another walk retains the existing restart behavior")
        XCTAssertFalse(tour.activities[stops[1].id].learningCompleted)
        let reloaded = await makeTour(activityStore: store); defer { cleanUp(reloaded) }
        XCTAssertEqual(reloaded.passportCollectedCount, 1)
        XCTAssertNil(reloaded.pendingPassportStampStopID, "Relaunch preserves stamps without an unsolicited celebration")
    }

    func testPracticeAndDisabledRecordingDoNotAwardPassportStamps() async {
        let practice = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: SimulatedLocationService(start: stops[0].coordinate), directionsService: PreviewDirectionsService())
        await practice.loadStopsIfNeeded(); defer { cleanUp(practice) }
        XCTAssertTrue(practice.preparePlaqueScanner(stopID: stops[0].id))
        practice.confirmPlaqueArrival(for: stops[0].id)
        XCTAssertEqual(practice.activateCurrentStop(stopID: stops[0].id, trackingReady: true, plaqueIsTracked: true), .allow(.simulation))
        XCTAssertEqual(practice.passportCollectedCount, 0)
        XCTAssertNil(practice.pendingPassportStampStopID)
        #if DEVELOPER_MENU
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.isVisitRecordingEnabled = false
        XCTAssertTrue(tour.preparePlaqueScanner(stopID: stops[1].id))
        tour.confirmPlaqueArrival(for: stops[1].id)
        _ = tour.activateCurrentStop(stopID: stops[1].id, trackingReady: true, plaqueIsTracked: true)
        XCTAssertEqual(tour.passportCollectedCount, 0)
        XCTAssertNil(tour.pendingPassportStampStopID)
        #endif
    }

    func testPassportVisitOnlyAndFullResetsRemainIndependent() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        XCTAssertTrue(tour.preparePlaqueScanner(stopID: stops[0].id))
        tour.confirmPlaqueArrival(for: stops[0].id)
        _ = tour.activateCurrentStop(stopID: stops[0].id, trackingReady: true, plaqueIsTracked: true)
        #if DEVELOPER_MENU
        tour.clearRecordedActivitiesAndRestart(includingStoriesAndBonuses: false)
        XCTAssertEqual(tour.passportCollectedCount, 1)
        XCTAssertNil(tour.activities[stops[0].id].visitedAt)
        XCTAssertNil(tour.pendingPassportStampStopID)
        tour.clearRecordedActivitiesAndRestart(includingStoriesAndBonuses: true)
        XCTAssertEqual(tour.passportCollectedCount, 0)
        XCTAssertNil(tour.pendingPassportStampStopID)
        #endif
    }

    func testSavedVisitAndBonusNeverSuppressReturnWalkingArrows() async {
        let store = InMemoryStopActivityStore()
        var ledger = StopActivityLedger()
        ledger.visited(stops[0].id)
        ledger.foundBonus(at: stops[0].id)
        store.save(ledger)
        let tour = await makeTour(activityStore: store); defer { cleanUp(tour) }
        tour.startTour()
        XCTAssertTrue(tour.isARStopVisited, "Saved accomplishments remain intact")
        XCTAssertTrue(tour.discovery.hasArrived, "Saved bonus discovery must not masquerade as current presence")
        XCTAssertFalse(tour.shouldSuppressWalkingAR, "Still guide the user toward a previously visited destination")
        XCTAssertFalse(tour.hasPlaqueConfirmedArrival)
        confirmArrival(tour)
        XCTAssertTrue(tour.shouldSuppressWalkingAR, "Actual current-session arrival ends walking guidance")
    }

    func testWalkingArrowsResumeOnAdvanceAndPreviousWithoutErasingVisits() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        confirmArrival(tour)
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
        XCTAssertEqual(map.markers(for: tour, emphasizesDestinationOnly: true).filter(\.isIllustrated).map(\.id), [stops[3].id])
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

    func testMapTurnCardNamesTheStreetAndHidesOnArrivalOrWeakGPS() async throws {
        let source = ActivityTestLocationService(status: .authorized)
        let tour = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: source, directionsService: PreviewDirectionsService())
        await tour.loadStopsIfNeeded()
        tour.startTour()
        defer { cleanUp(tour) }
        let user = GeoMath.destination(from: stops[0].coordinate, bearing: 180, distance: 120)
        let fix = LocationSample(coordinate: user, horizontalAccuracy: 5, timestamp: Date())
        source.emit(fix)
        for _ in 0..<150 where tour.userLocation?.timestamp != fix.timestamp || tour.currentRoute == nil {
            try await Task.sleep(for: .milliseconds(2))
        }
        XCTAssertEqual(tour.userLocation?.timestamp, fix.timestamp)
        XCTAssertNil(tour.locationIssue)
        XCTAssertEqual(tour.currentRoute?.source, .simulated)
        tour.cancelRouting()

        let corner = GeoMath.destination(from: user, bearing: 0, distance: 80)
        let route = WalkingRoute(origin: user, destination: stops[0].coordinate, distanceMeters: 120, durationSeconds: 90,
            routeCoordinates: [user, corner, stops[0].coordinate], routeSteps: [
                RouteStep(distanceMeters: 80, durationSeconds: 60, startCoordinate: user, endCoordinate: corner,
                          instruction: "Head north on Lincoln Ave E", maneuver: "DEPART"),
                RouteStep(distanceMeters: 40, durationSeconds: 30, startCoordinate: corner, endCoordinate: stops[0].coordinate,
                          instruction: "Turn right onto Springfield Ave", maneuver: "TURN_RIGHT")
            ], source: .appleMaps)
        tour.currentRoute = route
        tour.routeProgress = RouteProgressCalculator.progress(along: route, userLocation: user)
        let cue = try XCTUnwrap(tour.mapWalkingCue)
        XCTAssertEqual(cue.mapTurnCardText, "Turn right onto Springfield Ave")
        XCTAssertFalse(cue.mapTurnCardText.contains("ft"))
        XCTAssertEqual(ARWalkingGuidance.mapTurnCardSentence(phase: tour.phase, isPaused: tour.isWalkPaused,
            hasArrived: tour.walkingProgression.hasArrived, cue: cue), cue.mapTurnCardText)

        tour.currentRoute = .straightLineEstimate(from: user, to: stops[0].coordinate)
        tour.routeProgress = RouteProgressCalculator.progress(along: tour.currentRoute!, userLocation: user)
        XCTAssertNil(tour.mapWalkingCue, "A straight-line estimate is not a street turn")

        tour.currentRoute = route
        tour.routeProgress = RouteProgressCalculator.progress(along: route, userLocation: user)
        tour.walkingProgression.confirmArrival()
        XCTAssertNotNil(tour.mapWalkingCue, "The route cue remains; the card hides because this walk has arrived")
        XCTAssertNil(ARWalkingGuidance.mapTurnCardSentence(phase: tour.phase, isPaused: tour.isWalkPaused,
            hasArrived: tour.walkingProgression.hasArrived, cue: tour.mapWalkingCue))

        let weak = LocationSample(coordinate: user, horizontalAccuracy: 30, timestamp: fix.timestamp.addingTimeInterval(1))
        source.emit(weak)
        for _ in 0..<150 where tour.userLocation?.horizontalAccuracy != 30 {
            try await Task.sleep(for: .milliseconds(2))
        }
        XCTAssertEqual(tour.locationIssue, .poorAccuracy(meters: 30))
        XCTAssertNil(tour.mapWalkingCue, "Weak GPS must not keep showing the last turn")
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

    func testPreviousStopUsesTourOrderAndPreservesAllRecordedProgress() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        tour.progress.markCurrentStopVisited()
        tour.finishListening(for: stops[0].id)
        tour.activities.foundBonus(at: stops[1].id)
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
        XCTAssertEqual(tour.windowBonusLayout.width, 5.3)
        XCTAssertEqual(tour.parkBonusLayout.width, 0.8)
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

    func testExistingBonusPlacementsLoadReadOnlyAndViewingPointBecomesACapture() async throws {
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
        XCTAssertEqual(tour.windowBonusLayout, WindowBonusLayout(right: 4.2, up: 0.55, width: 5.3, height: 3))
        XCTAssertEqual(tour.parkBonusLayout, WindowBonusLayout(right: 0.05, up: 0.65, width: 0.8, height: 0.5))
        XCTAssertEqual(developer.gpsCaptures.count, 1)
        XCTAssertEqual(developer.gpsCaptures.first?.source, .legacyViewingPoint)
        XCTAssertNil(developer.gpsCaptures.first?.fixTimestamp)
        developer.clearVisitsAndResetTour()
        XCTAssertEqual(developer.gpsCaptures.count, 1)
        XCTAssertEqual(tour.windowBonusLayout.width, 5.3)
        XCTAssertEqual(tour.parkBonusLayout.width, 0.8)
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
        XCTAssertNotNil(tour.activities["hpab-001"].bonusFoundAt, "Visit-only reset preserves the earned stamp")
        XCTAssertNotNil(tour.activities["hpab-001"].readAt, "Visit-only reset preserves story completion")
        XCTAssertEqual(tour.currentStop?.id, "hpab-001")
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
