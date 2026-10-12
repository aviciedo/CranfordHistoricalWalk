import Foundation

/// One stop on the walking tour.
///
/// The model is `Codable` so it can be loaded from the bundled `historical_stops.json`
/// today and from a remote API later without changes to consumers.
public struct HistoricalStop: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var address: String
    public var shortDescription: String
    public var longDescription: String
    /// Free-form so it can hold "1897", "c. 1890s" or a range. `nil` when unknown.
    public var historicalDate: String?
    /// Name of an image in the app's asset catalog.
    public var imageName: String?
    /// Remote historical photograph.
    public var imageURL: URL?
    /// Remote illustration / drawing.
    public var illustrationURL: URL?
    /// Optional narration.
    public var audioURL: URL?
    /// Meters. The AR sign opens when the user is within this radius.
    public var arrivalRadius: Double
    /// Meters. The AR sign closes only once the user is beyond this radius (hysteresis).
    /// When omitted from JSON a sensible default derived from `arrivalRadius` is used.
    public var departureRadius: Double?
    /// 1-based position in the tour.
    public var order: Int
    /// Seconds a visitor typically spends at the stop.
    public var estimatedVisitDuration: TimeInterval
    /// True while the stop's coordinates/content are placeholders and not verified history.
    public var isSample: Bool
    /// True when latitude/longitude came from an unverified geocode (or similar) and must not
    /// be treated as a surveyed historical-site position.
    public var coordinatesUnverified: Bool

    public init(
        id: String,
        name: String,
        latitude: Double,
        longitude: Double,
        address: String,
        shortDescription: String,
        longDescription: String,
        historicalDate: String? = nil,
        imageName: String? = nil,
        imageURL: URL? = nil,
        illustrationURL: URL? = nil,
        audioURL: URL? = nil,
        arrivalRadius: Double = 35,
        departureRadius: Double? = nil,
        order: Int,
        estimatedVisitDuration: TimeInterval = 90,
        isSample: Bool = false,
        coordinatesUnverified: Bool = false
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.shortDescription = shortDescription
        self.longDescription = longDescription
        self.historicalDate = historicalDate
        self.imageName = imageName
        self.imageURL = imageURL
        self.illustrationURL = illustrationURL
        self.audioURL = audioURL
        self.arrivalRadius = arrivalRadius
        self.departureRadius = departureRadius
        self.order = order
        self.estimatedVisitDuration = estimatedVisitDuration
        self.isSample = isSample
        self.coordinatesUnverified = coordinatesUnverified
    }

    public var coordinate: GeoCoordinate {
        GeoCoordinate(latitude: latitude, longitude: longitude)
    }

    /// Effective close radius: explicit value, else `arrivalRadius + 15 m` with a 50 m floor
    /// relative to the default 35 m arrival radius (spec §9: open at 35 m, close beyond 50 m).
    public var effectiveDepartureRadius: Double {
        if let departureRadius, departureRadius > arrivalRadius {
            return departureRadius
        }
        return max(arrivalRadius + 15, arrivalRadius * 1.4)
    }

    public var hasAnyImage: Bool {
        imageName != nil || imageURL != nil || illustrationURL != nil
    }

    /// Where narration for this stop comes from, in order of preference:
    /// a remote/bundled audio file (`audioURL`), else the description read aloud by speech synthesis.
    public enum NarrationSource: Equatable, Sendable {
        /// `audioURL` with an `http(s)` or `file` scheme.
        case remoteAudio(URL)
        /// `audioURL` given as a bare file name (e.g. `"droeschers-mill.m4a"`), bundled with the app.
        case bundledAudio(fileName: String)
        /// No recording; `text` is spoken by the system voice.
        case synthesizedSpeech(text: String)
    }

    public var narrationSource: NarrationSource? {
        if let audioURL {
            switch audioURL.scheme?.lowercased() {
            case "http", "https", "file":
                return .remoteAudio(audioURL)
            case nil, "":
                let name = audioURL.lastPathComponent
                if !name.isEmpty, name != "/" { return .bundledAudio(fileName: name) }
            default:
                break
            }
        }
        let text = longDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { return .synthesizedSpeech(text: text) }
        let short = shortDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return short.isEmpty ? nil : .synthesizedSpeech(text: short)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, address, shortDescription, longDescription
        case historicalDate, imageName, imageURL, illustrationURL, audioURL
        case arrivalRadius, departureRadius, order, estimatedVisitDuration, isSample
        case coordinatesUnverified
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        latitude = try c.decode(Double.self, forKey: .latitude)
        longitude = try c.decode(Double.self, forKey: .longitude)
        address = try c.decodeIfPresent(String.self, forKey: .address) ?? "Cranford, NJ"
        shortDescription = try c.decodeIfPresent(String.self, forKey: .shortDescription) ?? ""
        longDescription = try c.decodeIfPresent(String.self, forKey: .longDescription) ?? ""
        historicalDate = try c.decodeIfPresent(String.self, forKey: .historicalDate)
        imageName = try c.decodeIfPresent(String.self, forKey: .imageName)
        imageURL = try c.decodeIfPresent(URL.self, forKey: .imageURL)
        illustrationURL = try c.decodeIfPresent(URL.self, forKey: .illustrationURL)
        audioURL = try c.decodeIfPresent(URL.self, forKey: .audioURL)
        arrivalRadius = try c.decodeIfPresent(Double.self, forKey: .arrivalRadius) ?? 35
        departureRadius = try c.decodeIfPresent(Double.self, forKey: .departureRadius)
        order = try c.decode(Int.self, forKey: .order)
        estimatedVisitDuration = try c.decodeIfPresent(TimeInterval.self, forKey: .estimatedVisitDuration) ?? 90
        isSample = try c.decodeIfPresent(Bool.self, forKey: .isSample) ?? false
        coordinatesUnverified = try c.decodeIfPresent(Bool.self, forKey: .coordinatesUnverified) ?? false
    }
}

/// Top-level document stored in `Resources/historical_stops.json`.
public struct HistoricalTourDocument: Codable, Sendable {
    public var schemaVersion: Int
    public var tourName: String
    public var tourSubtitle: String?
    public var dataStatus: String?
    public var stops: [HistoricalStop]

    public init(schemaVersion: Int = 1, tourName: String, tourSubtitle: String? = nil, dataStatus: String? = nil, stops: [HistoricalStop]) {
        self.schemaVersion = schemaVersion
        self.tourName = tourName
        self.tourSubtitle = tourSubtitle
        self.dataStatus = dataStatus
        self.stops = stops
    }
}

public enum HistoricalStopDecodingError: Error, Equatable, LocalizedError {
    case emptyTour
    case duplicateIdentifiers([String])
    case invalidCoordinate(stopID: String)

    public var errorDescription: String? {
        switch self {
        case .emptyTour: return "The tour file contains no stops."
        case .duplicateIdentifiers(let ids): return "Duplicate stop identifiers: \(ids.joined(separator: ", "))."
        case .invalidCoordinate(let id): return "Stop \(id) has an invalid coordinate."
        }
    }
}

public enum HistoricalStopDecoder {
    /// Decodes and validates a tour document, returning stops sorted by `order`.
    public static func decode(_ data: Data) throws -> HistoricalTourDocument {
        let decoder = JSONDecoder()
        var document = try decoder.decode(HistoricalTourDocument.self, from: data)
        guard !document.stops.isEmpty else { throw HistoricalStopDecodingError.emptyTour }

        var seen = Set<String>()
        var duplicates: [String] = []
        for stop in document.stops {
            if !seen.insert(stop.id).inserted { duplicates.append(stop.id) }
            guard stop.coordinate.isValid else {
                throw HistoricalStopDecodingError.invalidCoordinate(stopID: stop.id)
            }
        }
        if !duplicates.isEmpty { throw HistoricalStopDecodingError.duplicateIdentifiers(duplicates) }

        document.stops.sort { ($0.order, $0.id) < ($1.order, $1.id) }
        return document
    }
}
