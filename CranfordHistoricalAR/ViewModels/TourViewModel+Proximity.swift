import Foundation
import TourCore

extension TourViewModel {
    enum SignPresentationSource: Equatable { case automatic, manual }
    var presentedSignStop: HistoricalStop? { presentedSignStopID.flatMap(stop(withID:)) }
    var isSignPresented: Bool { presentedSignStopID != nil }
    var proximityState: StopProximityState? { proximityMachine?.state }
    var hasArrivedAtCurrentStop: Bool { proximityMachine?.hasPresentedSign ?? false }
    var isWithinArrivalRadius: Bool { proximityMachine?.isWithinArrivalRadius ?? false }
    var hasPlaqueConfirmedArrival: Bool { arStop?.id == plaqueConfirmedStopID && plaqueConfirmedStopID != nil }
    var isARStopVisited: Bool { arStop.map { activities[$0.id].visitedAt != nil || ($0.id == currentStop?.id && progress.isCurrentStopVisited) } ?? false }

    func restoreDiscovery(for stopID: String) {
        var state = discoveriesByStopID[stopID] ?? StopDiscovery()
        let saved = activities[stopID]
        if saved.learningCompleted { state.finishStory() }
        if saved.bonusFoundAt != nil && !state.hasVerifiedPlaque {
            state.beginDiscovery()
            state.recognizePlaque(isMatching: true, trackingReady: true, isSimulated: false)
        }
        discoveriesByStopID[stopID] = state
    }

    func finishListening(for stopID: String) {
        guard let stop = stop(withID: stopID), stop.narrationSource != nil else { return }
        activities.listened(to: stopID)
        activityStore.save(activities)
        restoreDiscovery(for: stopID)
    }

    /// An explicit reading acknowledgement; merely opening Read never claims completion.
    func finishStory(for stopID: String) {
        guard let stop = stop(withID: stopID),
              !(stop.narrationText ?? stop.longDescription).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        activities.read(stopID)
        activityStore.save(activities)
        restoreDiscovery(for: stopID)
    }

    func confirmPlaqueArrival(for stopID: String) {
        guard arStop?.id == stopID, arStop?.hasPlaqueReference == true else { return }
        plaqueConfirmedStopID = stopID
        presentedSignStopID = stopID
        signPresentationSource = .manual
    }

    func resetProximityForCurrentStop() {
        plaqueConfirmedStopID = nil
        activeVisitEvidence = nil
        arrivalStoryStopID = nil
        presentedSignStopID = nil
        signPresentationSource = nil
        guard let stop = currentStop else { proximityMachine = nil; return }
        restoreDiscovery(for: stop.id)
        proximityMachine = StopProximityStateMachine(stop: stop)
        if let userLocation { handleLocationForProximity(userLocation) }
    }

    /// Physical visits do not finish stories, find bonuses, change playback or advance routing.
    func handleLocationForProximity(_ sample: LocationSample) {
        guard sample.coordinate.isValid, StopActivationPolicy.isFresh(sample.timestamp),
              sample.horizontalAccuracy >= 0, sample.horizontalAccuracy <= 100 else { return }
        let practice = sample.isSimulated || locationService is SimulatedLocationService
        for stop in stops {
            let distance = GeoMath.distance(from: sample.coordinate, to: stop.coordinate)
            if case .allow = StopActivationPolicy.decide(trackingReady: true, plaqueIsTracked: false,
                isSimulated: practice, distanceMeters: distance, horizontalAccuracy: sample.horizontalAccuracy,
                locationTimestamp: sample.timestamp, arrivalRadius: stop.arrivalRadius) {
                if stop.id == currentStop?.id { progress.markCurrentStopVisited() }
                if !practice && activities[stop.id].visitedAt == nil {
                    savePhysicalActivity(for: stop.id, evidence: .onSiteARMarker, now: Date())
                }
            }
        }
        guard phase == .inProgress, let stop = currentStop, var machine = proximityMachine,
              arDiscoveryStopID == nil || arDiscoveryStopID == stop.id,
              !hasPlaqueConfirmedArrival else { return }
        let distance = GeoMath.distance(from: sample.coordinate, to: stop.coordinate)
        let effects = machine.handle(.distanceUpdated(meters: distance))
        proximityMachine = machine
        apply(effects, for: stop, source: .automatic)
        if stop.hasPlaqueReference {
            var point = stop.coordinate
            #if DEVELOPER_MENU
            if stop.plaque?.referenceImageName == SignPlacementPolicy.millReferenceImageName {
                point = viewingPointOverride ?? point
            }
            #endif
            let viewingDistance = GeoMath.distance(from: sample.coordinate, to: point)
            if sample.horizontalAccuracy <= StopActivationPolicy.maximumAccuracyMeters,
               viewingDistance + sample.horizontalAccuracy <= stop.arrivalRadius,
               discovery.arrive() { arrivalStoryStopID = stop.id }
        }
    }

    func openSignManually() {
        guard let stop = arStop else { return }
        if stop.id != currentStop?.id {
            presentedSignStopID = stop.id
            signPresentationSource = .manual
            return
        }
        guard var machine = proximityMachine else { return }
        let effects = machine.handle(.userOpenedSign)
        proximityMachine = machine
        apply(effects, for: stop, source: .manual)
    }

    func closeSign() {
        guard let stop = arStop, stop.id == currentStop?.id, var machine = proximityMachine else {
            presentedSignStopID = nil; return
        }
        let effects = machine.handle(.userClosedSign)
        proximityMachine = machine
        apply(effects, for: stop, source: .manual)
    }

    @discardableResult
    func activateCurrentStop(stopID: String, trackingReady: Bool, plaqueIsTracked: Bool, now: Date = Date()) -> StopActivationDecision {
        guard let stop = arStop, stop.id == stopID else { return .deny(.wrongStop) }
        if stop.hasPlaqueReference && discovery.hasVerifiedPlaque { return .alreadyActivated }
        if !stop.hasPlaqueReference && isARStopVisited { return .alreadyActivated }
        guard isSignPresented else { return .deny(.markerNotReady) }
        if stop.hasPlaqueReference,
           discovery.stage != .searching || !plaqueIsTracked || !hasPlaqueConfirmedArrival { return .deny(.markerNotReady) }
        let sample = userLocation
        let decision = StopActivationPolicy.decide(trackingReady: trackingReady,
            plaqueIsTracked: plaqueIsTracked && stop.hasPlaqueReference && hasPlaqueConfirmedArrival,
            isSimulated: sample?.isSimulated == true || locationService is SimulatedLocationService,
            distanceMeters: sample.map { GeoMath.distance(from: $0.coordinate, to: stop.coordinate) },
            horizontalAccuracy: sample?.horizontalAccuracy, locationTimestamp: sample?.timestamp,
            arrivalRadius: stop.arrivalRadius, now: now)
        guard case .allow(let evidence) = decision else { return decision }
        if stop.id == currentStop?.id { progress.markCurrentStopVisited() }
        activeVisitEvidence = evidence
        if stop.hasPlaqueReference {
            discovery.recognizePlaque(isMatching: true, trackingReady: trackingReady, isSimulated: evidence == .simulation)
        }
        savePhysicalActivity(for: stop.id, evidence: evidence, now: now)
        return decision
    }

    private func savePhysicalActivity(for stopID: String, evidence: StopVisitEvidence, now: Date) {
        guard evidence != .simulation else { return }
        #if DEVELOPER_MENU
        guard isVisitRecordingEnabled else { return }
        #endif
        activities.visited(stopID, at: now)
        if evidence == .recognizedPlaque { activities.foundBonus(at: stopID, date: now) }
        activityStore.save(activities)
        visitStore.record(StopVisitRecord(stopID: stopID, activatedAt: now, evidence: evidence))
        visitRecords = visitStore.records()
    }

    /// Recognition selects an AR subject, never the guided walking destination.
    @discardableResult
    func selectRecognizedPlaque(imageName: String?, isTracked: Bool, trackingReady: Bool) -> Bool {
        guard let stop = SignPlacementPolicy.recognizedStop(imageName: imageName, isTracked: isTracked,
            trackingReady: trackingReady, stops: stops), !continuedARStopIDs.contains(stop.id) else { return false }
        if arDiscoveryStopID != stop.id {
            arDiscoveryStopID = stop.id
            plaqueConfirmedStopID = nil
            presentedSignStopID = nil
        }
        restoreDiscovery(for: stop.id)
        return true
    }

    func endARDiscoverySession() {
        isARSessionActive = false
        arDiscoveryStopID = nil
        plaqueConfirmedStopID = nil
        continuedARStopIDs = []
    }

    func lastRecordedVisit(for stop: HistoricalStop) -> StopVisitRecord? {
        visitRecords.filter { $0.stopID == stop.id }.max { $0.activatedAt < $1.activatedAt }
    }
    var isCurrentStopVisited: Bool { currentStop.map { progress.isCurrentStopVisited || activities[$0.id].visitedAt != nil } ?? false }
    var canContinueCurrentStop: Bool { phase == .inProgress && currentStop != nil }
    var canContinueARStop: Bool { canContinueCurrentStop && arStop?.id == currentStop?.id }

    /// Advancing an itinerary is not proof of a physical visit or learning completion.
    func completeCurrentStopAndAdvance() {
        guard canContinueCurrentStop, let stop = currentStop else { return }
        if isARSessionActive { continuedARStopIDs.insert(stop.id) }
        arDiscoveryStopID = nil
        progress.advanceCurrentStop()
        destinationDidChange()
    }

    var isPlaqueDiscoveryStop: Bool { arStop?.hasPlaqueReference == true }
    var isMillDiscoveryStop: Bool { arStop?.plaque?.referenceImageName == SignPlacementPolicy.millReferenceImageName }
    var currentBonusLayout: WindowBonusLayout { isMillDiscoveryStop ? windowBonusLayout : parkBonusLayout }

    func openStory(for stopID: String) {
        guard stop(withID: stopID) != nil else { return }
        restoreDiscovery(for: stopID)
        var state = discoveriesByStopID[stopID] ?? StopDiscovery()
        state.openStory()
        discoveriesByStopID[stopID] = state
        if arrivalStoryStopID == stopID { arrivalStoryStopID = nil }
    }

    @discardableResult
    func beginPlaqueDiscovery() -> Bool {
        guard isPlaqueDiscoveryStop else { return false }
        arrivalStoryStopID = nil
        return discovery.beginDiscovery()
    }

    private func apply(_ effects: [StopProximityEffect], for stop: HistoricalStop, source: SignPresentationSource) {
        for effect in effects {
            switch effect {
            case .presentSign: presentedSignStopID = stop.id; signPresentationSource = source
            case .dismissSign:
                if presentedSignStopID == stop.id { presentedSignStopID = nil; signPresentationSource = nil }
            case .stopCompleted: break
            }
        }
    }
}
