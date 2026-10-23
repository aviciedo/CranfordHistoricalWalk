import SwiftUI
import TourCore

/// A quiet destination summary. Navigation and arrival never depend on learning or AR.
struct NextStopCard: View {
    @Environment(TourViewModel.self) private var tour
    var onDetails: (() -> Void)? = nil

    var body: some View {
        if let current = tour.currentStop {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(current.name)
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Text("Stop \(current.order) of \(tour.stops.count)")
                        .font(.caption).foregroundStyle(AppTheme.secondaryInk)
                }
                // Refresh presence even if the GPS stops emitting; a stale fix is not arrival.
                TimelineView(.periodic(from: .now, by: 5)) { _ in
                    if tour.isAtCurrentStopNow {
                        Label("You’re here", systemImage: "mappin.circle.fill")
                            .font(.subheadline.weight(.medium))
                            .accessibilityIdentifier("map.arrived")
                    } else {
                        Text("\(tour.remainingDistanceText) · \(tour.remainingTimeText)")
                            .font(.subheadline).monospacedDigit()
                            .foregroundStyle(AppTheme.secondaryInk)
                        if tour.isRoutingInFlight && tour.currentRoute == nil {
                            ProgressView("Finding a walking route").font(.footnote)
                        }
                    }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 24) { actions }
                    VStack(alignment: .leading, spacing: 4) { actions }
                }
                routeStatus
            }
            .foregroundStyle(AppTheme.ink)
            .padding(.horizontal, 22).padding(.vertical, 12)
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
        if tour.canContinueCurrentStop {
            Button { tour.completeCurrentStopAndAdvance() } label: {
                Label(tour.nextStop == nil ? "Finish walk" : "Continue to next stop", systemImage: "arrow.right")
                    .frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain).font(.subheadline.weight(.medium))
            .accessibilityHint("Changes the walking destination; listening and finding a bonus are optional")
        }
    }

    @ViewBuilder private var routeStatus: some View {
        if tour.isRouteAnEstimate {
            Label("Walking route unavailable · Distance is an estimate", systemImage: "info.circle")
                .font(.footnote).foregroundStyle(AppTheme.warning)
        } else if tour.routingError != nil {
            Label("Couldn't update directions. Showing the last route.", systemImage: "wifi.exclamationmark")
                .font(.footnote).foregroundStyle(AppTheme.secondaryInk)
        }
    }
}
