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

    var hasPlaqueConfirmedArrival: Bool {
        guard let currentStop else { return false }
        return plaqueConfirmedStopID == currentStop.id
    }

    /// A matching physical plaque is stronger arrival evidence than the unverified GPS geocode.
    func confirmPlaqueArrival(for stopID: String) {
        switch PlaqueArrivalPolicy.confirmation(
            tourInProgress: progress.phase == .inProgress,
            currentStopID: currentStop?.id,
            requestedStopID: stopID,
            stopHasPlaqueReference: currentStop?.hasPlaqueReference == true,
            hasManuallyDismissed: proximityMachine?.hasManuallyDismissed,
            isSignPresented: isSignPresented
        ) {
        case .ignore:
            return
        case .confirm(let openSign):
            plaqueConfirmedStopID = stopID
            if openSign { openSignManually() }
        }
    }

    /// Builds a fresh state machine for the current stop. Called whenever the destination changes.
    func resetProximityForCurrentStop() {
        plaqueConfirmedStopID = nil
        presentedSignStopID = nil
        signPresentationSource = nil
        guard let stop = currentStop else { proximityMachine = nil; return }
        proximityMachine = StopProximityStateMachine(stop: stop)
        if let userLocation {
            handleLocationForProximity(userLocation)
        }
    }

    func handleLocationForProximity(_ sample: LocationSample) {
        guard progress.phase == .inProgress, let stop = currentStop, var machine = proximityMachine else { return }
        // A recognized plaque holds the stop against a bad geocode. Other fixes still
        // have to be accurate enough that a 200 m GPS jump cannot open or close the sign.
        guard PlaqueArrivalPolicy.shouldApplyLocationSample(
            plaqueConfirmedForCurrentStop: hasPlaqueConfirmedArrival,
            horizontalAccuracy: sample.horizontalAccuracy
        ) else { return }
        let distance = GeoMath.distance(from: sample.coordinate, to: stop.coordinate)
        let effects = machine.handle(.distanceUpdated(meters: distance))
        proximityMachine = machine
        apply(effects, for: stop, source: .automatic)
    }

    /// User tapped the stop / "Show sign" while the sign is closed.
    func openSignManually() {
        guard let stop = currentStop, var machine = proximityMachine else { return }
        let effects = machine.handle(.userOpenedSign)
        proximityMachine = machine
        apply(effects, for: stop, source: .manual)
    }

    /// Close button on the sign.
    func closeSign() {
        guard let stop = currentStop, var machine = proximityMachine else { presentedSignStopID = nil; return }
        let effects = machine.handle(.userClosedSign)
        proximityMachine = machine
        apply(effects, for: stop, source: .manual)
    }

    // MARK: Completion (spec §11)

    /// True once the current stop counts as visited (its sign has been displayed).
    var isCurrentStopVisited: Bool { progress.isCurrentStopVisited }

    /// Explicit "Mark as visited" / "Continue": completes the current stop and moves the tour on.
    /// Route, panel, AR arrows and destination all follow from `destinationDidChange()`.
    func completeCurrentStopAndAdvance() {
        guard progress.phase == .inProgress, currentStop != nil else { return }
        proximityMachine?.handle(.markCompleted)
        presentedSignStopID = nil
        signPresentationSource = nil
        progress.completeCurrentStop()
        // When this was the last stop, `currentStop` is nil: routing stops, the proximity machine
        // is dropped and the "TOUR COMPLETE" screen takes over. Summary legs are kept for its totals.
        destinationDidChange()
    }

    private func apply(_ effects: [StopProximityEffect], for stop: HistoricalStop, source: SignPresentationSource) {
        var shouldAdvance = false
        for effect in effects {
            switch effect {
            case .presentSign:
                presentedSignStopID = stop.id
                signPresentationSource = source
                // Reaching the site and seeing the sign is what "visited" means (spec §11).
                // The marker changes now; the destination advances once the sign is put away.
                if stop.id == currentStop?.id { progress.markCurrentStopVisited() }
            case .dismissSign:
                if presentedSignStopID == stop.id {
                    presentedSignStopID = nil
                    signPresentationSource = nil
                }
                // Closing the sign (by hand or by walking off) at a visited stop moves the tour on.
                shouldAdvance = stop.id == currentStop?.id && progress.isCompleted(stop.id)
            case .stopCompleted:
                break
            }
        }
        if shouldAdvance {
            completeCurrentStopAndAdvance()
        }
    }
}
