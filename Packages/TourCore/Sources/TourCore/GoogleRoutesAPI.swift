import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Wire types for Google **Routes API** `computeRoutes` (the current replacement for the legacy
/// Directions API, which became Legacy on 2025-03-01 and is unavailable to new Cloud projects).
///
/// Endpoint: `POST https://routes.googleapis.com/directions/v2:computeRoutes`
/// Required headers: `Content-Type: application/json`, `X-Goog-Api-Key`, `X-Goog-FieldMask`.
/// For `travelMode: WALK` the `routingPreference` field must be omitted.
public enum GoogleRoutesAPI {
    public static let endpoint = URL(string: "https://routes.googleapis.com/directions/v2:computeRoutes")!

    /// POST `computeRoutes` with the iOS bundle id always set (never empty).
    public static func makeURLRequest(
        apiKey: String,
        bundleIdentifier: String?,
        origin: GeoCoordinate,
        destination: GeoCoordinate,
        timeout: TimeInterval = 15
    ) throws -> URLRequest {
        let bundleID = GoogleAPIClientIdentity.resolvedIOSBundleIdentifier(bundleIdentifier)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(fieldMask, forHTTPHeaderField: "X-Goog-FieldMask")
        request.setValue(bundleID, forHTTPHeaderField: GoogleAPIClientIdentity.iosBundleIdentifierHeader)
        request.httpBody = try Request(origin: origin, destination: destination).encoded()
        return request
    }

    /// Minimal field mask that still yields geometry and step instructions.
    public static let fieldMask = [
        "routes.distanceMeters",
        "routes.duration",
        "routes.staticDuration",
        "routes.polyline.encodedPolyline",
        "routes.legs.distanceMeters",
        "routes.legs.duration",
        "routes.legs.staticDuration",
        "routes.legs.steps.distanceMeters",
        "routes.legs.steps.staticDuration",
        "routes.legs.steps.polyline.encodedPolyline",
        "routes.legs.steps.startLocation",
        "routes.legs.steps.endLocation",
        "routes.legs.steps.navigationInstruction"
    ].joined(separator: ",")

    // MARK: Request

    public struct LatLng: Codable, Sendable, Equatable {
        public var latitude: Double
        public var longitude: Double
        public init(_ c: GeoCoordinate) { latitude = c.latitude; longitude = c.longitude }
        public var coordinate: GeoCoordinate { GeoCoordinate(latitude: latitude, longitude: longitude) }
    }

    public struct Location: Codable, Sendable, Equatable {
        public var latLng: LatLng
        public var heading: Int?
        public init(latLng: LatLng, heading: Int? = nil) { self.latLng = latLng; self.heading = heading }
    }

    public struct Waypoint: Codable, Sendable, Equatable {
        public var location: Location
        public init(_ c: GeoCoordinate) { location = Location(latLng: LatLng(c)) }
    }

    public struct Request: Codable, Sendable, Equatable {
        public var origin: Waypoint
        public var destination: Waypoint
        public var travelMode: String
        public var polylineQuality: String
        public var computeAlternativeRoutes: Bool
        public var languageCode: String
        public var units: String

        public init(origin: GeoCoordinate, destination: GeoCoordinate, languageCode: String = "en-US", units: String = "IMPERIAL") {
            self.origin = Waypoint(origin)
            self.destination = Waypoint(destination)
            self.travelMode = "WALK"
            self.polylineQuality = "HIGH_QUALITY"
            self.computeAlternativeRoutes = false
            self.languageCode = languageCode
            self.units = units
        }

        public func encoded() throws -> Data {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return try encoder.encode(self)
        }
    }

    // MARK: Response

    public struct Polyline: Codable, Sendable, Equatable {
        public var encodedPolyline: String?
    }

    public struct NavigationInstruction: Codable, Sendable, Equatable {
        public var maneuver: String?
        public var instructions: String?
    }

    public struct Step: Codable, Sendable, Equatable {
        public var distanceMeters: Double?
        public var staticDuration: String?
        public var polyline: Polyline?
        public var startLocation: Location?
        public var endLocation: Location?
        public var navigationInstruction: NavigationInstruction?
    }

    public struct Leg: Codable, Sendable, Equatable {
        public var distanceMeters: Double?
        public var duration: String?
        public var staticDuration: String?
        public var steps: [Step]?
    }

    public struct Route: Codable, Sendable, Equatable {
        public var distanceMeters: Double?
        public var duration: String?
        public var staticDuration: String?
        public var polyline: Polyline?
        public var legs: [Leg]?
    }

    public struct Response: Codable, Sendable, Equatable {
        public var routes: [Route]?
    }

    /// Google API error envelope: `{"error": {"code": 403, "message": "...", "status": "PERMISSION_DENIED"}}`.
    public struct ErrorEnvelope: Codable, Sendable, Equatable {
        public struct Detail: Codable, Sendable, Equatable {
            public var code: Int?
            public var message: String?
            public var status: String?
        }
        public var error: Detail
    }

    public enum ParseError: Error, Equatable, LocalizedError {
        case noRoutes
        case missingGeometry
        case api(code: Int?, status: String?, message: String?)

        public var errorDescription: String? {
            switch self {
            case .noRoutes: return "Google returned no walking route between these points."
            case .missingGeometry: return "Google returned a route without geometry."
            case .api(let code, let status, let message):
                return "Routes API error \(code.map(String.init) ?? "")\(status.map { " \($0)" } ?? ""): \(message ?? "unknown")"
            }
        }
    }

    /// Parses `"165s"` / `"3.5s"` into seconds.
    public static func seconds(fromDuration text: String?) -> TimeInterval? {
        guard var text, !text.isEmpty else { return nil }
        if text.hasSuffix("s") { text.removeLast() }
        return TimeInterval(text)
    }

    /// Turns a successful response into the app's `WalkingRoute`.
    public static func walkingRoute(from data: Data, origin: GeoCoordinate, destination: GeoCoordinate, now: Date = Date()) throws -> WalkingRoute {
        let decoder = JSONDecoder()
        if let envelope = try? decoder.decode(ErrorEnvelope.self, from: data) {
            throw ParseError.api(code: envelope.error.code, status: envelope.error.status, message: envelope.error.message)
        }
        let response = try decoder.decode(Response.self, from: data)
        guard let route = response.routes?.first else { throw ParseError.noRoutes }

        let steps: [RouteStep] = (route.legs ?? []).flatMap { leg -> [RouteStep] in
            (leg.steps ?? []).compactMap { step in
                let coords = step.polyline?.encodedPolyline.map(TourCore.Polyline.decode) ?? []
                guard let start = step.startLocation?.latLng.coordinate ?? coords.first,
                      let end = step.endLocation?.latLng.coordinate ?? coords.last else { return nil }
                return RouteStep(
                    distanceMeters: step.distanceMeters ?? GeoMath.distance(from: start, to: end),
                    durationSeconds: seconds(fromDuration: step.staticDuration) ?? 0,
                    startCoordinate: start,
                    endCoordinate: end,
                    instruction: step.navigationInstruction?.instructions,
                    maneuver: step.navigationInstruction?.maneuver,
                    coordinates: coords
                )
            }
        }

        var coordinates = route.polyline?.encodedPolyline.map(TourCore.Polyline.decode) ?? []
        if coordinates.count < 2 {
            coordinates = steps.flatMap(\.coordinates)
        }
        guard coordinates.count >= 2 else { throw ParseError.missingGeometry }

        let distance = route.distanceMeters ?? steps.reduce(0) { $0 + $1.distanceMeters }
        let duration = seconds(fromDuration: route.duration)
            ?? seconds(fromDuration: route.staticDuration)
            ?? steps.reduce(0) { $0 + $1.durationSeconds }

        return WalkingRoute(
            origin: origin,
            destination: destination,
            distanceMeters: distance,
            durationSeconds: duration > 0 ? duration : distance / WalkingRoute.defaultWalkingSpeed,
            routeCoordinates: coordinates,
            routeSteps: steps,
            source: .googleRoutesAPI,
            computedAt: now
        )
    }
}

/// Wire types for the **legacy** Directions API (`GET https://maps.googleapis.com/maps/api/directions/json`).
/// Only usable by Cloud projects that already had the Directions API enabled before 2025-03-01.
public enum GoogleDirectionsLegacyAPI {
    public struct Response: Codable, Sendable {
        public struct Route: Codable, Sendable {
            public struct OverviewPolyline: Codable, Sendable { public var points: String? }
            public struct Leg: Codable, Sendable {
                public struct Value: Codable, Sendable { public var value: Double?; public var text: String? }
                public struct LatLng: Codable, Sendable {
                    public var lat: Double; public var lng: Double
                    public var coordinate: GeoCoordinate { GeoCoordinate(latitude: lat, longitude: lng) }
                }
                public struct Step: Codable, Sendable {
                    public var distance: Value?
                    public var duration: Value?
                    public var startLocation: LatLng?
                    public var endLocation: LatLng?
                    public var htmlInstructions: String?
                    public var maneuver: String?
                    public var polyline: OverviewPolyline?
                    enum CodingKeys: String, CodingKey {
                        case distance, duration, maneuver, polyline
                        case startLocation = "start_location"
                        case endLocation = "end_location"
                        case htmlInstructions = "html_instructions"
                    }
                }
                public var distance: Value?
                public var duration: Value?
                public var steps: [Step]?
            }
            public var overviewPolyline: OverviewPolyline?
            public var legs: [Leg]?
            enum CodingKeys: String, CodingKey {
                case legs
                case overviewPolyline = "overview_polyline"
            }
        }
        public var status: String?
        public var errorMessage: String?
        public var routes: [Route]?
        enum CodingKeys: String, CodingKey {
            case status, routes
            case errorMessage = "error_message"
        }
    }

    public enum ParseError: Error, Equatable, LocalizedError {
        case status(String, message: String?)
        case noRoutes
        public var errorDescription: String? {
            switch self {
            case .status(let s, let m): return "Directions API status \(s): \(m ?? "")"
            case .noRoutes: return "Directions API returned no routes."
            }
        }
    }

    public static func walkingRoute(from data: Data, origin: GeoCoordinate, destination: GeoCoordinate, now: Date = Date()) throws -> WalkingRoute {
        let response = try JSONDecoder().decode(Response.self, from: data)
        if let status = response.status, status != "OK" {
            throw ParseError.status(status, message: response.errorMessage)
        }
        guard let route = response.routes?.first, let leg = route.legs?.first else { throw ParseError.noRoutes }
        let steps: [RouteStep] = (leg.steps ?? []).compactMap { step in
            guard let s = step.startLocation?.coordinate, let e = step.endLocation?.coordinate else { return nil }
            return RouteStep(
                distanceMeters: step.distance?.value ?? GeoMath.distance(from: s, to: e),
                durationSeconds: step.duration?.value ?? 0,
                startCoordinate: s,
                endCoordinate: e,
                instruction: step.htmlInstructions?.strippingHTMLTags(),
                maneuver: step.maneuver,
                coordinates: step.polyline?.points.map(Polyline.decode) ?? []
            )
        }
        var coordinates = route.overviewPolyline?.points.map(Polyline.decode) ?? []
        if coordinates.count < 2 { coordinates = steps.flatMap(\.coordinates) }
        guard coordinates.count >= 2 else { throw ParseError.noRoutes }
        let distance = leg.distance?.value ?? steps.reduce(0) { $0 + $1.distanceMeters }
        let duration = leg.duration?.value ?? steps.reduce(0) { $0 + $1.durationSeconds }
        return WalkingRoute(
            origin: origin,
            destination: destination,
            distanceMeters: distance,
            durationSeconds: duration,
            routeCoordinates: coordinates,
            routeSteps: steps,
            source: .googleDirectionsLegacy,
            computedAt: now
        )
    }
}

extension String {
    /// Removes `<b>`, `<div ...>` etc. from legacy `html_instructions`.
    func strippingHTMLTags() -> String {
        var result = ""
        var insideTag = false
        for ch in self {
            if ch == "<" { insideTag = true; continue }
            if ch == ">" { insideTag = false; result.append(" "); continue }
            if !insideTag { result.append(ch) }
        }
        return result.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}
