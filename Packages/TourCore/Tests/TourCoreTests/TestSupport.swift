import Foundation
import XCTest
@testable import TourCore

enum Fixtures {
    static func data(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: name, withExtension: "json") else {
            throw NSError(domain: "Fixtures", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing fixture \(name).json"])
        }
        return try Data(contentsOf: url)
    }

    static func sampleStops() throws -> [HistoricalStop] {
        try HistoricalStopDecoder.decode(data("sample_historical_stops")).stops
    }
}

/// Cranford, NJ downtown-ish reference point used by geometry tests (not a historical claim).
let cranfordCenter = GeoCoordinate(latitude: 40.6584, longitude: -74.3035)

func makeStop(id: String = "s1", order: Int = 1, lat: Double = 40.6584, lng: Double = -74.3035, arrival: Double = 35, departure: Double? = 50) -> HistoricalStop {
    HistoricalStop(
        id: id, name: "Stop \(order)", latitude: lat, longitude: lng,
        address: "SAMPLE", shortDescription: "SAMPLE", longDescription: "SAMPLE",
        arrivalRadius: arrival, departureRadius: departure, order: order
    )
}

/// Straight route of `segments` legs heading `bearing` from `start`, `segmentMeters` each.
func makeRoute(from start: GeoCoordinate, bearing: Double, segments: Int, segmentMeters: Double, speed: Double = 1.4, source: RouteSource = .googleRoutesAPI) -> WalkingRoute {
    var points = [start]
    for _ in 0..<segments {
        points.append(GeoMath.destination(from: points.last!, bearing: bearing, distance: segmentMeters))
    }
    let total = Double(segments) * segmentMeters
    return WalkingRoute(
        origin: start,
        destination: points.last!,
        distanceMeters: total,
        durationSeconds: total / speed,
        routeCoordinates: points,
        routeSteps: [],
        source: source
    )
}
