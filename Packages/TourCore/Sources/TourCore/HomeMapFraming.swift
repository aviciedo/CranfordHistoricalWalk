import Foundation

/// Home-map camera and landmark decisions. The live tour map still frames the user and
/// hides landmark art when zoomed out; Home must stay on the stops with the drawings visible.
public enum HomeMapFraming {
    /// Live-map zoom at which landmark illustrations appear. Home ignores this cutoff.
    public static let landmarkMinimumZoom: Double = 14.5
    /// Short screens and large text still keep a map larger than the previous fixed 290 points.
    public static let minimumMapHeight: Double = 310
    public static let maximumMapHeight: Double = 350
    /// The developer button's 44-point target plus the gap above the map.
    public static let developerControlReserve: Double = 56

    /// Coordinates for a fit-all camera. Home passes `includesUserLocation: false` so a GPS
    /// fix far from Cranford cannot zoom the tour out of frame. An absent fix is omitted
    /// even when the live map would otherwise include it.
    public static func overviewCoordinates(
        stops: [GeoCoordinate],
        user: GeoCoordinate?,
        includesUserLocation: Bool
    ) -> [GeoCoordinate] {
        guard includesUserLocation, let user else { return stops }
        return stops + [user]
    }

    public static func showsLandmark(keepsLandmarksVisible: Bool, zoom: Double) -> Bool {
        keepsLandmarksVisible || zoom >= landmarkMinimumZoom
    }

    /// `contentReserve` is the scaled space already claimed by the title, stop count, and
    /// start button. The developer row is added only for that build, then the result is clamped.
    public static func mapHeight(
        availableHeight: Double,
        contentReserve: Double,
        includesDeveloperControl: Bool
    ) -> Double {
        let reserved = contentReserve + (includesDeveloperControl ? developerControlReserve : 0)
        return max(minimumMapHeight, min(maximumMapHeight, availableHeight - reserved))
    }
}
