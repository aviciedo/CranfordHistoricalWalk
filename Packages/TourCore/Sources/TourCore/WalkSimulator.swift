import Foundation

/// Deterministic position stepping for Developer Mode (spec §19). Pure function of its inputs so
/// the app can drive it from a timer and tests can drive it synchronously.
public struct WalkSimulator: Sendable, Equatable {
    public var metersPerSecond: Double

    public init(metersPerSecond: Double = 1.4) {
        self.metersPerSecond = metersPerSecond
    }

    public struct Sample: Sendable, Equatable {
        public var coordinate: GeoCoordinate
        /// Course over ground in degrees; `nil` when not moving.
        public var course: Double?
        public var didArrive: Bool
    }

    /// Moves straight toward `target` for `deltaTime` seconds, stopping exactly at the target.
    public func step(from current: GeoCoordinate, toward target: GeoCoordinate, deltaTime: TimeInterval) -> Sample {
        let remaining = GeoMath.distance(from: current, to: target)
        let stride = max(0, metersPerSecond * deltaTime)
        if remaining <= stride || remaining < 0.05 {
            return Sample(coordinate: target, course: remaining > 0.05 ? GeoMath.bearing(from: current, to: target) : nil, didArrive: true)
        }
        let bearing = GeoMath.bearing(from: current, to: target)
        return Sample(coordinate: GeoMath.destination(from: current, bearing: bearing, distance: stride), course: bearing, didArrive: false)
    }

    /// Follows a polyline: advances along `path` starting from the vertex after the user's
    /// current projection. Falls back to a straight step when the path is empty.
    public func step(from current: GeoCoordinate, along path: [GeoCoordinate], toward target: GeoCoordinate, deltaTime: TimeInterval) -> Sample {
        guard path.count >= 2 else {
            return step(from: current, toward: target, deltaTime: deltaTime)
        }
        var budget = max(0, metersPerSecond * deltaTime)
        var position = current

        // Find the segment we're on, then walk vertex to vertex until the budget is spent.
        var bestSegment = 0
        var bestDistance = Double.greatestFiniteMagnitude
        for i in 0..<(path.count - 1) {
            let d = GeoMath.project(current, ontoSegment: path[i], path[i + 1]).distance
            if d < bestDistance { bestDistance = d; bestSegment = i }
        }

        var nextVertex = bestSegment + 1
        var course: Double? = nil
        while budget > 0, nextVertex < path.count {
            let vertex = path[nextVertex]
            let d = GeoMath.distance(from: position, to: vertex)
            if d <= budget {
                budget -= d
                course = d > 0.05 ? GeoMath.bearing(from: position, to: vertex) : course
                position = vertex
                nextVertex += 1
            } else {
                let bearing = GeoMath.bearing(from: position, to: vertex)
                position = GeoMath.destination(from: position, bearing: bearing, distance: budget)
                course = bearing
                budget = 0
            }
        }

        if nextVertex >= path.count, budget > 0 || GeoMath.distance(from: position, to: target) < 0.05 {
            // Reached the end of the polyline; finish with a straight step to the exact target.
            let final = step(from: position, toward: target, deltaTime: budget / max(metersPerSecond, 0.01))
            return Sample(coordinate: final.coordinate, course: final.course ?? course, didArrive: final.didArrive)
        }
        return Sample(coordinate: position, course: course, didArrive: GeoMath.distance(from: position, to: target) < 0.05)
    }
}
