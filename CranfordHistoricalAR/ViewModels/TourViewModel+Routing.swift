import CoreLocation
import Foundation
import TourCore

/// Routing behaviour for `TourViewModel` (spec §5, §18). Stored properties live in the class body;
/// this extension owns the policy loop and derived values.
extension TourViewModel {
    // MARK: Derived values for the navigation panel

    /// Meters left along the walking route to the current stop.
    var remainingDistanceMeters: Double? {
        if let routeProgress { return routeProgress.remainingMeters }
        return currentRoute?.distanceMeters
    }

    var remainingSeconds: TimeInterval? {
        if let routeProgress { return routeProgress.remainingSeconds }
        return currentRoute?.durationSeconds
    }

    var remainingDistanceText: String {
        remainingDistanceMeters.map { DistanceFormatter.distance(meters: $0) } ?? "—"
    }

    var remainingTimeText: String {
        remainingSeconds.map { DistanceFormatter.duration(seconds: $0) } ?? "—"
    }

    var isRouteAnEstimate: Bool { currentRoute?.source == .straightLineEstimate }

    /// The current turn instruction, when the provider supplied steps.
    var currentInstruction: String? {
        guard let route = currentRoute, let index = routeProgress?.currentStepIndex, route.routeSteps.indices.contains(index) else { return nil }
        return route.routeSteps[index].instruction
    }

    /// Next vertex ahead on the route, used by AR arrows. Falls back to the stop itself.
    var nextWaypointCoordinate: GeoCoordinate? {
        routeProgress?.nextWaypoint ?? currentStop?.coordinate
    }

    /// Bearing from the user to the next waypoint (route-aware), else to the stop.
    var bearingToNextWaypoint: Double? {
        guard let userLocation, let target = nextWaypointCoordinate else { return nil }
        return GeoMath.bearing(from: userLocation.coordinate, to: target)
    }

    /// Aggregate figures for the header / completion screen (spec §12).
    var tourSummary: TourSummary {
        TourSummary.make(stops: stops, legs: summaryLegs())
    }

    /// Figures for the TOUR COMPLETE screen (spec §12). Distance prefers what was actually measured
    /// from location updates; it falls back to the routed total when the device barely moved
    /// (e.g. a simulated or jumped-through tour) so the screen is never blank.
    var completionFigures: TourCompletionFigures {
        let summary = tourSummary
        let distance = TourCompletionDistance.select(walkedMeters: progress.walkedMeters, routedMeters: summary.totalDistanceMeters)
        return TourCompletionFigures(
            distanceMeters: distance.meters,
            isDistanceMeasured: distance.isMeasured,
            walkingSeconds: summary.totalWalkingSeconds,
            elapsedSeconds: progress.elapsed,
            visitedCount: progress.completedCount,
            totalStops: progress.totalStops,
            isFromWalkingRoutes: summary.isFromWalkingRoutes
        )
    }

    /// Legs: user → first stop (or first-stop placeholder) then stop i → stop i+1.
    private func summaryLegs() -> [WalkingRoute?] {
        guard !stops.isEmpty else { return [] }
        var legs: [WalkingRoute?] = []
        legs.append(legRoutes[TourViewModel.startLegKey])
        for i in 1..<stops.count {
            legs.append(legRoutes[TourViewModel.legKey(from: stops[i - 1], to: stops[i])])
        }
        return legs
    }

    static let startLegKey = "start"
    static func legKey(from a: HistoricalStop, to b: HistoricalStop) -> String { "\(a.id)->\(b.id)" }

    // MARK: Location-driven updates

    /// Called by the location pipeline on every accepted sample.
    func handleLocationForRouting(_ sample: LocationSample) {
        guard progress.phase == .inProgress, let destination = currentStop?.coordinate else { return }
        if let route = currentRoute {
            routeProgress = RouteProgressCalculator.progress(along: route, userLocation: sample.coordinate)
        }
        evaluateRouteRefresh(userLocation: sample.coordinate, destination: destination)
    }

    /// Re-evaluates the refresh policy; call after the destination changes too.
    func evaluateRouteRefresh(userLocation: GeoCoordinate? = nil, destination: GeoCoordinate? = nil) {
        guard progress.phase == .inProgress else { return }
        guard let user = userLocation ?? self.userLocation?.coordinate,
              let dest = destination ?? currentStop?.coordinate else { return }
        guard routingTask == nil else { return }

        let context = RouteRefreshPolicy.Context(
            currentRoute: currentRoute,
            currentDestination: dest,
            userLocation: user,
            progress: routeProgress,
            lastRequestOrigin: lastRouteRequest?.origin,
            lastRequestDestination: lastRouteRequest?.destination,
            lastRequestDate: lastRouteRequest?.date
        )
        guard let reason = refreshPolicy.refreshReason(for: context) else { return }
        requestRoute(from: user, to: dest, reason: reason)
    }

    func requestRoute(from origin: GeoCoordinate, to destination: GeoCoordinate, reason: RouteRefreshReason) {
        routingTask?.cancel()
        routingGeneration += 1
        let generation = routingGeneration
        lastRouteRequest = RouteRequestRecord(origin: origin, destination: destination, date: Date(), reason: reason)
        isRoutingInFlight = true
        let service = directionsService
        routingTask = Task { @MainActor [weak self] in
            defer { self?.finishRoutingTask(generation: generation) }
            do {
                let route = try await service.walkingRoute(from: origin.clLocationCoordinate, to: destination.clLocationCoordinate)
                guard !Task.isCancelled else { return }
                self?.applyRoute(route, for: destination)
            } catch {
                guard !Task.isCancelled else { return }
                self?.handleRoutingFailure(error, origin: origin, destination: destination)
            }
        }
    }

    /// Only the newest request may clear the in-flight state; superseded tasks must not touch it.
    private func finishRoutingTask(generation: Int) {
        guard generation == routingGeneration else { return }
        routingTask = nil
        isRoutingInFlight = false
    }

    private func applyRoute(_ route: WalkingRoute, for destination: GeoCoordinate) {
        // The stop may have advanced while the request was in flight.
        guard let current = currentStop?.coordinate, GeoMath.distance(from: current, to: destination) < 1 else { return }
        currentRoute = route
        routingError = nil
        if let userLocation {
            routeProgress = RouteProgressCalculator.progress(along: route, userLocation: userLocation.coordinate)
        } else {
            routeProgress = nil
        }
        if let stop = currentStop {
            cacheLeg(route, forStop: stop)
        }
    }

    private func handleRoutingFailure(_ error: Error, origin: GeoCoordinate, destination: GeoCoordinate) {
        let described = (error as? DirectionsError)?.errorDescription ?? error.localizedDescription
        routingError = described
        // Spec §21: keep the last known route; only estimate when we have nothing for this destination.
        if let existing = currentRoute, GeoMath.distance(from: existing.destination, to: destination) < 1 {
            return
        }
        let estimate = WalkingRoute.straightLineEstimate(from: origin, to: destination)
        currentRoute = estimate
        routeProgress = RouteProgressCalculator.progress(along: estimate, userLocation: origin)
    }

    /// The live leg to the first stop doubles as the "start" leg of the tour summary.
    private func cacheLeg(_ route: WalkingRoute, forStop stop: HistoricalStop) {
        if stop.id == stops.first?.id, legRoutes[TourViewModel.startLegKey] == nil || legRoutes[TourViewModel.startLegKey]?.source == .straightLineEstimate {
            legRoutes[TourViewModel.startLegKey] = route
        }
    }

    // MARK: Destination changes

    /// Clears per-stop routing state when the destination changes and asks for a new route.
    func destinationDidChange() {
        routingTask?.cancel()
        routingTask = nil
        isRoutingInFlight = false
        currentRoute = nil
        routeProgress = nil
        routingError = nil
        resetProximityForCurrentStop()
        evaluateRouteRefresh()
    }

    // MARK: Tour summary legs (spec §12: computed from actual walking routes)

    /// Fetches stop→stop legs once per tour, sequentially and cancellably, so the header can show
    /// "2.1 MILES / ~42 MINUTES" from real walking routes. The user→first-stop leg comes from live routing.
    func loadTourSummaryLegsIfNeeded() {
        guard summaryLegsTask == nil, stops.count >= 2 else { return }
        let pairs: [(key: String, from: GeoCoordinate, to: GeoCoordinate)] = (1..<stops.count).compactMap { i in
            let key = TourViewModel.legKey(from: stops[i - 1], to: stops[i])
            guard legRoutes[key] == nil else { return nil }
            return (key, stops[i - 1].coordinate, stops[i].coordinate)
        }
        guard !pairs.isEmpty else { return }
        let service = directionsService
        summaryLegsTask = Task { @MainActor [weak self] in
            for pair in pairs {
                if Task.isCancelled { break }
                do {
                    let route = try await service.walkingRoute(from: pair.from.clLocationCoordinate, to: pair.to.clLocationCoordinate)
                    self?.storeLeg(route, key: pair.key)
                } catch {
                    guard !Task.isCancelled else { break }
                    let estimate = WalkingRoute.straightLineEstimate(from: pair.from, to: pair.to)
                    self?.storeLeg(estimate, key: pair.key)
                }
            }
            self?.summaryLegsFinished()
        }
        if legRoutes[TourViewModel.startLegKey] == nil, let user = userLocation?.coordinate, let first = stops.first {
            legRoutes[TourViewModel.startLegKey] = WalkingRoute.straightLineEstimate(from: user, to: first.coordinate)
        }
    }

    private func storeLeg(_ route: WalkingRoute, key: String) {
        legRoutes[key] = route
    }

    private func summaryLegsFinished() {
        summaryLegsTask = nil
    }

    func cancelRouting() {
        routingTask?.cancel()
        routingTask = nil
        summaryLegsTask?.cancel()
        summaryLegsTask = nil
        isRoutingInFlight = false
    }
}

struct TourCompletionFigures: Equatable {
    var distanceMeters: Double
    var isDistanceMeasured: Bool
    var walkingSeconds: TimeInterval
    var elapsedSeconds: TimeInterval?
    var visitedCount: Int
    var totalStops: Int
    var isFromWalkingRoutes: Bool
}

struct RouteRequestRecord: Equatable, Sendable {
    var origin: GeoCoordinate
    var destination: GeoCoordinate
    var date: Date
    var reason: RouteRefreshReason
}
