import CoreLocation
import Foundation
import TourCore

// TourCore owns the Codable model. These extensions bridge it to Apple frameworks.

extension GeoCoordinate {
    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

extension CLLocationCoordinate2D {
    var geoCoordinate: GeoCoordinate { GeoCoordinate(self) }
}

extension HistoricalStop {
    var clLocationCoordinate: CLLocationCoordinate2D { coordinate.clLocationCoordinate }

    /// Date line for the sign; sample stops never show a fabricated date.
    var displayDate: String? {
        guard let historicalDate, !historicalDate.isEmpty else { return nil }
        return historicalDate
    }

    static let previewStops: [HistoricalStop] = [
        HistoricalStop(id: "preview-1", name: "Sample Stop 1 — Downtown Area", latitude: 40.6565, longitude: -74.3040, address: "SAMPLE LOCATION — REPLACE WITH VERIFIED CRANFORD HISTORICAL SITE", shortDescription: "SAMPLE HISTORICAL DESCRIPTION — Historical information will appear here.", longDescription: "SAMPLE HISTORICAL DESCRIPTION.", imageName: "placeholder-historic-photo", order: 1, isSample: true),
        HistoricalStop(id: "preview-2", name: "Sample Stop 2 — Riverside Area", latitude: 40.6580, longitude: -74.3005, address: "SAMPLE LOCATION — REPLACE WITH VERIFIED CRANFORD HISTORICAL SITE", shortDescription: "SAMPLE HISTORICAL DESCRIPTION — Historical information will appear here.", longDescription: "SAMPLE HISTORICAL DESCRIPTION.", order: 2, isSample: true),
        HistoricalStop(id: "preview-3", name: "Sample Stop 3 — North Side", latitude: 40.6600, longitude: -74.2990, address: "SAMPLE LOCATION — REPLACE WITH VERIFIED CRANFORD HISTORICAL SITE", shortDescription: "SAMPLE HISTORICAL DESCRIPTION — Historical information will appear here.", longDescription: "SAMPLE HISTORICAL DESCRIPTION.", order: 3, isSample: true)
    ]
}

extension WalkingRoute {
    var clCoordinates: [CLLocationCoordinate2D] { routeCoordinates.map(\.clLocationCoordinate) }
}
