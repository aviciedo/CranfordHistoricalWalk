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

    /// True once arrival has made the marker available; activation is tracked separately.
    var hasArrivedAtCurrentStop: Bool { proximityMachine?.hasPresentedSign ?? false }

    var isWithinArrivalRadius: Bool { proximityMachine?.isWithinArrivalRadius ?? false }

    var hasPlaqueConfirmedArrival: Bool {
        guard let currentStop else { return false }
        return plaqueConfirmedStopID == currentStop.id
    }

    /// A matching physical plaque is stronger arrival evidence than the unverified GPS geocode.
    func confirmPlaqueArrival(for stopID: String) {
        guard progress.phase == .inProgress, let stop = currentStop,
              stop.id == stopID, stop.hasPlaqueReference,
              proximityMachine?.hasManuallyDismissed == false else { return }
        plaqueConfirmedStopID = stopID
        if !isSignPresented { openSignManually() }
    }

    /// Builds a fresh state machine for the current stop. Called whenever the destination changes.
    func resetProximityForCurrentStop() {
        plaqueConfirmedStopID = nil
        activeVisitEvidence = nil
        if let discoveryStopID { discoveriesByStopID[discoveryStopID] = discovery }
        discoveryStopID = currentStop?.id
        discovery = discoveryStopID.flatMap { discoveriesByStopID[$0] } ?? StopDiscovery()
        arrivalStoryStopID = nil
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
        // Do not immediately dismiss a visually confirmed stop because its bundled geocode is wrong.
        // Continuing clears this confirmation; simply closing the card never advances.
        guard !hasPlaqueConfirmedArrival, !isCurrentStopVisited else { return }
        // Ignore wildly inaccurate fixes so a 200 m GPS jump cannot open/close the sign.
        guard sample.coordinate.isValid, StopActivationPolicy.isFresh(sample.timestamp),
              sample.horizontalAccuracy >= 0, sample.horizontalAccuracy <= 100 else { return }
        let distance = GeoMath.distance(from: sample.coordinate, to: stop.coordinate)
        let effects = machine.handle(.distanceUpdated(meters: distance))
        proximityMachine = machine
        apply(effects, for: stop, source: .automatic)
        // Outside AR discovery, a reliable GPS arrival completes the destination.
        // Hold plaque sites during AR so GPS cannot reset the story or discovery mid-scan.
        // Evaluate each location fix at most once, so a stop change cannot reuse the same
        // stationary fix to cascade through two nearby tour destinations.
        if !(stop.hasPlaqueReference && (isARSessionActive || arDiscoveryStopID == stop.id)),
           lastAutomaticVisitSampleTimestamp != sample.timestamp,
           sample.horizontalAccuracy <= StopActivationPolicy.maximumAccuracyMeters,
           distance + sample.horizontalAccuracy <= stop.arrivalRadius {
            lastAutomaticVisitSampleTimestamp = sample.timestamp
            let decision = StopActivationPolicy.decide(
                trackingReady: true, // Core Location arrival needs no AR camera session.
                plaqueIsTracked: false,
                isSimulated: sample.isSimulated || locationService is SimulatedLocationService,
                distanceMeters: distance,
                horizontalAccuracy: sample.horizontalAccuracy,
                locationTimestamp: sample.timestamp,
                arrivalRadius: stop.arrivalRadius
            )
            if case .allow(let evidence) = decision {
                progress.markCurrentStopVisited()
                activeVisitEvidence = evidence
                #if DEVELOPER_MENU
                if isVisitRecordingEnabled {
                    visitStore.record(StopVisitRecord(stopID: stop.id, activatedAt: Date(), evidence: evidence))
                }
                #else
                visitStore.record(StopVisitRecord(stopID: stop.id, activatedAt: Date(), evidence: evidence))
                #endif
                visitRecords = visitStore.records()
                completeCurrentStopAndAdvance()
                return
            }
        }
        if stop.hasPlaqueReference {
            var viewingPoint = stop.coordinate
            #if DEVELOPER_MENU
            if stop.plaque?.referenceImageName == SignPlacementPolicy.millReferenceImageName {
                viewingPoint = viewingPointOverride ?? viewingPoint
            }
            #endif
            let viewingDistance = GeoMath.distance(from: sample.coordinate, to: viewingPoint)
            if sample.horizontalAccuracy <= StopActivationPolicy.maximumAccuracyMeters,
               viewingDistance + sample.horizontalAccuracy <= stop.arrivalRadius,
               discovery.arrive() { arrivalStoryStopID = stop.id }
        }
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

    // MARK: Marker activation / visits

    /// A marker becoming visible is arrival, not a visit. Only an explicit on-site
    /// activation from the running AR session can mark the current stop visited.
    @discardableResult
    func activateCurrentStop(stopID: String, trackingReady: Bool, plaqueIsTracked: Bool, now: Date = Date()) -> StopActivationDecision {
        guard progress.phase == .inProgress, let stop = currentStop, stop.id == stopID else { return .deny(.wrongStop) }
        // A GPS visit must not prevent a subsequent, stronger plaque verification.
        if isCurrentStopVisited && (!stop.hasPlaqueReference || discovery.hasVerifiedPlaque) { return .alreadyActivated }
        guard isSignPresented else { return .deny(.markerNotReady) }
        if stop.hasPlaqueReference,
           discovery.stage != .searching || !plaqueIsTracked || !hasPlaqueConfirmedArrival {
            return .deny(.markerNotReady)
        }
        let sample = userLocation
        let matchingPlaque = plaqueIsTracked && stop.hasPlaqueReference && hasPlaqueConfirmedArrival
        let distance = sample.map { GeoMath.distance(from: $0.coordinate, to: stop.coordinate) }
        let decision = StopActivationPolicy.decide(
            trackingReady: trackingReady,
            plaqueIsTracked: matchingPlaque,
            isSimulated: sample?.isSimulated == true || locationService is SimulatedLocationService,
            distanceMeters: distance,
            horizontalAccuracy: sample?.horizontalAccuracy,
            locationTimestamp: sample?.timestamp,
            arrivalRadius: stop.arrivalRadius,
            now: now
        )
        guard case .allow(let evidence) = decision else { return decision }
        progress.markCurrentStopVisited()
        activeVisitEvidence = evidence
        if stop.hasPlaqueReference {
            discovery.recognizePlaque(isMatching: true, trackingReady: trackingReady, isSimulated: evidence == .simulation)
        }
        #if DEVELOPER_MENU
        if isVisitRecordingEnabled {
            visitStore.record(StopVisitRecord(stopID: stop.id, activatedAt: now, evidence: evidence))
        }
        #else
        visitStore.record(StopVisitRecord(stopID: stop.id, activatedAt: now, evidence: evidence))
        #endif
        visitRecords = visitStore.records()
        return decision
    }

    /// A tracked bundled plaque identifies its own site, even when the guided walk is stale.
    /// Selection offers that site's story; verification still requires the discovery flow.
    @discardableResult
    func selectRecognizedPlaque(imageName: String?, isTracked: Bool, trackingReady: Bool) -> Bool {
        guard let stop = SignPlacementPolicy.recognizedStop(imageName: imageName, isTracked: isTracked,
                                                           trackingReady: trackingReady, stops: stops),
              !continuedARStopIDs.contains(stop.id) else { return false }
        if arDiscoveryStopID != stop.id { arDiscoveryStopID = stop.id }
        if currentStop?.id != stop.id {
            guard progress.selectStop(withID: stop.id) else { return false }
            destinationDidChange()
        }
        return true
    }

    /// Also called when the camera cannot start, so a denied/unsupported AR screen
    /// cannot leave ordinary GPS arrival suspended after the visitor returns to the map.
    func endARDiscoverySession() {
        isARSessionActive = false
        arDiscoveryStopID = nil
        continuedARStopIDs = []
    }

    func lastRecordedVisit(for stop: HistoricalStop) -> StopVisitRecord? {
        visitRecords.filter { $0.stopID == stop.id }.max { $0.activatedAt < $1.activatedAt }
    }

    var isCurrentStopVisited: Bool { progress.isCurrentStopVisited }

    /// Explicit Continue releases the site's discovery hold and advances. Map-only reliable
    /// GPS arrival also uses this path; closing a story card never advances the walk.
    func completeCurrentStopAndAdvance() {
        guard progress.phase == .inProgress, let stop = currentStop,
              isCurrentStopVisited || (stop.hasPlaqueReference && discovery.canContinue) else { return }
        proximityMachine?.handle(.markCompleted)
        presentedSignStopID = nil
        signPresentationSource = nil
        if isARSessionActive { continuedARStopIDs.insert(stop.id) }
        arDiscoveryStopID = nil
        progress.completeCurrentStop()
        destinationDidChange()
    }

    var isPlaqueDiscoveryStop: Bool { currentStop?.hasPlaqueReference == true }
    var isMillDiscoveryStop: Bool { currentStop?.plaque?.referenceImageName == SignPlacementPolicy.millReferenceImageName }
    var currentBonusLayout: WindowBonusLayout { isMillDiscoveryStop ? windowBonusLayout : parkBonusLayout }
    var canContinueCurrentStop: Bool { isCurrentStopVisited || (isPlaqueDiscoveryStop && discovery.canContinue) }

    func openStory(for stopID: String) {
        guard currentStop?.id == stopID, isPlaqueDiscoveryStop else { return }
        arrivalStoryStopID = nil
        discovery.openStory()
    }

    func finishStory(for stopID: String) {
        guard currentStop?.id == stopID, isPlaqueDiscoveryStop else { return }
        discovery.finishStory()
    }

    @discardableResult
    func beginPlaqueDiscovery() -> Bool {
        guard isPlaqueDiscoveryStop, discovery.beginDiscovery() else { return false }
        if discovery.hasVerifiedPlaque { return true }
        arrivalStoryStopID = nil
        arDiscoveryStopID = currentStop?.id
        // Re-arm a dismissed generic marker; the discovery camera will not show that marker.
        proximityMachine = currentStop.map { StopProximityStateMachine(stop: $0) }
        if let userLocation { handleLocationForProximity(userLocation) }
        return true
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
