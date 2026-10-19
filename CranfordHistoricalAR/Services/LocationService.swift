import CoreLocation
import Foundation
import TourCore

// MARK: - Value types shared by real and simulated location sources

struct LocationSample: Sendable, Equatable {
    var coordinate: GeoCoordinate
    /// Meters (68% confidence). Negative means invalid.
    var horizontalAccuracy: Double
    /// Course over ground in degrees, `nil` when invalid/unknown.
    var course: Double?
    /// Meters per second, `nil` when unknown.
    var speed: Double?
    var altitude: Double?
    var timestamp: Date
    var isSimulated: Bool

    init(location: CLLocation) {
        coordinate = GeoCoordinate(location.coordinate)
        horizontalAccuracy = location.horizontalAccuracy
        course = location.course >= 0 ? location.course : nil
        speed = location.speed >= 0 ? location.speed : nil
        altitude = location.verticalAccuracy >= 0 ? location.altitude : nil
        timestamp = location.timestamp
        isSimulated = location.sourceInformation?.isSimulatedBySoftware == true
    }

    init(coordinate: GeoCoordinate, horizontalAccuracy: Double = 5, course: Double? = nil, speed: Double? = nil, altitude: Double? = nil, timestamp: Date = Date(), isSimulated: Bool = false) {
        self.coordinate = coordinate
        self.horizontalAccuracy = horizontalAccuracy
        self.course = course
        self.speed = speed
        self.altitude = altitude
        self.timestamp = timestamp
        self.isSimulated = isSimulated
    }

    var clLocationCoordinate: CLLocationCoordinate2D { coordinate.clLocationCoordinate }
}

struct HeadingSample: Sendable, Equatable {
    /// Degrees relative to true north; `nil` when true heading is unavailable.
    var trueHeading: Double?
    var magneticHeading: Double
    /// Degrees of error; negative means invalid.
    var accuracy: Double
    var timestamp: Date
    var isSimulated: Bool

    init(heading: CLHeading) {
        trueHeading = heading.trueHeading >= 0 ? heading.trueHeading : nil
        magneticHeading = heading.magneticHeading
        accuracy = heading.headingAccuracy
        timestamp = heading.timestamp
        isSimulated = false
    }

    init(trueHeading: Double?, magneticHeading: Double, accuracy: Double, timestamp: Date = Date(), isSimulated: Bool = false) {
        self.trueHeading = trueHeading
        self.magneticHeading = magneticHeading
        self.accuracy = accuracy
        self.timestamp = timestamp
        self.isSimulated = isSimulated
    }

    /// Best available heading: true north when valid, else magnetic.
    var bestHeading: Double { trueHeading ?? magneticHeading }
    var isReliable: Bool { accuracy.isFinite && accuracy >= 0 && accuracy <= 25 && bestHeading.isFinite }
}

enum LocationAuthorization: Sendable, Equatable {
    case notDetermined
    case denied
    case restricted
    case authorized

    init(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        case .restricted: self = .restricted
        case .authorizedAlways, .authorizedWhenInUse: self = .authorized
        @unknown default: self = .denied
        }
    }
}

enum LocationFailure: Sendable, Equatable, Error {
    case denied
    case locationUnknown
    case network
    case other(String)

    init(_ error: Error) {
        if let clError = error as? CLError {
            switch clError.code {
            case .denied: self = .denied
            case .locationUnknown: self = .locationUnknown
            case .network: self = .network
            default: self = .other(clError.localizedDescription)
            }
        } else {
            self = .other(error.localizedDescription)
        }
    }
}

enum LocationEvent: Sendable, Equatable {
    case authorization(LocationAuthorization, precise: Bool)
    case location(LocationSample)
    case heading(HeadingSample)
    case failure(LocationFailure)
}

// MARK: - Protocol

/// The one location source the app listens to (spec §17). `TourViewModel` subscribes once;
/// screens read location from the view model instead of creating their own managers.
@MainActor
protocol LocationService: AnyObject {
    var authorization: LocationAuthorization { get }
    var isPreciseLocationAuthorized: Bool { get }
    var isHeadingAvailable: Bool { get }
    /// Each call returns an independent stream so consumers can resubscribe freely.
    func events() -> AsyncStream<LocationEvent>
    func requestWhenInUseAuthorization()
    func requestTemporaryPreciseLocationIfNeeded()
    func start()
    func requestFreshLocation()
    func stop()
}

/// Minimal multicast helper for `AsyncStream` consumers.
@MainActor
final class EventBroadcaster<Event: Sendable> {
    private var continuations: [UUID: AsyncStream<Event>.Continuation] = [:]
    private(set) var latest: Event?

    func stream(replayLatest: Bool = true) -> AsyncStream<Event> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: Event.self, bufferingPolicy: .bufferingNewest(32))
        continuations[id] = continuation
        if replayLatest, let latest { continuation.yield(latest) }
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in self?.continuations[id] = nil }
        }
        return stream
    }

    func send(_ event: Event) {
        latest = event
        for continuation in continuations.values { continuation.yield(event) }
    }

    func finish() {
        for continuation in continuations.values { continuation.finish() }
        continuations.removeAll()
    }
}

// MARK: - Core Location implementation

@MainActor
final class CoreLocationService: NSObject, LocationService {
    private let manager = CLLocationManager()
    private let broadcaster = EventBroadcaster<LocationEvent>()
    private var isRunning = false
    private var isRequestingFreshLocation = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 2
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        manager.headingFilter = 2
    }

    var authorization: LocationAuthorization { LocationAuthorization(manager.authorizationStatus) }
    var isPreciseLocationAuthorized: Bool { manager.accuracyAuthorization == .fullAccuracy }
    var isHeadingAvailable: Bool { CLLocationManager.headingAvailable() }

    func events() -> AsyncStream<LocationEvent> {
        broadcaster.stream()
    }

    func requestWhenInUseAuthorization() {
        guard manager.authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    func requestTemporaryPreciseLocationIfNeeded() {
        guard authorization == .authorized, manager.accuracyAuthorization == .reducedAccuracy else { return }
        manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "PreciseLocationForAR")
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.headingOrientation = .portrait
            manager.startUpdatingHeading()
        }
    }

    /// One-shot refresh on the existing manager. Continuous updates must pause because
    /// requestLocation() is ignored while startUpdatingLocation() is active.
    func requestFreshLocation() {
        guard authorization == .authorized else { requestWhenInUseAuthorization(); return }
        manager.stopUpdatingLocation()
        isRequestingFreshLocation = true
        manager.requestLocation()
    }

    private func resumeAfterRefresh() {
        guard isRequestingFreshLocation else { return }
        isRequestingFreshLocation = false
        if isRunning { manager.startUpdatingLocation() }
    }

    func stop() {
        isRequestingFreshLocation = false
        guard isRunning else { return }
        isRunning = false
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    private func publish(_ event: LocationEvent) {
        broadcaster.send(event)
    }
}

extension CoreLocationService: CLLocationManagerDelegate {
    // CLLocationManager calls its delegate on the thread it was created on (main here), but the
    // protocol requirements are nonisolated, so hop explicitly and pass only Sendable values.

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = LocationAuthorization(manager.authorizationStatus)
        let precise = manager.accuracyAuthorization == .fullAccuracy
        Task { @MainActor in self.publish(.authorization(status, precise: precise)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let samples = locations
            .filter { $0.horizontalAccuracy >= 0 }
            .map(LocationSample.init(location:))
        Task { @MainActor in
            for sample in samples { self.publish(.location(sample)) }
            self.resumeAfterRefresh()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let sample = HeadingSample(heading: newHeading)
        Task { @MainActor in self.publish(.heading(sample)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let failure = LocationFailure(error)
        Task { @MainActor in
            self.publish(.failure(failure))
            self.resumeAfterRefresh()
        }
    }

    nonisolated func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        true
    }
}
