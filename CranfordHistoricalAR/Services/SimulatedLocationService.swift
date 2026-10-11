import Foundation
import TourCore

/// A `LocationService` driven by `WalkSimulator` instead of GPS (spec §19). Swapped into
/// `TourViewModel` by Developer Mode so every subsystem (map, routing, proximity, AR) sees the
/// same "single location source" it does in production — nothing else knows it is simulated.
@MainActor
final class SimulatedLocationService: LocationService {
    /// Where the walker should go next and which polyline to follow. Re-read on every tick so the
    /// simulation follows re-routes and destination changes automatically.
    struct Route {
        var path: [GeoCoordinate]
        var target: GeoCoordinate
    }

    private let broadcaster = EventBroadcaster<LocationEvent>()
    private var simulator = WalkSimulator()
    private var walkTask: Task<Void, Never>?
    private var isRunning = false

    private(set) var position: GeoCoordinate
    private(set) var course: Double?
    private(set) var isWalking = false
    /// Reported GPS accuracy; raise it to exercise the "weak GPS" handling.
    var horizontalAccuracy: Double = 5 {
        didSet { if isRunning { publishLocation() } }
    }
    /// 1 = real walking pace (1.4 m/s). Higher values shorten test loops.
    var speedMultiplier: Double = 1 {
        didSet { simulator.metersPerSecond = WalkingRoute.defaultWalkingSpeed * max(0.1, speedMultiplier) }
    }
    /// Set by the owner; called each tick.
    var routeProvider: (() -> Route?)?

    static let tickInterval: TimeInterval = 0.5

    init(start: GeoCoordinate) {
        position = start
    }

    // MARK: LocationService

    var authorization: LocationAuthorization { .authorized }
    var isPreciseLocationAuthorized: Bool { true }
    var isHeadingAvailable: Bool { true }

    func events() -> AsyncStream<LocationEvent> { broadcaster.stream() }

    func requestWhenInUseAuthorization() {}
    func requestTemporaryPreciseLocationIfNeeded() {}

    func start() {
        guard !isRunning else { return }
        isRunning = true
        broadcaster.send(.authorization(.authorized, precise: true))
        publishLocation()
        publishHeading()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        stopWalking()
    }

    // MARK: Controls

    /// Instantly relocates the walker (e.g. "jump to next stop").
    func teleport(to coordinate: GeoCoordinate) {
        stopWalking()
        position = coordinate
        course = nil
        publishLocation()
    }

    /// Advances one step toward the target without starting continuous walking.
    func nudge(meters: Double) {
        guard let route = routeProvider?() else { return }
        let seconds = meters / max(simulator.metersPerSecond, 0.01)
        apply(simulator.step(from: position, along: route.path, toward: route.target, deltaTime: seconds))
    }

    func startWalking() {
        guard !isWalking else { return }
        isWalking = true
        walkTask = Task { @MainActor [weak self] in
            var last = Date()
            while let self, !Task.isCancelled, self.isWalking {
                try? await Task.sleep(for: .milliseconds(Int(SimulatedLocationService.tickInterval * 1000)))
                guard !Task.isCancelled, self.isWalking else { break }
                let now = Date()
                let dt = now.timeIntervalSince(last)
                last = now
                guard let route = self.routeProvider?() else { continue }
                let sample = self.simulator.step(from: self.position, along: route.path, toward: route.target, deltaTime: dt)
                self.apply(sample)
                if sample.didArrive { self.isWalking = false }
            }
            self?.isWalking = false
        }
    }

    func stopWalking() {
        isWalking = false
        walkTask?.cancel()
        walkTask = nil
    }

    // MARK: Publishing

    private func apply(_ sample: WalkSimulator.Sample) {
        position = sample.coordinate
        if let c = sample.course { course = c }
        publishLocation()
        publishHeading()
    }

    private func publishLocation() {
        guard isRunning else { return }
        broadcaster.send(.location(LocationSample(
            coordinate: position,
            horizontalAccuracy: horizontalAccuracy,
            course: course,
            speed: isWalking ? simulator.metersPerSecond : 0,
            altitude: nil,
            timestamp: Date(),
            isSimulated: true
        )))
    }

    private func publishHeading() {
        guard isRunning, let course else { return }
        broadcaster.send(.heading(HeadingSample(trueHeading: course, magneticHeading: course, accuracy: 5, isSimulated: true)))
    }
}
