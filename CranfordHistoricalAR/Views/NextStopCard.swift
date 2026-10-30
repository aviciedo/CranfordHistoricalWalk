import SwiftUI
import TourCore

/// Destination and exploration actions; the one turn instruction lives above the map.
struct NextStopCard: View {
    @Environment(TourViewModel.self) private var tour
    var onDetails: (() -> Void)? = nil
    var onEnterAR: (() -> Void)? = nil
    var onShowRoute: (() -> Void)? = nil
    var onFollow: (() -> Void)? = nil

    var body: some View {
        if let current = tour.phase == .notStarted ? tour.stops.first : tour.currentStop {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    if tour.walkingProgression.isConfirmingArrival && !tour.isWalkPaused {
                        Text("Arriving at")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.secondaryInk)
                    } else if !tour.isCurrentVisitConfirmed {
                        Text("Next stop")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.forest.opacity(0.8))
                    }
                    HStack(alignment: .top, spacing: 12) {
                        Text(current.name)
                            .font(.system(.largeTitle, design: .serif).weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(1)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("map.destinationName")
                        Menu { moreActions } label: {
                            Image(systemName: "ellipsis").font(.body.weight(.semibold))
                                .frame(width: 44, height: 44)
                                .background(AppTheme.forest.opacity(0.05), in: Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("More walking controls")
                        .accessibilityIdentifier("map.more")
                    }
                    if tour.phase == .inProgress && (tour.isWalkingActive || tour.isCurrentVisitConfirmed) {
                        MapDestinationStatus().padding(.top, 2)
                    }
                }
                Button { tour.performMapWalkAction() } label: {
                    primaryActionLabel(primaryTitle, symbol: primarySymbol)
                }
                .buttonStyle(.plain)
                .disabled(tour.loadState != .loaded && !tour.isWalkingActive)
                .accessibilityHint(tour.isWalkingActive
                    ? "Stops directions and removes the route. You can continue later."
                    : "Starts or continues walking directions to the next stop")
                .accessibilityIdentifier(primaryIdentifier)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { explorationActions }
                    VStack(spacing: 8) { explorationActions }
                }
                if !tour.isWalkPaused && (tour.isRouteAnEstimate || tour.routingError != nil) {
                    Button("Retry directions") { tour.retryWalkingRoute() }
                        .frame(minHeight: 44).disabled(tour.isRoutingInFlight || tour.isWalkPaused)
                    Text(tour.isRouteAnEstimate ? "Walking route unavailable · Distance is an estimate" : "Couldn't update directions. Showing the last route.")
                        .font(.footnote).foregroundStyle(AppTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(AppTheme.forest)
            .padding(.horizontal, 24).padding(.bottom, 8)
            .background(AppTheme.ivory)
        }
    }

    private var primaryTitle: String {
        if tour.phase == .notStarted { return "Start walk" }
        return tour.isWalkPaused ? "Continue walk" : "Stop walk"
    }

    private var primarySymbol: String { tour.isWalkingActive ? "stop.circle" : "figure.walk" }

    private var primaryIdentifier: String {
        if tour.phase == .notStarted { return "map.startWalk" }
        return tour.isWalkPaused ? "map.resumeWalk" : "map.stopWalk"
    }

    @ViewBuilder private var explorationActions: some View {
        if let onDetails {
            Button(action: onDetails) { actionLabel("View stop", symbol: "book") }
                .buttonStyle(.plain)
        }
        if let onEnterAR {
            Button(action: onEnterAR) { actionLabel("AR directions", symbol: "camera.viewfinder") }
                .buttonStyle(.plain)
                .disabled(tour.loadState != .loaded)
                .accessibilityHint("Opens optional camera walking guidance to the current destination")
                .accessibilityIdentifier("map.enterAR")
        }
    }

    private func primaryActionLabel(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(.white)
            .background(AppTheme.forest, in: RoundedRectangle(cornerRadius: 14))
    }

    private func actionLabel(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol).font(.subheadline.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(.white, in: Capsule())
            .overlay(Capsule().strokeBorder(AppTheme.forest.opacity(0.15), lineWidth: 1))
            .contentShape(Capsule())
    }

    @ViewBuilder private var moreActions: some View {
        if tour.automaticTransitionFromStopID != nil {
            Button("Undo · Return to previous stop") { tour.undoAutomaticTransition() }
                .accessibilityIdentifier("map.undoAdvance")
        }
        if let previous = tour.previousStop {
            Button { tour.goToPreviousStop() } label: {
                Label("Previous stop: \(previous.name)", systemImage: "arrow.left")
            }
            .accessibilityIdentifier("map.previousStop")
        }
        if tour.isCurrentVisitConfirmed {
            Button { tour.startNextLegAfterConfirmedVisit() } label: {
                Label(tour.nextStop.map { "Walk to \($0.name)" } ?? "Finish walk",
                      systemImage: tour.nextStop == nil ? "checkmark" : "figure.walk")
            }
            .accessibilityIdentifier("map.startNextLeg")
        }
        if tour.canContinueCurrentStop && !tour.isCurrentVisitConfirmed {
            Button { tour.completeCurrentStopAndAdvance() } label: {
                Label(tour.nextStop == nil ? "Finish walk" : "Continue now", systemImage: "arrow.right")
            }
        }
        if let onShowRoute { Button(tour.isWalkingActive ? "Show walking route" : "Show destination", systemImage: "scope", action: onShowRoute) }
        if let onFollow { Button("Center on my location", systemImage: "location.fill", action: onFollow).disabled(tour.userLocation == nil) }
    }
}

/// TimelineView needs an explicit vertical container and intrinsic text height. Without
/// these, it can be measured shorter than its distance/time text in the scrolling panel.
struct MapDestinationStatus: View {
    @Environment(TourViewModel.self) private var tour
    @ScaledMetric(relativeTo: .title3) private var minimumLineHeight: CGFloat = 24

    private var arrivalText: String {
        if tour.userLocation?.isSimulated == true || tour.locationService is SimulatedLocationService {
            return "Practice arrival · Not saved"
        }
        return "Visited"
    }

    var body: some View {
        // Refresh presence even when GPS stops emitting; an old fix is not arrival.
        TimelineView(.periodic(from: .now, by: 5)) { _ in
            VStack(alignment: .leading, spacing: 8) {
                if tour.isCurrentVisitConfirmed {
                    Label(arrivalText, systemImage: "checkmark.circle")
                        .font(.title3.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("map.arrived")
                } else {
                    if tour.progress.isCurrentStopVisited {
                        Label("Visited on this walk", systemImage: "checkmark.circle")
                            .font(.subheadline).foregroundStyle(AppTheme.secondaryInk)
                    }
                    MapRouteSummary(distance: tour.remainingDistanceText, walkingTime: tour.remainingTimeText)
                    if tour.isRoutingInFlight && tour.currentRoute == nil {
                        ProgressView("Finding a walking route")
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if tour.locationIssue != nil && !tour.isWalkPaused {
                    Text("Waiting for a clearer location")
                        .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .task {
            while !Task.isCancelled {
                tour.refreshLocationIssue()
                try? await Task.sleep(for: .seconds(5))
            }
        }
        .frame(minHeight: minimumLineHeight, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .layoutPriority(1)
        .accessibilityIdentifier("map.destinationStatus")
    }
}

/// The active-leg summary sits below the shared destination heading. Keep each value
/// intact; narrow or accessibility-size layouts stack instead of stranding a separator.
struct MapRouteSummary: View {
    let distance: String
    let walkingTime: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Text("\(distance) · \(walkingTime)")
                .fixedSize(horizontal: true, vertical: true)
            VStack(alignment: .leading, spacing: 4) {
                Text(distance).fixedSize(horizontal: false, vertical: true)
                Text(walkingTime).fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.title3.weight(.medium)).monospacedDigit()
        .foregroundStyle(AppTheme.secondaryInk)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Remaining distance: \(distance). Walking time: \(walkingTime).")
        .accessibilityIdentifier("map.routeSummary")
    }
}
