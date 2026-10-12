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

    /// Same five stops as the bundled walking tour (previews and host-app tests).
    static let previewStops: [HistoricalStop] = [
        HistoricalStop(
            id: "hpab-001", name: "Droescher's Mill", latitude: 40.6551018, longitude: -74.2925808,
            address: "347 Lincoln Ave East, Cranford, NJ",
            shortDescription: "HPAB audio-tour stop. Play the recording for the site description. No transcript is bundled.",
            longDescription: "", imageName: "droeschers-mill",
            audioURL: URL(string: "http://preservecranford.com/Audio/Droescher%20Mill.mp3"),
            order: 1, isSample: false, coordinatesUnverified: true
        ),
        HistoricalStop(
            id: "hpab-002", name: "Cranford Hall", latitude: 40.6522522, longitude: -74.2997607,
            address: "600 Lincoln Park East, Cranford, NJ",
            shortDescription: "HPAB audio-tour stop. Play the recording for the site description. No transcript is bundled.",
            longDescription: "",
            audioURL: URL(string: "http://www.preservecranford.com/Audio/Greystone.mp3"),
            order: 2, isSample: false, coordinatesUnverified: true
        ),
        HistoricalStop(
            id: "hpab-003", name: "Rahway River", latitude: 40.6659731, longitude: -74.3108614,
            address: "Rahway River, Cranford, NJ",
            shortDescription: "HPAB audio-tour stop. Play the recording for the site description. No transcript is bundled.",
            longDescription: "",
            audioURL: URL(string: "http://preservecranford.com/Audio/Rahway%20River.mp3"),
            order: 3, isSample: false, coordinatesUnverified: true
        ),
        HistoricalStop(
            id: "hpab-004", name: "First Baptist Church", latitude: 40.6534498, longitude: -74.3027952,
            address: "100 High St, Cranford, NJ",
            shortDescription: "HPAB audio-tour stop. Play the recording for the site description. No transcript is bundled.",
            longDescription: "",
            audioURL: URL(string: "http://preservecranford.com/Audio/First%20Baptist.mp3"),
            order: 4, isSample: false, coordinatesUnverified: true
        ),
        HistoricalStop(
            id: "hpab-005", name: "Cranford Hotel", latitude: 40.65513, longitude: -74.304765,
            address: "1 S Union Ave, Cranford, NJ",
            shortDescription: "HPAB audio-tour stop. Play the recording for the site description. No transcript is bundled.",
            longDescription: "",
            audioURL: URL(string: "http://preservecranford.com/Audio/Cranford%20Hotel.mp3"),
            order: 5, isSample: false, coordinatesUnverified: true
        )
    ]
}

extension WalkingRoute {
    var clCoordinates: [CLLocationCoordinate2D] { routeCoordinates.map(\.clLocationCoordinate) }
}
