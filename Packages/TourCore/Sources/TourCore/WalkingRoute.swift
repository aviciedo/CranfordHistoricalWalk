import Foundation

/// Where a `WalkingRoute` came from. Lets the UI label estimates honestly.
public enum RouteSource: String, Codable, Sendable {
    case googleRoutesAPI
    case googleDirectionsLegacy
    /// Haversine fallback used only when no routing provider is reachable.
    case straightLineEstimate
    case simulated
}

/// One navigation instruction worth of route.
public struct RouteStep: Hashable, Codable, Sendable {
    public var distanceMeters: Double
    public var durationSeconds: TimeInterval
    public var startCoordinate: GeoCoordinate
    public var endCoordinate: GeoCoordinate
    public var instruction: String?
    /// Raw maneuver identifier from the provider (e.g. "TURN_LEFT"). Not interpreted by TourCore.
    public var maneuver: String?
    public var coordinates: [GeoCoordinate]

    public init(
        distanceMeters: Double,
        durationSeconds: TimeInterval,
        startCoordinate: GeoCoordinate,
        endCoordinate: GeoCoordinate,
        instruction: String? = nil,
        maneuver: String? = nil,
        coordinates: [GeoCoordinate] = []
    ) {
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.startCoordinate = startCoordinate
        self.endCoordinate = endCoordinate
        self.instruction = instruction
        self.maneuver = maneuver
        self.coordinates = coordinates
    }
}

/// A walking route between two points (spec §18).
public struct WalkingRoute: Hashable, Codable, Sendable {
    public var origin: GeoCoordinate
    public var destination: GeoCoordinate
    public var distanceMeters: Double
    public var durationSeconds: TimeInterval
    public var routeCoordinates: [GeoCoordinate]
    public var routeSteps: [RouteStep]
    public var source: RouteSource
    public var computedAt: Date

    public init(
        origin: GeoCoordinate,
        destination: GeoCoordinate,
        distanceMeters: Double,
        durationSeconds: TimeInterval,
        routeCoordinates: [GeoCoordinate],
        routeSteps: [RouteStep] = [],
        source: RouteSource,
        computedAt: Date = Date()
    ) {
        self.origin = origin
        self.destination = destination
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.routeCoordinates = routeCoordinates
        self.routeSteps = routeSteps
        self.source = source
        self.computedAt = computedAt
    }

    /// Average speed implied by the provider; falls back to a typical 1.4 m/s walking pace.
    public var metersPerSecond: Double {
        guard durationSeconds > 0, distanceMeters > 0 else { return WalkingRoute.defaultWalkingSpeed }
        return distanceMeters / durationSeconds
    }

    public static let defaultWalkingSpeed: Double = 1.4

    /// Straight-line fallback used when every routing provider failed (spec §21).
    /// Clearly tagged so the UI can say "estimate".
    public static func straightLineEstimate(from origin: GeoCoordinate, to destination: GeoCoordinate, at date: Date = Date()) -> WalkingRoute {
        let meters = GeoMath.distance(from: origin, to: destination)
        // Streets rarely allow a straight path; 1.3x is a conservative detour factor.
        let adjusted = meters * 1.3
        return WalkingRoute(
            origin: origin,
            destination: destination,
            distanceMeters: adjusted,
            durationSeconds: adjusted / defaultWalkingSpeed,
            routeCoordinates: [origin, destination],
            routeSteps: [RouteStep(distanceMeters: adjusted, durationSeconds: adjusted / defaultWalkingSpeed, startCoordinate: origin, endCoordinate: destination, instruction: "Head toward the stop", coordinates: [origin, destination])],
            source: .straightLineEstimate,
            computedAt: date
        )
    }
}
