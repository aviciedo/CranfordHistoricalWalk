import Foundation

public enum StopVisitEvidence: String, Codable, Equatable, Sendable {
    case recognizedPlaque
    case onSiteARMarker
    /// Practice can exercise the flow, but must never be saved as a real visit.
    case simulation
}

public struct StopVisitRecord: Codable, Equatable, Sendable {
    public var stopID: String
    public var activatedAt: Date
    public var evidence: StopVisitEvidence

    public init(stopID: String, activatedAt: Date, evidence: StopVisitEvidence) {
        self.stopID = stopID
        self.activatedAt = activatedAt
        self.evidence = evidence
    }
}

public enum StopActivationIssue: String, Equatable, Sendable {
    case wrongStop, markerNotReady, trackingNotReady, waitingForLocation, weakLocation, outsideStop

    public var message: String {
        switch self {
        case .wrongStop: return "Follow the tour to the current stop first."
        case .markerNotReady: return "Move closer and look for the stop marker."
        case .trackingNotReady: return "Hold your phone up and move it slowly to find the marker."
        case .waitingForLocation: return "Finding your position. Wait for a fresh location and try again."
        case .weakLocation: return "Location is too approximate to record a visit. Move into a clearer area and try again."
        case .outsideStop: return "Move closer to this stop to activate its marker."
        }
    }
}

public enum StopActivationDecision: Equatable, Sendable {
    case allow(StopVisitEvidence)
    case deny(StopActivationIssue)
    case alreadyActivated
}

/// GPS-based activation is an on-site estimate, not proof of physical image recognition.
/// The mill can instead use a currently tracked plaque, including when its geocode is wrong.
public enum StopActivationPolicy {
    public static let maximumLocationAge: TimeInterval = 30
    public static let maximumAccuracyMeters: Double = 25

    public static func decide(
        trackingReady: Bool,
        plaqueIsTracked: Bool,
        isSimulated: Bool,
        distanceMeters: Double?,
        horizontalAccuracy: Double?,
        locationTimestamp: Date?,
        arrivalRadius: Double,
        now: Date = Date()
    ) -> StopActivationDecision {
        guard trackingReady else { return .deny(.trackingNotReady) }
        if plaqueIsTracked { return .allow(isSimulated ? .simulation : .recognizedPlaque) }
        guard let timestamp = locationTimestamp,
              isFresh(timestamp, now: now) else { return .deny(.waitingForLocation) }
        guard let accuracy = horizontalAccuracy, accuracy.isFinite,
              accuracy >= 0, accuracy <= maximumAccuracyMeters else { return .deny(.weakLocation) }
        guard let distance = distanceMeters, distance.isFinite, distance >= 0,
              arrivalRadius.isFinite, arrivalRadius > 0,
              distance + accuracy <= arrivalRadius else { return .deny(.outsideStop) }
        return .allow(isSimulated ? .simulation : .onSiteARMarker)
    }

    public static func isFresh(_ timestamp: Date, now: Date = Date()) -> Bool {
        let age = now.timeIntervalSince(timestamp)
        return age.isFinite && age >= -5 && age < maximumLocationAge
    }
}
