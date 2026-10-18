import Foundation

/// Path comparison for a walking route drawn on the map.
public enum RouteGeometry {
    /// True only when both paths have the same coordinates in the same order.
    ///
    /// Comparing a count plus the endpoints and midpoint is not enough: a reroute can
    /// keep those three points and still change the streets in between.
    public static func coordinatesMatch(_ lhs: [GeoCoordinate], _ rhs: [GeoCoordinate]) -> Bool {
        lhs.count == rhs.count && zip(lhs, rhs).allSatisfy {
            $0.latitude == $1.latitude && $0.longitude == $1.longitude
        }
    }
}
