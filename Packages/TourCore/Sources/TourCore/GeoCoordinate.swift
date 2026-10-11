import Foundation

/// Platform-independent latitude/longitude pair (degrees, WGS84).
/// The app layer bridges this to `CLLocationCoordinate2D`; TourCore never imports CoreLocation.
public struct GeoCoordinate: Hashable, Codable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public var isValid: Bool {
        (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}

extension GeoCoordinate: CustomStringConvertible {
    public var description: String {
        String(format: "%.6f, %.6f", latitude, longitude)
    }
}
