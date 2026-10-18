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
    /// Optional WGS84 ellipsoid altitude in meters (ARCore Geospatial / `CLLocation.ellipsoidalAltitude`,
    /// **not** `CLLocation.altitude`). `nil` means “use the camera’s geospatial altitude”.
    public var altitude: Double?
    public var address: String
    public var shortDescription: String
    public var longDescription: String
    /// Free-form so it can hold "1897", "c. 1890s" or a range. `nil` when unknown.
    public var historicalDate: String?
    /// Name of an image in the app's asset catalog.
    public var imageName: String?
    /// Ordered local photographs for the detail-screen slideshow; the first is the cover.
    public var photos: [HistoricalStopPhoto]
    /// Remote historical photograph.
    public var imageURL: URL?
    /// Remote illustration / drawing.
    public var illustrationURL: URL?
    /// Optional narration.
    public var audioURL: URL?
    /// Dedicated narration/transcript. Kept separate from the concise screen description.
    public var narrationText: String?
    /// Applies only when narration is read on device; recorded audio keeps its original voice.
    public var narrationVoicePreference: NarrationVoicePreference
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
    /// Optional bronze-plaque / door-plate copy for AR image tracking. Quote this; do not treat it
    /// as extra narrative.
    public var plaque: StopPlaque?

    public init(
        id: String,
        name: String,
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        address: String,
        shortDescription: String,
        longDescription: String,
        historicalDate: String? = nil,
        imageName: String? = nil,
        photos: [HistoricalStopPhoto] = [],
        imageURL: URL? = nil,
        illustrationURL: URL? = nil,
        audioURL: URL? = nil,
        narrationText: String? = nil,
        narrationVoicePreference: NarrationVoicePreference = .systemDefault,
        arrivalRadius: Double = 35,
        departureRadius: Double? = nil,
        order: Int,
        estimatedVisitDuration: TimeInterval = 90,
        isSample: Bool = false,
        coordinatesUnverified: Bool = false,
        plaque: StopPlaque? = nil
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.address = address
        self.shortDescription = shortDescription
        self.longDescription = longDescription
        self.historicalDate = historicalDate
        self.imageName = imageName
        self.photos = photos
        self.imageURL = imageURL
        self.illustrationURL = illustrationURL
        self.audioURL = audioURL
        self.narrationText = narrationText
        self.narrationVoicePreference = narrationVoicePreference
        self.arrivalRadius = arrivalRadius
        self.departureRadius = departureRadius
        self.order = order
        self.estimatedVisitDuration = estimatedVisitDuration
        self.isSample = isSample
        self.coordinatesUnverified = coordinatesUnverified
        self.plaque = plaque
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
        !galleryPhotos.isEmpty || imageURL != nil || illustrationURL != nil
    }

    /// Ignore empty/duplicate entries while preserving editorial order and old single-photo stops.
    public var galleryPhotos: [HistoricalStopPhoto] {
        var seen = Set<String>()
        var result: [HistoricalStopPhoto] = []
        for var photo in photos {
            photo.imageName = photo.imageName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !photo.imageName.isEmpty, seen.insert(photo.imageName).inserted else { continue }
            result.append(photo)
        }
        if let name = imageName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty,
           seen.insert(name).inserted {
            result.insert(HistoricalStopPhoto(imageName: name, caption: self.name), at: 0)
        }
        return result
    }

    /// Short location popup. The longer description and narration stay in the detail screen.
    public var markerInformation: String {
        [address, historicalDate, shortDescription].compactMap { value in
            guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
            return text
        }.joined(separator: "\n\n")
    }

    /// True when this stop can be locked to a physical plate via ARKit image tracking.
    public var hasPlaqueReference: Bool {
        plaque?.isUsable == true
    }

    /// Where narration for this stop comes from, in order of preference:
    /// a recording, else the dedicated script, else the description read aloud on device.
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
        if let script = narrationText?.trimmingCharacters(in: .whitespacesAndNewlines), !script.isEmpty {
            return .synthesizedSpeech(text: script)
        }
        let text = longDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { return .synthesizedSpeech(text: text) }
        let short = shortDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return short.isEmpty ? nil : .synthesizedSpeech(text: short)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, altitude, address, shortDescription, longDescription
        case historicalDate, imageName, photos, imageURL, illustrationURL, audioURL
        case narrationText, narrationVoicePreference
        case arrivalRadius, departureRadius, order, estimatedVisitDuration, isSample
        case coordinatesUnverified, plaque
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        latitude = try c.decode(Double.self, forKey: .latitude)
        longitude = try c.decode(Double.self, forKey: .longitude)
        altitude = try c.decodeIfPresent(Double.self, forKey: .altitude)
        address = try c.decodeIfPresent(String.self, forKey: .address) ?? "Cranford, NJ"
        shortDescription = try c.decodeIfPresent(String.self, forKey: .shortDescription) ?? ""
        longDescription = try c.decodeIfPresent(String.self, forKey: .longDescription) ?? ""
        historicalDate = try c.decodeIfPresent(String.self, forKey: .historicalDate)
        imageName = try c.decodeIfPresent(String.self, forKey: .imageName)
        photos = try c.decodeIfPresent([HistoricalStopPhoto].self, forKey: .photos) ?? []
        imageURL = try c.decodeIfPresent(URL.self, forKey: .imageURL)
        illustrationURL = try c.decodeIfPresent(URL.self, forKey: .illustrationURL)
        audioURL = try c.decodeIfPresent(URL.self, forKey: .audioURL)
        narrationText = try c.decodeIfPresent(String.self, forKey: .narrationText)
        narrationVoicePreference = try c.decodeIfPresent(NarrationVoicePreference.self, forKey: .narrationVoicePreference) ?? .systemDefault
        arrivalRadius = try c.decodeIfPresent(Double.self, forKey: .arrivalRadius) ?? 35
        departureRadius = try c.decodeIfPresent(Double.self, forKey: .departureRadius)
        order = try c.decode(Int.self, forKey: .order)
        estimatedVisitDuration = try c.decodeIfPresent(TimeInterval.self, forKey: .estimatedVisitDuration) ?? 90
        isSample = try c.decodeIfPresent(Bool.self, forKey: .isSample) ?? false
        coordinatesUnverified = try c.decodeIfPresent(Bool.self, forKey: .coordinatesUnverified) ?? false
        plaque = try c.decodeIfPresent(StopPlaque.self, forKey: .plaque)
    }
}

/// A bundled photo and its reader-visible caption/credit. Photos are not AR recognition markers.
public struct HistoricalStopPhoto: Identifiable, Hashable, Codable, Sendable {
    public var imageName: String
    public var caption: String
    public var credit: String?
    public var id: String { imageName }

    public init(imageName: String, caption: String, credit: String? = nil) {
        self.imageName = imageName
        self.caption = caption
        self.credit = credit
    }
}

/// Physical door-plate / bronze-plaque copy used for AR image tracking.
///
/// `transcription` is the plate text only — not a new historical narrative.
public struct StopPlaque: Hashable, Codable, Sendable {
    /// Exact plate wording that has been read off the physical sign.
    public var transcription: String
    /// Caption shown above the quote (for example "Door plaque").
    public var quoteLabel: String
    /// `ARReferenceImage` name inside the `PlaqueAnchors` resource group.
    public var referenceImageName: String
    /// Real-world width of the plate in meters, used by ARKit.
    public var physicalWidthMeters: Double

    public init(
        transcription: String,
        quoteLabel: String = "Door plaque",
        referenceImageName: String,
        physicalWidthMeters: Double
    ) {
        self.transcription = transcription
        self.quoteLabel = quoteLabel
        self.referenceImageName = referenceImageName
        self.physicalWidthMeters = physicalWidthMeters
    }

    public var isUsable: Bool {
        !transcription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !referenceImageName.isEmpty
            && physicalWidthMeters > 0
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
