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
    private var stops: [HistoricalStop] { HistoricalStop.previewStops }
    private func makeTour(visitStore: (any StopVisitStore)? = nil, activityStore: (any StopActivityStore)? = nil) async -> TourViewModel {
        let model = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: ActivityTestLocationService(), directionsService: PreviewDirectionsService(),
            visitStore: visitStore, activityStore: activityStore)
        await model.loadStopsIfNeeded()
        return model
    }
    private func cleanUp(_ model: TourViewModel) { model.stopLocation(); model.cancelRouting() }

    func testEntireWalkNeedsOnlyGPSAndExplicitContinue() async throws {
        let source = ActivityTestLocationService(status: .authorized)
        let tour = TourViewModel(stopService: InMemoryHistoricalStopService(stops: stops),
            locationService: source, directionsService: PreviewDirectionsService())
        await tour.loadStopsIfNeeded()
        defer { cleanUp(tour) }
        tour.startTour()
        for stop in stops {
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
        tour.handleLocationForProximity(LocationSample(coordinate: stops[0].coordinate))
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
        navigation.storyModes[stops[0].id] = .read
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
        XCTAssertEqual(navigation.storyModes[stops[0].id], .read)
    }
    func testGPSRecordsVisitWithoutCompletingLearningBonusOrAdvancing() async {
        let tour = await makeTour(); defer { cleanUp(tour) }
        tour.startTour()
        let sample = LocationSample(coordinate: stops[0].coordinate, horizontalAccuracy: 3)
        tour.handleLocationForProximity(sample)
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
