import CryptoKit
import Foundation
import TourCore

/// Source of tour stops. The bundled JSON implementation is the MVP; a remote implementation
/// (e.g. `RemoteHistoricalStopService(baseURL:)`) only needs to conform to this protocol.
protocol HistoricalStopService: Sendable {
    func loadTour() async throws -> HistoricalTourDocument
}

enum HistoricalStopServiceError: LocalizedError {
    case resourceMissing(String)
    case narrationReleaseMismatch(String)

    var errorDescription: String? {
        switch self {
        case .resourceMissing(let name): return "The tour file \(name) is missing from the app bundle."
        case .narrationReleaseMismatch(let name):
            return "This app has incomplete or outdated narration (\(name)). Rebuild from the complete latest download. Your visits do not need resetting."
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
        var document = try HistoricalStopDecoder.decode(data)
        try ProducedNarrationRelease.install(in: &document, bundle: bundle)
        return document
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

/// One authoritative release for the produced recordings. Legacy tour metadata must never
/// select the phone's voice or old remote audio for these stops. Validate actual bundled bytes
/// at load time; missing/stale resources are an explicit error, never a silent voice fallback.
enum ProducedNarrationRelease {
    static let identifier = "cedar-2"
    struct Recording {
        let stopID: String
        let fileName: String
        let duration: TimeInterval
        let audioSHA256: String
        let transcriptSHA256: String
    }
    static let recordings: [Recording] = [
        Recording(stopID: "hpab-001", fileName: "stop_01_droeschers_mill.mp3",
                  duration: 151.301224, audioSHA256: "197afe552a3e7be4bb100fa9eeacde4eef9cce32d7ad9aa406ccbf3575661f71",
                  transcriptSHA256: "bbf78f5a93d013b782c981d39f9139068e77760ea38da76d67ed65bd4c254454"),
        Recording(stopID: "hpab-002", fileName: "stop_02_greystone.mp3",
                  duration: 142.733061, audioSHA256: "12253f3de71fbf179b5f54a3a23298eeecc71e2175334007792930f8a96d5b1a",
                  transcriptSHA256: "e8d895c7345f9f66f9859dc16d69e2649eb1949e637b7ef36437f60c8cb6ef72"),
    ]

    static func recording(for stopID: String) -> Recording? {
        recordings.first { $0.stopID == stopID }
    }

    static func source(for stop: HistoricalStop) -> HistoricalStop.NarrationSource? {
        if let recording = recording(for: stop.id) {
            return .bundledAudio(fileName: recording.fileName)
        }
        return stop.narrationSource
    }

    static func install(in document: inout HistoricalTourDocument, bundle: Bundle) throws {
        for recording in recordings {
            guard let index = document.stops.firstIndex(where: { $0.id == recording.stopID }),
                  let url = bundle.url(forResource: recording.fileName, withExtension: nil),
                  let bytes = try? Data(contentsOf: url),
                  digest(bytes) == recording.audioSHA256,
                  let transcript = document.stops[index].narrationText,
                  digest(Data(transcript.utf8)) == recording.transcriptSHA256 else {
                throw HistoricalStopServiceError.narrationReleaseMismatch(recording.fileName)
            }
            document.stops[index].audioURL = URL(string: recording.fileName)
            document.stops[index].estimatedVisitDuration = recording.duration
        }
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
