import Foundation

/// What the Stops list says about a stop. A saved visit wins over completion and "next",
/// so a verified plaque is never relabeled as a practice visit.
public enum StopListStatus: Equatable, Sendable {
    /// A visit stored on this device. Plaque recognition is the only verified evidence.
    case recordedVisit(plaqueVerified: Bool)
    /// Finished in the tour with nothing saved. Plaque stops must say the verification is missing.
    case completed(savedPlaqueMissing: Bool)
    case nextOnWalk
    case none

    public static func resolve(
        recordedVisitEvidence: StopVisitEvidence?,
        isCompleted: Bool,
        hasPlaqueReference: Bool,
        isCurrentDestination: Bool
    ) -> StopListStatus {
        if let recordedVisitEvidence {
            return .recordedVisit(plaqueVerified: recordedVisitEvidence == .recognizedPlaque)
        }
        if isCompleted {
            return .completed(savedPlaqueMissing: hasPlaqueReference)
        }
        if isCurrentDestination {
            return .nextOnWalk
        }
        return .none
    }
}
