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
        if let current = tour.currentStop {
            VStack(alignment: .leading, spacing: 10) {
                if tour.isWalkPaused {
                    Text("Walk paused").font(.caption).foregroundStyle(AppTheme.secondaryInk)
                } else if tour.walkingProgression.isConfirmingArrival {
                    Text("Arriving at").font(.caption).foregroundStyle(AppTheme.secondaryInk)
                } else if tour.automaticTransitionFromStopID != nil && !tour.progress.isCurrentStopVisited {
                    Text("Now guiding you to").font(.caption).foregroundStyle(AppTheme.secondaryInk)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text(current.name).font(.system(.title2, design: .serif).weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Menu { moreActions } label: {
                        Image(systemName: "ellipsis").font(.title3.weight(.semibold))
                            .frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .accessibilityLabel("More walking controls")
                    .accessibilityIdentifier("map.more")
                }
                if !tour.isWalkPaused { MapDestinationStatus() }
                if tour.walkingProgression.hasArrived && !tour.isWalkPaused {
                    Text(tour.walkingProgression.isHeld ? "Staying here until you continue." : "Take your time. Directions move on when you leave.")
                        .font(.footnote).foregroundStyle(AppTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(tour.walkingProgression.isHeld ? "Guide me when I leave" : "Stay here") {
                        tour.toggleAutomaticDepartureHold()
                    }
                    .buttonStyle(.plain).font(.subheadline.weight(.medium)).frame(minHeight: 44)
                }
                if tour.walkingProgression.isHeld && !tour.walkingProgression.hasArrived {
                    Text("Continue when you’re ready to move on.")
                        .font(.footnote).foregroundStyle(AppTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if tour.isWalkPaused {
                    Button { tour.startTour() } label: {
                        Label("Resume walk", systemImage: "figure.walk").frame(minHeight: 44)
                    }
                    .buttonStyle(.plain).font(.headline)
                }
                // Undo stays discoverable immediately after an automatic transition.
                if tour.automaticTransitionFromStopID != nil {
                    Button("Undo · Stay at previous stop") { tour.undoAutomaticTransition() }
                        .buttonStyle(.plain).font(.subheadline).frame(minHeight: 44)
                        .accessibilityIdentifier("map.undoAdvance")
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { explorationActions }
                    VStack(spacing: 8) { explorationActions }
                }
                if tour.isRouteAnEstimate || tour.routingError != nil {
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
        if let previous = tour.previousStop {
            Button { tour.goToPreviousStop() } label: {
                Label("Previous stop: \(previous.name)", systemImage: "arrow.left")
            }
            .accessibilityIdentifier("map.previousStop")
        }
        if tour.canContinueCurrentStop {
            Button { tour.completeCurrentStopAndAdvance() } label: {
                Label(tour.nextStop == nil ? "Finish walk" : "Continue now", systemImage: "arrow.right")
            }
        }
        if let onShowRoute { Button("Show walking route", systemImage: "scope", action: onShowRoute) }
        if let onFollow { Button("Center on my location", systemImage: "location.fill", action: onFollow).disabled(tour.userLocation == nil) }
    }
}

/// TimelineView needs an explicit vertical container and intrinsic text height. Without
/// these, it can be measured shorter than its distance/time text in the scrolling panel.
struct MapDestinationStatus: View {
    @Environment(TourViewModel.self) private var tour
    @ScaledMetric(relativeTo: .subheadline) private var minimumLineHeight: CGFloat = 24

    private var arrivalText: String {
        if tour.userLocation?.isSimulated == true || tour.locationService is SimulatedLocationService {
            return "Practice arrival · Not saved"
        }
        return tour.isAtCurrentStopNow ? "You’re here · Visited" : "Visited · Ready when you are"
    }

    var body: some View {
        // Refresh presence even when GPS stops emitting; an old fix is not arrival.
        TimelineView(.periodic(from: .now, by: 5)) { _ in
            VStack(alignment: .leading, spacing: 8) {
                if tour.walkingProgression.hasArrived {
                    Label(arrivalText, systemImage: "checkmark.circle")
                        .font(.subheadline.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("map.arrived")
                } else {
                    if tour.progress.isCurrentStopVisited {
                        Label("Visited on this walk", systemImage: "checkmark.circle")
                            .font(.footnote).foregroundStyle(AppTheme.secondaryInk)
                    }
                    Text("\(tour.remainingDistanceText) · \(tour.remainingTimeText)")
                        .font(.subheadline).monospacedDigit()
                        .foregroundStyle(AppTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                    if tour.isRoutingInFlight && tour.currentRoute == nil {
                        ProgressView("Finding a walking route")
                            .font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if tour.locationIssue != nil && !tour.isWalkPaused {
                    Text("Waiting for a clearer location")
                        .font(.footnote).fixedSize(horizontal: false, vertical: true)
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
