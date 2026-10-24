import Foundation

/// Derived from the phone-down regression work in 3d4dcce; time is now monotonic.
public struct PhoneDownReturnPolicy: Equatable, Sendable {
    private var raised = false
    private var horizontalSince: TimeInterval?
    private var previousTime: TimeInterval?
    public init() {}
    public mutating func reset() { self = Self() }
    public mutating func update(x: Double, y: Double, z: Double, timestamp: TimeInterval,
                                suspended: Bool = false) -> Bool {
        guard [x,y,z,timestamp].allSatisfy(\.isFinite), !suspended else {
            horizontalSince = nil
            previousTime = nil
            return false
        }
        if let previousTime, timestamp <= previousTime || timestamp - previousTime > 0.6 {
            horizontalSince = nil
        }
        previousTime = timestamp
        if abs(z) < 0.70 { raised = true; horizontalSince = nil }
        else if raised && z < -0.92 && abs(x) < 0.35 && abs(y) < 0.35 {
            if let horizontalSince { return timestamp - horizontalSince >= 2 }
            horizontalSince = timestamp
        } else { horizontalSince = nil }
        return false
    }
}
