import CoreLocation
import Foundation
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
/// user stands still (or reopening the AR view) cost nothing. The TTL, coalescing, and eviction
/// live in `DirectionsRouteCache` so they can be unit-tested without Core Location.
actor CachedDirectionsService: DirectionsService {
    private let upstream: any DirectionsService
    private let cache: DirectionsRouteCache

    init(upstream: any DirectionsService, ttl: TimeInterval = DirectionsRouteCache.defaultTTL) {
        self.upstream = upstream
        self.cache = DirectionsRouteCache(ttl: ttl)
    }

    func walkingRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> WalkingRoute {
        let upstream = self.upstream
        let originLatitude = origin.latitude
        let originLongitude = origin.longitude
        let destinationLatitude = destination.latitude
        let destinationLongitude = destination.longitude
        return try await cache.route(
            from: GeoCoordinate(latitude: originLatitude, longitude: originLongitude),
            to: GeoCoordinate(latitude: destinationLatitude, longitude: destinationLongitude)
        ) {
            try await upstream.walkingRoute(
                from: CLLocationCoordinate2D(latitude: originLatitude, longitude: originLongitude),
                to: CLLocationCoordinate2D(latitude: destinationLatitude, longitude: destinationLongitude)
            )
        }
    }
}

// MARK: - Factory

enum DirectionsServiceFactory {
    static func make(configuration: AppConfiguration) -> any DirectionsService {
        let upstream: any DirectionsService
        let bundleID = AppConfiguration.iosBundleIdentifier()
        switch configuration.directionsProvider {
        case .routes: upstream = GoogleRoutesDirectionsService(apiKey: configuration.googleRoutesAPIKey, bundleIdentifier: bundleID)
        case .legacy: upstream = LegacyGoogleDirectionsService(apiKey: configuration.googleRoutesAPIKey, bundleIdentifier: bundleID)
        }
        return CachedDirectionsService(upstream: upstream)
    }
}
