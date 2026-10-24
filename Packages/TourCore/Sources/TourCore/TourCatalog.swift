import Foundation

public struct TourCatalogIdentity: Codable, Equatable, Hashable, Sendable {
    public var tourID: String
    public var version: Int
    public init(tourID: String, version: Int = 1) { self.tourID = tourID; self.version = version }
    public static let legacy = TourCatalogIdentity(tourID: "cranford-historical-walk")
    public var isValid: Bool { !tourID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && version > 0 }
    /// Keep original device data readable without copying, deleting or importing it into another tour.
    public func storageKey(_ legacyKey: String, perRevision: Bool = false) -> String {
        if self == .legacy || (!perRevision && tourID == Self.legacy.tourID) { return legacyKey }
        let suffix = Data(tourID.utf8).base64EncodedString()
        return legacyKey + ".tour." + suffix + (perRevision ? ".v\(version)" : "")
    }
}

public struct TourRecording: Codable, Equatable, Sendable {
    public var stopID: String
    public var fileName: String
    public var duration: Double
    public var audioSHA256: String
    public var transcriptSHA256: String
    public init(stopID: String, fileName: String, duration: Double, audioSHA256: String, transcriptSHA256: String) {
        self.stopID = stopID; self.fileName = fileName; self.duration = duration
        self.audioSHA256 = audioSHA256; self.transcriptSHA256 = transcriptSHA256
    }
    public var isValid: Bool {
        !stopID.isEmpty && !fileName.isEmpty && !fileName.contains("/") && !fileName.contains("\\")
        && fileName != "." && fileName != ".." && duration.isFinite && duration > 0
        && [audioSHA256, transcriptSHA256].allSatisfy { hash in
            hash.count == 64 && hash.allSatisfy { "0123456789abcdef".contains($0) }
        }
    }
}

/// Stop identifiers are globally unique so playback and asset bookmarks remain unambiguous.
public struct TourCatalog: Sendable {
    public let tours: [HistoricalTourDocument]
    public init(tours: [HistoricalTourDocument]) throws {
        guard !tours.isEmpty, tours.allSatisfy({ $0.identity.isValid }),
              Set(tours.map { $0.identity.tourID }).count == tours.count,
              tours.allSatisfy({ !$0.stops.isEmpty }) else { throw HistoricalStopDecodingError.invalidCatalog }
        let ids = tours.flatMap { $0.stops.map(\.id) }
        guard Set(ids).count == ids.count else { throw HistoricalStopDecodingError.invalidCatalog }
        self.tours = try tours.map { try HistoricalStopDecoder.decode(JSONEncoder().encode($0)) }
    }
}
