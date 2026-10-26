import CoreLocation
import Foundation
import MapKit
import TourCore

/// Walking directions provider (spec §18).
protocol DirectionsService: Sendable {
    func walkingRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> WalkingRoute
}

enum DirectionsError: LocalizedError, Equatable {
    case missingAPIKey
    case offline
    case timedOut
    case network(String)
    case http(status: Int, message: String?)
    case api(String)
    case noRoute
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "No Routes API key is configured, so walking distances are estimates."
        case .offline: return "You're offline. Showing the last known route."
        case .timedOut: return "Directions took too long. Showing the last known route."
        case .network(let text): return "Network problem while routing: \(text)"
        case .http(let status, let message): return "Directions request failed (HTTP \(status))\(message.map { ": \($0)" } ?? "")."
        case .api(let text): return text
        case .noRoute: return "No walking route was found to this stop."
        case .invalidResponse: return "Directions returned an unexpected response."
        }
    }

    init(urlError: URLError) {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
            self = .offline
        case .timedOut:
            self = .timedOut
        default:
            self = .network(urlError.localizedDescription)
        }
    }

    /// Maps a Google error envelope onto copy the tour UI can show without crashing.
    static func fromRoutesAPI(code: Int?, status: String?, message: String?, bundleIdentifier: String) -> DirectionsError {
        .api(GoogleAPIClientIdentity.userFacingRoutesError(code: code, status: status, message: message, bundleIdentifier: bundleIdentifier))
    }
}

// MARK: - Google Routes API (current)

/// `POST https://routes.googleapis.com/directions/v2:computeRoutes` with `travelMode: WALK`.
/// Request/response shapes and the field mask live in `TourCore.GoogleRoutesAPI` so they are unit-tested.
struct GoogleRoutesDirectionsService: DirectionsService {
    let apiKey: String
    var bundleIdentifier: String
    var session: URLSession = .shared
    var timeout: TimeInterval = 15

    init(apiKey: String, bundleIdentifier: String = AppConfiguration.iosBundleIdentifier(), session: URLSession = .shared, timeout: TimeInterval = 15) {
        self.apiKey = apiKey
        self.bundleIdentifier = GoogleAPIClientIdentity.resolvedIOSBundleIdentifier(bundleIdentifier)
        self.session = session
        self.timeout = timeout
    }

    func walkingRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> WalkingRoute {
        guard AppConfiguration.looksLikeKey(apiKey) else { throw DirectionsError.missingAPIKey }
        let o = GeoCoordinate(origin), d = GeoCoordinate(destination)
        let request = try GoogleRoutesAPI.makeURLRequest(
            apiKey: apiKey,
            bundleIdentifier: bundleIdentifier,
            origin: o,
            destination: d,
            timeout: timeout
        )

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw DirectionsError(urlError: error)
        }

        do {
            return try GoogleRoutesAPI.walkingRoute(from: data, origin: o, destination: d)
        } catch let error as GoogleRoutesAPI.ParseError {
            switch error {
            case .noRoutes: throw DirectionsError.noRoute
            case .missingGeometry: throw DirectionsError.invalidResponse
            case .api(let code, let status, let message):
                throw DirectionsError.fromRoutesAPI(code: code ?? (response as? HTTPURLResponse)?.statusCode, status: status, message: message, bundleIdentifier: bundleIdentifier)
            }
        } catch {
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw DirectionsError.http(status: http.statusCode, message: nil)
            }
            throw DirectionsError.invalidResponse
        }
    }
}

// MARK: - Legacy Directions API (only for Cloud projects that still have it enabled)

struct LegacyGoogleDirectionsService: DirectionsService {
    let apiKey: String
    var bundleIdentifier: String
    var session: URLSession = .shared
    var timeout: TimeInterval = 15

    init(apiKey: String, bundleIdentifier: String = AppConfiguration.iosBundleIdentifier(), session: URLSession = .shared, timeout: TimeInterval = 15) {
        self.apiKey = apiKey
        self.bundleIdentifier = GoogleAPIClientIdentity.resolvedIOSBundleIdentifier(bundleIdentifier)
        self.session = session
        self.timeout = timeout
    }

    func walkingRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> WalkingRoute {
        guard AppConfiguration.looksLikeKey(apiKey) else { throw DirectionsError.missingAPIKey }
        let o = GeoCoordinate(origin), d = GeoCoordinate(destination)
        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/directions/json")!
        components.queryItems = [
            URLQueryItem(name: "origin", value: "\(o.latitude),\(o.longitude)"),
            URLQueryItem(name: "destination", value: "\(d.latitude),\(d.longitude)"),
            URLQueryItem(name: "mode", value: "walking"),
            URLQueryItem(name: "units", value: "imperial"),
            URLQueryItem(name: "key", value: apiKey)
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = timeout
        request.setValue(bundleIdentifier, forHTTPHeaderField: GoogleAPIClientIdentity.iosBundleIdentifierHeader)
        let (data, _): (Data, URLResponse)
        do {
            (data, _) = try await session.data(for: request)
        } catch let error as URLError {
            throw DirectionsError(urlError: error)
        }
        do {
            return try GoogleDirectionsLegacyAPI.walkingRoute(from: data, origin: o, destination: d)
        } catch let error as GoogleDirectionsLegacyAPI.ParseError {
            switch error {
            case .noRoutes: throw DirectionsError.noRoute
            case .status(let status, let message):
                throw DirectionsError.fromRoutesAPI(code: nil, status: status, message: message, bundleIdentifier: bundleIdentifier)
            }
        } catch {
            throw DirectionsError.invalidResponse
        }
    }
}

// MARK: - Small cache decorator (spec §22: do not continuously make network requests)

/// Remembers routes for ~10 m origin/destination cells for a few minutes so re-requests while the
/// user stands still (or reopening the AR view) cost nothing.
actor CachedDirectionsService: DirectionsService {
    private struct Key: Hashable {
        let olat: Int, olng: Int, dlat: Int, dlng: Int
        init(_ o: CLLocationCoordinate2D, _ d: CLLocationCoordinate2D) {
            // ~0.0001° ≈ 11 m latitude.
            olat = Int((o.latitude * 10_000).rounded()); olng = Int((o.longitude * 10_000).rounded())
            dlat = Int((d.latitude * 10_000).rounded()); dlng = Int((d.longitude * 10_000).rounded())
        }
    }

    private let upstream: any DirectionsService
    private let ttl: TimeInterval
    private var cache: [Key: WalkingRoute] = [:]
    private var inFlight: [Key: Task<WalkingRoute, Error>] = [:]

    init(upstream: any DirectionsService, ttl: TimeInterval = 300) {
        self.upstream = upstream
        self.ttl = ttl
    }

    func walkingRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> WalkingRoute {
        let key = Key(origin, destination)
        if let cached = cache[key], Date().timeIntervalSince(cached.computedAt) < ttl {
            return cached
        }
        if let task = inFlight[key] {
            return try await task.value
        }
        let upstream = self.upstream
        let task = Task { try await upstream.walkingRoute(from: origin, to: destination) }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        let route = try await task.value
        cache[key] = route
        if cache.count > 64 {
            // Drop the oldest entries; the tour has at most a handful of live legs.
            let sorted = cache.sorted { $0.value.computedAt < $1.value.computedAt }
            for (k, _) in sorted.prefix(cache.count - 48) { cache[k] = nil }
        }
        return route
    }
}

// MARK: - Apple walking routes and provider fallback

/// Real street/path geometry; never substitutes a straight line for a walking route.
struct AppleWalkingDirectionsService: DirectionsService {
    func walkingRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> WalkingRoute {
        try Task.checkCancellation()
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .walking
        request.requestsAlternateRoutes = false
        let directions = MKDirections(request: request)
        let response = try await directions.calculate()
        try Task.checkCancellation()
        guard let route = response.routes.first else { throw DirectionsError.noRoute }
        let geometry = coordinates(of: route.polyline)
        guard geometry.count >= 2 else { throw DirectionsError.invalidResponse }
        let steps = route.steps.compactMap { step -> RouteStep? in
            let points = coordinates(of: step.polyline)
            guard let start = points.first, let end = points.last, step.distance > 0 else { return nil }
            return RouteStep(distanceMeters: step.distance,
                durationSeconds: route.distance > 0 ? route.expectedTravelTime * step.distance / route.distance : 0,
                startCoordinate: start, endCoordinate: end,
                instruction: step.instructions.isEmpty ? nil : step.instructions, coordinates: points)
        }
        return WalkingRoute(origin: GeoCoordinate(origin), destination: GeoCoordinate(destination),
            distanceMeters: route.distance, durationSeconds: route.expectedTravelTime,
            routeCoordinates: geometry, routeSteps: steps, source: .appleMaps)
    }

    private func coordinates(of polyline: MKPolyline) -> [GeoCoordinate] {
        let points = polyline.points()
        return (0..<polyline.pointCount).map { GeoCoordinate(points[$0].coordinate) }
    }
}

/// Google remains primary when configured; failures use Apple's real walking network.
struct FallbackWalkingDirectionsService: DirectionsService {
    let primary: any DirectionsService
    let fallback: any DirectionsService

    func walkingRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> WalkingRoute {
        do { return try await primary.walkingRoute(from: origin, to: destination) }
        catch is CancellationError { throw CancellationError() }
        catch {
            try Task.checkCancellation()
            return try await fallback.walkingRoute(from: origin, to: destination)
        }
    }
}

// MARK: - Factory

enum DirectionsServiceFactory {
    /// The default remains Apple's real network; injection makes provider selection testable offline.
    static func make(configuration: AppConfiguration,
                     apple: any DirectionsService = AppleWalkingDirectionsService()) -> any DirectionsService {
        guard configuration.hasGoogleMapsKey, AppConfiguration.looksLikeKey(configuration.googleRoutesAPIKey) else {
            return CachedDirectionsService(upstream: apple)
        }
        let google: any DirectionsService
        let bundleID = AppConfiguration.iosBundleIdentifier()
        switch configuration.directionsProvider {
        case .routes: google = GoogleRoutesDirectionsService(apiKey: configuration.googleRoutesAPIKey, bundleIdentifier: bundleID)
        case .legacy: google = LegacyGoogleDirectionsService(apiKey: configuration.googleRoutesAPIKey, bundleIdentifier: bundleID)
        }
        return CachedDirectionsService(upstream: FallbackWalkingDirectionsService(primary: google, fallback: apple))
    }
}
