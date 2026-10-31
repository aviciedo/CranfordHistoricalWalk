import Foundation

/// One physical-movement decision feeds both measured distance and the drawn GPS trail.
/// A gap/jump starts a new segment; it never invents a connector or adds distance.
public struct WalkingMovementPolicy: Sendable {
    public enum Update: Equatable, Sendable {
        case ignored, interrupted, started
        case advanced(meters: Double)
    }
    private var previous: (coordinate: GeoCoordinate, timestamp: Date)?
    private var recordedCoordinate: GeoCoordinate?
    public init() {}
    public mutating func reset() { previous = nil; recordedCoordinate = nil }

    public mutating func update(coordinate: GeoCoordinate, accuracy: Double, timestamp: Date,
                                speed: Double? = nil, recordingAllowed: Bool = true,
                                now: Date = Date()) -> Update {
        guard recordingAllowed, coordinate.isValid, StopActivationPolicy.isFresh(timestamp, now: now),
              accuracy.isFinite, (0...StopActivationPolicy.maximumAccuracyMeters).contains(accuracy),
              speed.map({ $0.isFinite && (0...4).contains($0) }) ?? true else {
            reset(); return .interrupted
        }
        if let previous, timestamp <= previous.timestamp { return .ignored }
        let old = previous
        previous = (coordinate, timestamp)
        if let old {
            let elapsed = timestamp.timeIntervalSince(old.timestamp)
            if elapsed <= 10, GeoMath.distance(from: old.coordinate, to: coordinate) / elapsed <= 4,
               let recordedCoordinate {
                let moved = GeoMath.distance(from: recordedCoordinate, to: coordinate)
                guard moved >= 2 else { return .ignored }
                self.recordedCoordinate = coordinate
                return .advanced(meters: moved)
            }
        }
        recordedCoordinate = coordinate
        return .started
    }
}
