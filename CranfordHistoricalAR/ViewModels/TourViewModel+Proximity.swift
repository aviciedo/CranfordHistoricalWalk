import Foundation
import TourCore

/// Arrival detection and sign open/close behaviour (spec §9) on top of `StopProximityStateMachine`.
extension TourViewModel {
    enum SignPresentationSource: Equatable { case automatic, manual }

    /// The stop whose sign is currently open, if any.
    var presentedSignStop: HistoricalStop? {
        presentedSignStopID.flatMap(stop(withID:))
    }

    var isSignPresented: Bool { presentedSignStopID != nil }

    var proximityState: StopProximityState? { proximityMachine?.state }

    /// True once the user has been inside the arrival radius of the current stop (sign shown at least once).
    var hasArrivedAtCurrentStop: Bool { proximityMachine?.hasPresentedSign ?? false }

    var isWithinArrivalRadius: Bool { proximityMachine?.isWithinArrivalRadius ?? false }

    /// Builds a fresh state machine for the current stop. Called whenever the destination changes.
    func resetProximityForCurrentStop() {
        presentedSignStopID = nil
        signPresentationSource = nil
        guard let stop = currentStop else { proximityMachine = nil; return }
        proximityMachine = StopProximityStateMachine(stop: stop)
        if let userLocation {
            handleLocationForProximity(userLocation)
        }
    }

    func handleLocationForProximity(_ sample: LocationSample) {
        guard progress.phase == .inProgress, let stop = currentStop, proximityMachine != nil else { return }
        // Ignore wildly inaccurate fixes so a 200 m GPS jump cannot open/close the sign.
        guard sample.horizontalAccuracy >= 0, sample.horizontalAccuracy <= 100 else { return }
        let distance = GeoMath.distance(from: sample.coordinate, to: stop.coordinate)
        let effects = proximityMachine!.handle(.distanceUpdated(meters: distance))
        apply(effects, for: stop, source: .automatic)
    }

    /// User tapped the stop / "Show sign" while the sign is closed.
    func openSignManually() {
        guard let stop = currentStop, proximityMachine != nil else { return }
        let effects = proximityMachine!.handle(.userOpenedSign)
        apply(effects, for: stop, source: .manual)
    }

    /// Close button on the sign.
    func closeSign() {
        guard let stop = currentStop, proximityMachine != nil else { presentedSignStopID = nil; return }
        let effects = proximityMachine!.handle(.userClosedSign)
        apply(effects, for: stop, source: .manual)
    }

    private func apply(_ effects: [StopProximityEffect], for stop: HistoricalStop, source: SignPresentationSource) {
        for effect in effects {
            switch effect {
            case .presentSign:
                presentedSignStopID = stop.id
                signPresentationSource = source
            case .dismissSign:
                if presentedSignStopID == stop.id {
                    presentedSignStopID = nil
                    signPresentationSource = nil
                }
            case .stopCompleted:
                break
            }
        }
    }
}
