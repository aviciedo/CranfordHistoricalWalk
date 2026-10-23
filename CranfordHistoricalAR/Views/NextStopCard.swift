import SwiftUI
import TourCore

/// One compact destination surface. The shared audio transport lives above the tab bar.
struct NextStopCard: View {
    @Environment(TourViewModel.self) private var tour
    @Environment(\.dynamicTypeSize) private var typeSize
    var onEnterAR: (() -> Void)? = nil
    var onDetails: (() -> Void)? = nil

    var body: some View {
        if let current = tour.currentStop {
            VStack(alignment: .leading, spacing: 12) {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 14) {
                        photo(for: current)
                        stopInformation(current)
                    }
                } else {
                    HStack(alignment: .center, spacing: 18) {
                        photo(for: current)
                        stopInformation(current)
                        Spacer(minLength: 0)
                    }
                }
                if let onEnterAR {
                    let isAtMill = current.hasPlaqueReference && tour.discovery.hasArrived
                    let shouldRead = isAtMill && !tour.discovery.hasFinishedStory
                    Button {
                        if shouldRead { onDetails?() }
                        else {
                            if isAtMill && !tour.discovery.hasVerifiedPlaque { tour.beginPlaqueDiscovery() }
                            onEnterAR()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Label(shouldRead ? "Read or listen" : (isAtMill ? "Discover in AR" : "View in AR"),
                                  systemImage: shouldRead ? "book" : "camera")
                            Spacer()
                            Image(systemName: "chevron.right").font(.subheadline)
                        }
                        .font(.headline).padding(.horizontal, 18)
                        .frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .buttonStyle(.plain).foregroundStyle(AppTheme.ivory)
                    .background(AppTheme.forest, in: RoundedRectangle(cornerRadius: 14))
                }
                if let onDetails {
                    Button(action: onDetails) {
                        HStack(spacing: 14) {
                            Image(systemName: "doc.text").font(.title3)
                            Text("Stop details")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.subheadline).foregroundStyle(AppTheme.secondaryInk)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .font(.body.weight(.medium)).buttonStyle(.plain)
                    Divider()
                }
                if tour.canContinueCurrentStop {
                    Button {
                        tour.completeCurrentStopAndAdvance()
                    } label: {
                        Label(tour.nextStop == nil ? "Finish tour" : "Continue to next stop", systemImage: "arrow.right")
                            .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
                routeStatus
            }
            .foregroundStyle(AppTheme.ink)
            .padding(.horizontal, 22).padding(.top, 14).padding(.bottom, 12)
            .background(AppTheme.parchment)
        }
    }

    @ViewBuilder
    private func photo(for stop: HistoricalStop) -> some View {
        if stop.hasAnyImage {
            StopPhoto(stop: stop, height: 106, cornerRadius: 12, width: 132)
        }
    }

    private func stopInformation(_ stop: HistoricalStop) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tour.isCurrentStopVisited ? "VISITED" :
                 (stop.hasPlaqueReference && tour.discovery.hasArrived ? "AT THIS STOP" : (tour.isSignPresented ? "READY TO DISCOVER" : "NEXT STOP")))
                .font(.caption.weight(.medium)).tracking(0.8)
                .foregroundStyle(AppTheme.secondaryInk)
            Text(stop.name)
                .font(.system(.title, design: .serif).weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    distance
                    Divider().frame(height: 16)
                    Text(tour.hasPlaqueConfirmedArrival ? "Arrived" : tour.remainingTimeText)
                }
                VStack(alignment: .leading, spacing: 6) {
                    distance
                    Text(tour.hasPlaqueConfirmedArrival ? "Arrived" : tour.remainingTimeText)
                }
            }
            .font(.subheadline.weight(.medium)).monospacedDigit()
            .accessibilityElement(children: .combine)
            if tour.isRoutingInFlight && tour.currentRoute == nil {
                ProgressView().controlSize(.small).accessibilityLabel("Calculating walking route")
            }
        }
    }

    private var distance: some View {
        Label {
            Text(tour.hasPlaqueConfirmedArrival ? "At plaque" : tour.remainingDistanceText)
        } icon: {
            Image(systemName: "figure.walk").foregroundStyle(AppTheme.terracotta)
        }
    }

    @ViewBuilder
    private var routeStatus: some View {
        if tour.isRouteAnEstimate {
            Label("Estimated distance · Walking route unavailable", systemImage: "info.circle")
                .font(.footnote).foregroundStyle(AppTheme.warning)
        } else if tour.routingError != nil {
            Label("Couldn't update directions. Showing the last route.", systemImage: "wifi.exclamationmark")
                .font(.footnote).foregroundStyle(AppTheme.secondaryInk)
        }
    }
}
