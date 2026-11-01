import Foundation

/// Continuous camera evidence only. GPS proximity, stories and saved visits are not inputs.
/// The existing tour ledger remains responsible for awarding a qualified recognition once.
public struct PlaqueRecognitionEvidence: Sendable {
    public struct Observation: Equatable, Sendable {
        public var anchorID: UUID
        public var referenceName: String?
        public var isTracked: Bool
        public var cameraTrackingNormal: Bool
        public var position: SIMD3<Double>
        /// Image-anchor +Y: outward normal of the physical reference surface.
        public var surfaceNormal: SIMD3<Double>
        public var timestamp: TimeInterval

        public init(anchorID: UUID, referenceName: String?, isTracked: Bool,
                    cameraTrackingNormal: Bool, position: SIMD3<Double>,
                    surfaceNormal: SIMD3<Double>, timestamp: TimeInterval) {
            self.anchorID = anchorID; self.referenceName = referenceName
            self.isTracked = isTracked; self.cameraTrackingNormal = cameraTrackingNormal
            self.position = position; self.surfaceNormal = surfaceNormal; self.timestamp = timestamp
        }
    }

    public static let confirmationSeconds: TimeInterval = 0.5
    public static let maximumObservationGap: TimeInterval = 0.35
    public static let maximumObservationAge: TimeInterval = 0.5
    public private(set) var anchorID: UUID?
    public private(set) var referenceName: String?
    public private(set) var isConfirmed = false
    private var startedAt: TimeInterval?
    private var lastTimestamp: TimeInterval?
    private var origin: SIMD3<Double>?
    private var normal: SIMD3<Double>?
    private var observations = 0

    public init() {}
    public mutating func reset() { self = Self() }

    /// Removing an unrelated anchor must not discard the target currently in view.
    public mutating func lose(anchorID: UUID) {
        if self.anchorID == anchorID { reset() }
    }

    @discardableResult
    public mutating func observe(_ sample: Observation, at now: TimeInterval,
                                 supportedReferences: Set<String>) -> Bool {
        let values = [sample.timestamp, now, sample.position.x, sample.position.y, sample.position.z,
                      sample.surfaceNormal.x, sample.surfaceNormal.y, sample.surfaceNormal.z]
        guard values.allSatisfy(\.isFinite), sample.timestamp >= 0,
              (-0.01...Self.maximumObservationAge).contains(now - sample.timestamp),
              sample.isTracked, sample.cameraTrackingNormal,
              let name = sample.referenceName, supportedReferences.contains(name) else {
            reset(); return false
        }
        let n = sample.surfaceNormal
        let length = sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
        guard length.isFinite, length > 0.001 else { reset(); return false }
        let unit = n / length
        let sameTarget = anchorID == sample.anchorID && referenceName == name
        if sameTarget, let lastTimestamp, sample.timestamp <= lastTimestamp {
            // Multiple delegate callbacks for one AR frame are one observation.
            return sample.timestamp == lastTimestamp && isConfirmed
        }
        let gapIsValid = lastTimestamp.map { sample.timestamp - $0 <= Self.maximumObservationGap } ?? false
        let stablePosition = origin.map {
            let delta = sample.position - $0
            return sqrt(delta.x * delta.x + delta.y * delta.y + delta.z * delta.z) <= 0.15
        } ?? false
        let stableNormal = normal.map { $0.x * unit.x + $0.y * unit.y + $0.z * unit.z >= cos(12 * .pi / 180) } ?? false
        if !sameTarget || !gapIsValid || !stablePosition || !stableNormal {
            reset()
            anchorID = sample.anchorID; referenceName = name
            origin = sample.position; normal = unit; startedAt = sample.timestamp
        }
        observations += 1
        lastTimestamp = sample.timestamp
        isConfirmed = observations >= 3 && sample.timestamp - (startedAt ?? sample.timestamp) >= Self.confirmationSeconds
        return isConfirmed
    }
}
