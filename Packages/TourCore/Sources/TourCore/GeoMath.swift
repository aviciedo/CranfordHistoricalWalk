import Foundation

/// Great-circle and local-plane helpers. All distances are meters, all angles degrees
/// unless the name says otherwise. Bearings are compass bearings (0 = north, 90 = east).
public enum GeoMath {
    public static let earthRadiusMeters: Double = 6_371_008.8
    public static let metersPerMile: Double = 1609.344
    public static let feetPerMeter: Double = 3.280_839_895

    @inlinable static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    @inlinable static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }

    /// Haversine distance.
    public static func distance(from a: GeoCoordinate, to b: GeoCoordinate) -> Double {
        let φ1 = radians(a.latitude), φ2 = radians(b.latitude)
        let dφ = radians(b.latitude - a.latitude)
        let dλ = radians(b.longitude - a.longitude)
        let h = sin(dφ / 2) * sin(dφ / 2) + cos(φ1) * cos(φ2) * sin(dλ / 2) * sin(dλ / 2)
        return 2 * earthRadiusMeters * asin(min(1, sqrt(h)))
    }

    /// Initial great-circle bearing from `a` to `b`, normalized to 0..<360.
    public static func bearing(from a: GeoCoordinate, to b: GeoCoordinate) -> Double {
        let φ1 = radians(a.latitude), φ2 = radians(b.latitude)
        let dλ = radians(b.longitude - a.longitude)
        let y = sin(dλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(dλ)
        return normalizeBearing(degrees(atan2(y, x)))
    }

    /// Point reached by travelling `distance` meters from `origin` along `bearing`.
    public static func destination(from origin: GeoCoordinate, bearing: Double, distance: Double) -> GeoCoordinate {
        let δ = distance / earthRadiusMeters
        let θ = radians(bearing)
        let φ1 = radians(origin.latitude), λ1 = radians(origin.longitude)
        let φ2 = asin(sin(φ1) * cos(δ) + cos(φ1) * sin(δ) * cos(θ))
        let λ2 = λ1 + atan2(sin(θ) * sin(δ) * cos(φ1), cos(δ) - sin(φ1) * sin(φ2))
        return GeoCoordinate(latitude: degrees(φ2), longitude: normalizeLongitude(degrees(λ2)))
    }

    public static func normalizeBearing(_ degrees: Double) -> Double {
        var d = degrees.truncatingRemainder(dividingBy: 360)
        if d < 0 { d += 360 }
        return d == 360 ? 0 : d
    }

    public static func normalizeLongitude(_ degrees: Double) -> Double {
        var d = degrees
        while d > 180 { d -= 360 }
        while d < -180 { d += 360 }
        return d
    }

    /// Signed smallest angle from `heading` to `bearing`, in -180...180.
    /// Positive means the target is to the right (clockwise) of the heading.
    public static func relativeBearing(heading: Double, bearing: Double) -> Double {
        var delta = (bearing - heading).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return delta
    }

    /// Local east/north offset (meters) of `point` relative to `origin` using an
    /// equirectangular approximation, accurate to well under 1% at walking scales.
    public static func localOffset(of point: GeoCoordinate, from origin: GeoCoordinate) -> (east: Double, north: Double) {
        let meanLat = radians((point.latitude + origin.latitude) / 2)
        let east = radians(point.longitude - origin.longitude) * cos(meanLat) * earthRadiusMeters
        let north = radians(point.latitude - origin.latitude) * earthRadiusMeters
        return (east, north)
    }

    /// Nearest point on the segment `a`–`b` to `p`, returned with the fraction along the
    /// segment (0...1) and the perpendicular distance in meters.
    public static func project(_ p: GeoCoordinate, ontoSegment a: GeoCoordinate, _ b: GeoCoordinate)
        -> (point: GeoCoordinate, fraction: Double, distance: Double)
    {
        let pb = localOffset(of: b, from: a)
        let pp = localOffset(of: p, from: a)
        let lengthSquared = pb.east * pb.east + pb.north * pb.north
        guard lengthSquared > 0 else {
            return (a, 0, distance(from: p, to: a))
        }
        var t = (pp.east * pb.east + pp.north * pb.north) / lengthSquared
        t = min(1, max(0, t))
        let point = GeoCoordinate(
            latitude: a.latitude + (b.latitude - a.latitude) * t,
            longitude: a.longitude + (b.longitude - a.longitude) * t
        )
        return (point, t, distance(from: p, to: point))
    }

    public static func miles(fromMeters meters: Double) -> Double { meters / metersPerMile }
    public static func feet(fromMeters meters: Double) -> Double { meters * feetPerMeter }
}
