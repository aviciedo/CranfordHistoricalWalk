import Foundation
import TourCore

/// Source of tour stops. The bundled JSON implementation is the MVP; a remote implementation
/// (e.g. `RemoteHistoricalStopService(baseURL:)`) only needs to conform to this protocol.
protocol HistoricalStopService: Sendable {
    func loadTour() async throws -> HistoricalTourDocument
}

enum HistoricalStopServiceError: LocalizedError {
    case resourceMissing(String)

    var errorDescription: String? {
        switch self {
        case .resourceMissing(let name): return "The tour file \(name) is missing from the app bundle."
        }
    }
}

/// Reads `Resources/historical_stops.json` from the main bundle.
struct BundledJSONHistoricalStopService: HistoricalStopService {
    var resourceName = "historical_stops"
    var bundle: Bundle = .main

    func loadTour() async throws -> HistoricalTourDocument {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw HistoricalStopServiceError.resourceMissing("\(resourceName).json")
        }
        let data = try Data(contentsOf: url)
        return try HistoricalStopDecoder.decode(data)
    }
}

/// Deterministic stops for previews and tests.
struct InMemoryHistoricalStopService: HistoricalStopService {
    var stops: [HistoricalStop]
    var tourName = "Preview Tour"

    func loadTour() async throws -> HistoricalTourDocument {
        HistoricalTourDocument(tourName: tourName, dataStatus: "SAMPLE DATA", stops: stops.sorted { $0.order < $1.order })
    }
}
