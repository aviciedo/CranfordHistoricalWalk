import SwiftUI
import TourCore

/// A quiet destination summary. Navigation and arrival never depend on learning or AR.
struct NextStopCard: View {
    @Environment(TourViewModel.self) private var tour
    var onDetails: (() -> Void)? = nil

    var body: some View {
        if let current = tour.currentStop {
            VStack(alignment: .leading, spacing: 10) {
                if tour.isWalkPaused {
                    Text("Walk paused · Destination")
                        .font(.caption).foregroundStyle(AppTheme.secondaryInk)
                } else if !tour.isHeadingToFirstStop {
                    Text("Walking to")
                        .font(.caption).foregroundStyle(AppTheme.secondaryInk)
                }
                Text(tour.isHeadingToFirstStop && !tour.isWalkPaused ? tour.startWalkTitle : current.name)
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                MapDestinationStatus()
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 24) { actions }
                    VStack(alignment: .leading, spacing: 4) { actions }
                }
                routeStatus
            }
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(AppTheme.ink)
            .padding(.horizontal, 24).padding(.bottom, 8)
            .background(AppTheme.parchment)
        }
    }

    @ViewBuilder private var actions: some View {
        if let onDetails {
            Button(action: onDetails) {
                Label("View stop", systemImage: "book")
                    .frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain).font(.subheadline.weight(.semibold))
        }
        if tour.isWalkPaused {
            Button { tour.startTour() } label: {
                Label("Resume walk", systemImage: "figure.walk").frame(minHeight: 44)
            }
            .buttonStyle(.plain).font(.subheadline.weight(.semibold))
        } else if tour.canContinueCurrentStop {
            Button { tour.completeCurrentStopAndAdvance() } label: {
                Label(tour.nextStop == nil ? "Finish walk" : "Continue to next stop", systemImage: "arrow.right")
                    .frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain).font(.subheadline.weight(.medium))
            .accessibilityHint("Changes the walking destination; listening and finding a bonus are optional")
        }
    }

    @ViewBuilder private var routeStatus: some View {
        if tour.isRouteAnEstimate || tour.routingError != nil {
            Button("Retry directions") { tour.retryWalkingRoute() }
                .frame(minHeight: 44).disabled(tour.isRoutingInFlight || tour.isWalkPaused)
        }
        if tour.isRouteAnEstimate {
            Label("Walking route unavailable · Distance is an estimate", systemImage: "info.circle")
                .font(.footnote).foregroundStyle(AppTheme.warning)
                .fixedSize(horizontal: false, vertical: true)
        } else if tour.routingError != nil {
            Label("Couldn't update directions. Showing the last route.", systemImage: "wifi.exclamationmark")
                .font(.footnote).foregroundStyle(AppTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// TimelineView needs an explicit vertical container and intrinsic text height. Without
/// these, it can be measured shorter than its distance/time text in the scrolling panel.
struct MapDestinationStatus: View {
    @Environment(TourViewModel.self) private var tour
    @ScaledMetric(relativeTo: .subheadline) private var minimumLineHeight: CGFloat = 24

    var body: some View {
        // Refresh presence even when GPS stops emitting; an old fix is not arrival.
        TimelineView(.periodic(from: .now, by: 5)) { _ in
            VStack(alignment: .leading, spacing: 8) {
                if tour.isWalkPaused {
                    Text("Resume when you’re ready.")
                        .font(.subheadline).foregroundStyle(AppTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                } else if tour.isAtCurrentStopNow {
                    Label("You’re here", systemImage: "mappin.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("map.arrived")
                } else {
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
