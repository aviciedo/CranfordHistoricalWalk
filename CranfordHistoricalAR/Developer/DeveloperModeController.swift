#if DEVELOPER_MENU
import Foundation
import Observation
import TourCore

/// Device-GPS field captures and diagnostics. Debug builds only. Captures are local
/// evidence for review; saving them never rewrites routing, arrival or activity state.
@MainActor
@Observable
final class DeveloperModeController {
    private let tour: TourViewModel
    private let realLocationService: any LocationService
    private let defaults: UserDefaults
    private static let viewingKey = "cranford.developer.mill-viewing-point.v1"
    private static let windowKey = "cranford.developer.mill-window-layout.v1"
    private static let parkKey = "cranford.developer.greystone-bonus-layout.v1"
    private(set) var isRefreshingGPS = false
    private(set) var gpsRefreshMessage: String?
    @ObservationIgnored private var gpsRefreshTask: Task<Void, Never>?

    private static let captureKey = "cranford.developer.gps-captures.v1"
    private static let viewingImportKey = "cranford.developer.viewing-point-imported.v1"
    private(set) var gpsCaptures: [GPSCapture] = []
    private(set) var captureMessage: String?
    private var captureStorageReadable = true
    private var isSimulatedSource: Bool { tour.locationService is SimulatedLocationService }

    var currentTourCaptures: [GPSCapture] {
        guard tour.loadState == .loaded else { return [] }
        return gpsCaptures.filter { $0.tour.tourID == tour.catalogIdentity.tourID }
    }
    var capturesCSV: String { GPSCapture.csv(currentTourCaptures) }

    func captures(for stopID: String) -> [GPSCapture] {
        currentTourCaptures.filter { $0.stopID == stopID }
    }

    func captureIssue(stopID: String, now: Date = Date()) -> String? {
        guard captureStorageReadable else { return "Saved readings could not be read. Existing data has been kept; new captures are paused." }
        guard tour.loadState == .loaded, tour.stop(withID: stopID) != nil else { return "Select a tour stop for this reading." }
        guard tour.locationAuthorization == .authorized else { return "Allow location access to capture device GPS." }
        guard !isSimulatedSource, let sample = tour.userLocation, !sample.isSimulated else {
            return "Wait for device GPS. Simulated readings cannot be saved."
        }
        guard sample.coordinate.isValid, sample.horizontalAccuracy.isFinite, sample.horizontalAccuracy >= 0 else {
            return "Wait for a valid GPS reading."
        }
        guard StopActivationPolicy.isFresh(sample.timestamp, now: now) else { return "Refresh GPS before saving this reading." }
        guard !captures(for: stopID).contains(where: { $0.source == .deviceGPS && $0.fixTimestamp == sample.timestamp }) else {
            return "This reading is already saved for this stop. Refresh GPS for another capture."
        }
        return nil
    }

    @discardableResult
    func saveGPSCapture(stopID: String, label: String, now: Date = Date()) -> Bool {
        if let issue = captureIssue(stopID: stopID, now: now) { captureMessage = issue; return false }
        guard let stop = tour.stop(withID: stopID), let sample = tour.userLocation else { return false }
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let capture = GPSCapture(tour: tour.catalogIdentity, stopID: stop.id, stopName: stop.name,
            label: trimmed.isEmpty ? "Capture \(captures(for: stopID).count + 1)" : trimmed,
            coordinate: sample.coordinate, horizontalAccuracy: sample.horizontalAccuracy,
            fixTimestamp: sample.timestamp, savedAt: now,
            preciseLocation: tour.locationAuthorization == .authorized && tour.isPreciseLocation)
        guard persistCaptures([capture] + gpsCaptures) else { return false }
        captureMessage = "Saved \(capture.label) for \(stop.name)."
        return true
    }

    func deleteGPSCapture(id: UUID) {
        if persistCaptures(gpsCaptures.filter { $0.id != id }) { captureMessage = "GPS capture deleted." }
    }

    func makeCSVExport(directory: URL = FileManager.default.temporaryDirectory) -> URL? {
        guard !currentTourCaptures.isEmpty else { captureMessage = "No saved GPS captures to share."; return nil }
        do {
            let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let file = folder.appendingPathComponent("Cranford-GPS-captures.csv")
            try Data(capturesCSV.utf8).write(to: file, options: .atomic)
            return file
        } catch {
            captureMessage = "Could not prepare the CSV file. Your saved readings are unchanged."
            return nil
        }
    }

    private func persistCaptures(_ next: [GPSCapture]) -> Bool {
        guard captureStorageReadable else { return false }
        let archive = GPSCaptureArchive(records: next)
        guard archive.isValid, let data = try? JSONEncoder().encode(archive) else {
            captureMessage = "Could not save this GPS capture. Existing readings were kept."
            return false
        }
        defaults.set(data, forKey: Self.captureKey)
        gpsCaptures = next
        return true
    }

    func refreshGPSNow() {
        guard !isRefreshingGPS else { return }
        guard !isSimulatedSource else {
            gpsRefreshMessage = "Device GPS is required to refresh coordinates."
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
                if self.isSimulatedSource {
                    self.gpsRefreshMessage = "GPS refresh stopped: a simulated source is active."
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

    init(tour: TourViewModel, realLocationService: any LocationService, defaults: UserDefaults = .standard) {
        self.tour = tour
        self.realLocationService = realLocationService
        self.defaults = defaults
        if defaults.object(forKey: Self.captureKey) != nil {
            if let data = defaults.data(forKey: Self.captureKey),
               let archive = try? JSONDecoder().decode(GPSCaptureArchive.self, from: data), archive.isValid {
                gpsCaptures = archive.records
            } else {
                captureStorageReadable = false
                captureMessage = "Saved GPS data could not be read. It has been kept without changes."
            }
        }
        // Import the old mill coordinate once as a record, never as an arrival override.
        // Its original fix timestamp/permission were not stored and must not be invented.
        if captureStorageReadable, !defaults.bool(forKey: Self.viewingImportKey),
           let values = defaults.array(forKey: Self.viewingKey) as? [Double], values.count == 3 {
            let legacy = GPSCapture(tour: .legacy, stopID: "hpab-001", stopName: "Droescher’s Mill",
                label: "Imported mill viewing point", coordinate: GeoCoordinate(latitude: values[0], longitude: values[1]),
                horizontalAccuracy: values[2], fixTimestamp: nil, preciseLocation: nil, source: .legacyViewingPoint)
            if legacy.isValid, persistCaptures([legacy] + gpsCaptures) {
                defaults.set(true, forKey: Self.viewingImportKey)
            }
        }
        // Existing bonus placements remain read-only so retiring editors does not move bonuses.
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

    func markStoryRead() {
        if tour.phase == .notStarted { tour.startTour() }
        if let stop = tour.currentStop { tour.finishStory(for: stop.id) }
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
        (tour.locationService as? SimulatedLocationService)?.stopWalking()
        tour.resetTour(startImmediately: false)
    }

    /// Suppresses saved history only; marker activation and Continue still exercise the real flow.
    var isVisitRecordingEnabled: Bool {
        get { tour.isVisitRecordingEnabled }
        set { tour.isVisitRecordingEnabled = newValue }
    }

    func clearVisitsAndResetTour() {
        (tour.locationService as? SimulatedLocationService)?.stopWalking()
        tour.clearRecordedActivitiesAndRestart(includingStoriesAndBonuses: false)
    }

    func clearAllActivitiesAndResetTour() {
        (tour.locationService as? SimulatedLocationService)?.stopWalking()
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
