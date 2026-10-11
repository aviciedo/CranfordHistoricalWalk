import Foundation

/// Where the user is relative to a `WalkingRoute`, derived locally between network refreshes.
public struct RouteProgress: Hashable, Sendable {
    /// Closest point on the polyline to the user.
    public var snappedCoordinate: GeoCoordinate
    /// Perpendicular distance from the user to the polyline (meters).
    public var distanceFromRoute: Double
    /// Meters already covered along the polyline.
    public var traveledMeters: Double
    /// Meters left along the polyline from the snapped point to the destination.
    public var remainingMeters: Double
    /// Seconds left, scaled from the provider's duration by remaining/total distance.
    public var remainingSeconds: TimeInterval
    /// Index of the polyline segment (i -> i+1) the user is on.
    public var segmentIndex: Int
    /// Index into `route.routeSteps` of the step the user is currently on, if steps exist.
    public var currentStepIndex: Int?
    public var fractionComplete: Double

    /// Coordinate of the next vertex ahead of the user — a good AR arrow target.
    public var nextWaypoint: GeoCoordinate
}

public enum RouteProgressCalculator {
    /// Projects `userLocation` onto the route. `remainingMeters` is never computed as a straight
    /// line to the destination; it follows the route geometry (spec §5).
    public static func progress(along route: WalkingRoute, userLocation: GeoCoordinate) -> RouteProgress {
        let points = route.routeCoordinates
        guard points.count >= 2 else {
            let d = GeoMath.distance(from: userLocation, to: route.destination)
            return RouteProgress(
                snappedCoordinate: userLocation,
                distanceFromRoute: 0,
                traveledMeters: 0,
                remainingMeters: d,
                remainingSeconds: d / route.metersPerSecond,
                segmentIndex: 0,
                currentStepIndex: route.routeSteps.isEmpty ? nil : 0,
                fractionComplete: 0,
                nextWaypoint: route.destination
            )
        }

        var cumulative: [Double] = [0]
        cumulative.reserveCapacity(points.count)
        for i in 1..<points.count {
            cumulative.append(cumulative[i - 1] + GeoMath.distance(from: points[i - 1], to: points[i]))
        }
        let total = max(cumulative[points.count - 1], 0.001)

        var best = (segment: 0, point: points[0], fraction: 0.0, distance: Double.greatestFiniteMagnitude)
        for i in 0..<(points.count - 1) {
            let projection = GeoMath.project(userLocation, ontoSegment: points[i], points[i + 1])
            // Prefer later segments on ties so users do not "snap back" at self-intersections.
            if projection.distance < best.distance - 0.01 || (abs(projection.distance - best.distance) <= 0.01 && i > best.segment) {
                best = (i, projection.point, projection.fraction, projection.distance)
            }
        }

        let segmentLength = cumulative[best.segment + 1] - cumulative[best.segment]
        let traveled = cumulative[best.segment] + segmentLength * best.fraction
        let remaining = max(0, total - traveled)
        let scale = route.distanceMeters > 0 ? route.distanceMeters / total : 1
        let remainingProviderMeters = remaining * scale
        let remainingSeconds = remainingProviderMeters / route.metersPerSecond

        let stepIndex = currentStep(in: route, traveledFraction: traveled / total)
        let nextIndex = min(best.segment + 1, points.count - 1)

        return RouteProgress(
            snappedCoordinate: best.point,
            distanceFromRoute: best.distance,
            traveledMeters: traveled * scale,
            remainingMeters: remainingProviderMeters,
            remainingSeconds: remainingSeconds,
            segmentIndex: best.segment,
            currentStepIndex: stepIndex,
            fractionComplete: min(1, traveled / total),
            nextWaypoint: points[nextIndex]
        )
    }

    static func currentStep(in route: WalkingRoute, traveledFraction: Double) -> Int? {
        guard !route.routeSteps.isEmpty else { return nil }
        let total = route.routeSteps.reduce(0) { $0 + $1.distanceMeters }
        guard total > 0 else { return 0 }
        let target = traveledFraction * total
        var acc = 0.0
        for (index, step) in route.routeSteps.enumerated() {
            acc += step.distanceMeters
            if target <= acc + 0.5 { return index }
        }
        return route.routeSteps.count - 1
    }
}
