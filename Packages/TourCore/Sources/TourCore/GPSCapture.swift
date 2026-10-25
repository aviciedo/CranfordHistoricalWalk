import Foundation

/// An explicitly saved field-test reading. This never changes a tour's coordinates or activities.
public struct GPSCapture: Identifiable, Codable, Equatable, Sendable {
    public enum Source: String, Codable, Sendable { case deviceGPS = "device_gps", legacyViewingPoint = "legacy_viewing_point" }
    public var id: UUID
    public var tour: TourCatalogIdentity
    public var stopID: String
    public var stopName: String
    public var label: String
    public var coordinate: GeoCoordinate
    public var horizontalAccuracy: Double
    public var fixTimestamp: Date?
    public var savedAt: Date
    public var preciseLocation: Bool?
    public var source: Source

    public init(id: UUID = UUID(), tour: TourCatalogIdentity, stopID: String, stopName: String,
                label: String, coordinate: GeoCoordinate, horizontalAccuracy: Double,
                fixTimestamp: Date?, savedAt: Date = Date(), preciseLocation: Bool?, source: Source = .deviceGPS) {
        self.id = id; self.tour = tour; self.stopID = stopID; self.stopName = stopName
        self.label = label; self.coordinate = coordinate; self.horizontalAccuracy = horizontalAccuracy
        self.fixTimestamp = fixTimestamp; self.savedAt = savedAt
        self.preciseLocation = preciseLocation; self.source = source
    }

    public var isValid: Bool {
        guard tour.isValid, !stopID.isEmpty, !stopName.isEmpty,
              !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              coordinate.isValid, horizontalAccuracy.isFinite, horizontalAccuracy >= 0,
              savedAt.timeIntervalSince1970.isFinite else { return false }
        if source == .deviceGPS {
            guard let fixTimestamp, preciseLocation != nil,
                  StopActivationPolicy.isFresh(fixTimestamp, now: savedAt) else { return false }
        } else if let fixTimestamp, !fixTimestamp.timeIntervalSince1970.isFinite { return false }
        return true
    }

    public var copyText: String {
        let locale = Locale(identifier: "en_US_POSIX")
        return """
        \(stopName) — \(label)
        Stop ID: \(stopID)
        Latitude: \(String(format: "%.6f", locale: locale, coordinate.latitude))
        Longitude: \(String(format: "%.6f", locale: locale, coordinate.longitude))
        Reported accuracy: ± \(String(format: "%.1f", locale: locale, horizontalAccuracy)) m
        GPS fix (UTC): \(fixTimestamp.map(Self.timestamp) ?? "Unknown — imported legacy viewing point")
        Saved (UTC): \(Self.timestamp(savedAt))
        Precise Location: \(preciseLocation.map { $0 ? "On" : "Off" } ?? "Unknown")
        Source: \(source.rawValue)
        """
    }

    /// RFC 4180 rows; user-entered labels are also protected against spreadsheet formulas.
    public static func csv(_ records: [GPSCapture]) -> String {
        let header = "capture_id,tour_id,catalog_version,stop_id,stop_name,label,latitude,longitude,accuracy_m,fix_timestamp_utc,saved_at_utc,precise_location,source"
        let rows = records.map { record in
            [cell(record.id.uuidString), cell(record.tour.tourID), String(record.tour.version),
             cell(record.stopID), cell(record.stopName), cell(record.label),
             String(record.coordinate.latitude), String(record.coordinate.longitude), String(record.horizontalAccuracy),
             record.fixTimestamp.map(timestamp) ?? "", timestamp(record.savedAt),
             record.preciseLocation.map { $0 ? "true" : "false" } ?? "", record.source.rawValue].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\r\n") + "\r\n"
    }

    private static func cell(_ value: String) -> String {
        let first = value.trimmingCharacters(in: .whitespacesAndNewlines).first
        let safe = first.map { "=+-@".contains($0) } == true ? "'" + value : value
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}

public struct GPSCaptureArchive: Codable, Equatable, Sendable {
    public var version = 1
    public var records: [GPSCapture]
    public init(records: [GPSCapture]) { self.records = records }
    public var isValid: Bool {
        version == 1 && records.allSatisfy(\.isValid) && Set(records.map(\.id)).count == records.count
    }
}
