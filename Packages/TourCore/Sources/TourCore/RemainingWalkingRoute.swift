import Foundation

/// The part of a provider route still ahead of the visitor.
/// Trimming follows the route projection. It does not draw a line from the GPS dot.
public enum RemainingWalkingRoute {
    /// At this lateral error the projection is too far to shorten the line, so the full route stays.
    public static let maximumLateralMeters: Double = 35
    /// Drop a vertex that would only retrace the projection. Exactly 0.1 m is kept.
    public static let minimumVertexSeparationMeters: Double = 0.1

    /// `nil` means the progress cannot trim, and the caller keeps the provider geometry.
    /// An empty array means the projection has reached the end.
    public static func trimmed(coordinates: [GeoCoordinate], snapped: GeoCoordinate,
                               lateralMeters: Double, segmentIndex: Int) -> [GeoCoordinate]? {
        guard snapped.isValid, lateralMeters.isFinite,
              (0...maximumLateralMeters).contains(lateralMeters),
              coordinates.indices.contains(segmentIndex),
              coordinates.indices.contains(segmentIndex + 1) else { return nil }
        var remaining = [snapped]
        for coordinate in coordinates.dropFirst(segmentIndex + 1) {
            if let last = remaining.last,
               GeoMath.distance(from: last, to: coordinate) < minimumVertexSeparationMeters { continue }
            remaining.append(coordinate)
        }
        return remaining.count >= 2 ? remaining : []
    }
}
