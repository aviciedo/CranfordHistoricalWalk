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
/// select the phone's voice or old remote audio for these stops. Validate bundled bytes
/// against the selected catalog; unavailable narration never blocks walking or reading.
enum ProducedNarrationRelease {
    static let identifier = "cedar-2"
    typealias Recording = TourRecording
    /// Compatibility lookup for the shipped catalog and its existing narration bookmarks.
    static let recordings: [Recording] = {
        guard let url = Bundle.main.url(forResource: "historical_stops", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let document = try? HistoricalStopDecoder.decode(data) else { return [] }
        return document.recordings ?? []
    }()

    static func recording(for stopID: String) -> Recording? {
        recordings.first { $0.stopID == stopID }
    }

    static func recording(for stop: HistoricalStop) -> Recording? {
        guard stop.catalogID == nil || stop.catalogID == TourCatalogIdentity.legacy.tourID else { return nil }
        return recording(for: stop.id)
    }

    static func source(for stop: HistoricalStop) -> HistoricalStop.NarrationSource? {
        guard !stop.narrationPending else { return nil }
        if stop.narrationAudioSHA256 != nil { return stop.narrationSource }
        if let recording = recording(for: stop) {
            return .bundledAudio(fileName: recording.fileName)
        }
        return stop.narrationSource
    }

    static func install(in document: inout HistoricalTourDocument, bundle: Bundle) throws {
        for index in document.stops.indices { document.stops[index].narrationAudioSHA256 = nil }
        for recording in document.recordings ?? [] {
            guard let index = document.stops.firstIndex(where: { $0.id == recording.stopID }),
                  let url = bundle.url(forResource: recording.fileName, withExtension: nil),
                  let bytes = try? Data(contentsOf: url),
                  digest(bytes) == recording.audioSHA256,
                  let transcript = document.stops[index].narrationText,
                  digest(Data(transcript.utf8)) == recording.transcriptSHA256 else {
                // A missing recording must not disable otherwise valid map/story content.
                if let index = document.stops.firstIndex(where: { $0.id == recording.stopID }) {
                    document.stops[index].audioURL = nil
                    document.stops[index].narrationPending = true
                }
                continue
            }
            document.stops[index].narrationPending = false
            document.stops[index].narrationAudioSHA256 = recording.audioSHA256
            document.stops[index].audioURL = URL(string: recording.fileName)
            document.stops[index].estimatedVisitDuration = recording.duration
        }
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
