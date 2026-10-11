import Foundation

/// Google "Encoded Polyline Algorithm Format" codec (precision 1e-5), used by both the
/// Routes API (`polyline.encodedPolyline`) and the legacy Directions API.
public enum Polyline {
    public static func decode(_ encoded: String) -> [GeoCoordinate] {
        var coordinates: [GeoCoordinate] = []
        var index = encoded.utf8.startIndex
        let bytes = encoded.utf8
        var latitude = 0
        var longitude = 0

        func readValue() -> Int? {
            var result = 0
            var shift = 0
            while index < bytes.endIndex {
                let byte = Int(bytes[index]) - 63
                index = bytes.index(after: index)
                guard byte >= 0 else { return nil }
                result |= (byte & 0x1F) << shift
                shift += 5
                if byte < 0x20 {
                    return (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
                }
            }
            return nil
        }

        while index < bytes.endIndex {
            guard let dLat = readValue(), let dLng = readValue() else { break }
            latitude += dLat
            longitude += dLng
            coordinates.append(GeoCoordinate(latitude: Double(latitude) / 1e5, longitude: Double(longitude) / 1e5))
        }
        return coordinates
    }

    public static func encode(_ coordinates: [GeoCoordinate]) -> String {
        var output = ""
        var previousLat = 0
        var previousLng = 0

        func append(_ value: Int) {
            var v = value < 0 ? ~(value << 1) : (value << 1)
            while v >= 0x20 {
                output.unicodeScalars.append(UnicodeScalar((0x20 | (v & 0x1F)) + 63)!)
                v >>= 5
            }
            output.unicodeScalars.append(UnicodeScalar(v + 63)!)
        }

        for c in coordinates {
            let lat = Int((c.latitude * 1e5).rounded())
            let lng = Int((c.longitude * 1e5).rounded())
            append(lat - previousLat)
            append(lng - previousLng)
            previousLat = lat
            previousLng = lng
        }
        return output
    }
}
