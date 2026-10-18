import Foundation

/// Visual plaque recognition versus an unverified GPS geocode.
///
/// A matching physical plate can open the current stop even when the bundled coordinate
/// is still hundreds of meters away. That confirmation must not be undone by the next
/// location sample, and it must not reopen a sign the visitor already dismissed.
public enum PlaqueArrivalPolicy {
    /// Fixes worse than this must not open or close the AR sign on their own.
    public static let maximumHorizontalAccuracyMeters: Double = 100

    public enum Confirmation: Equatable, Sendable {
        /// Do not record a plaque arrival or open the sign.
        case ignore
        /// Record visual arrival. Open the sign only when it is not already presented.
        case confirm(openSign: Bool)
    }

    public static func confirmation(
        tourInProgress: Bool,
        currentStopID: String?,
        requestedStopID: String,
        stopHasPlaqueReference: Bool,
        hasManuallyDismissed: Bool?,
        isSignPresented: Bool
    ) -> Confirmation {
        guard tourInProgress,
              let currentStopID,
              currentStopID == requestedStopID,
              stopHasPlaqueReference,
              hasManuallyDismissed == false else {
            return .ignore
        }
        return .confirm(openSign: !isSignPresented)
    }

    /// GPS must not move a stop that was confirmed by the physical plaque.
    /// Other fixes still have to be accurate enough to open or close the sign.
    public static func shouldApplyLocationSample(
        plaqueConfirmedForCurrentStop: Bool,
        horizontalAccuracy: Double
    ) -> Bool {
        if plaqueConfirmedForCurrentStop { return false }
        return horizontalAccuracy >= 0 && horizontalAccuracy <= maximumHorizontalAccuracyMeters
    }
}
