import SwiftUI
import TourCore

/// One compact destination surface. The shared audio transport lives above the tab bar.
struct NextStopCard: View {
    @Environment(TourViewModel.self) private var tour
    var onEnterAR: (() -> Void)? = nil
    var onDetails: (() -> Void)? = nil

    var body: some View {
        if let current = tour.currentStop {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 16) {
                    if current.hasAnyImage {
                        StopPhoto(stop: current, height: 88, cornerRadius: 12, width: 88)
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        Text(tour.isSignPresented ? "You've arrived" : "Next stop")
                            .font(.subheadline).foregroundStyle(AppTheme.secondaryInk)
                        Text(current.name)
                            .font(.system(.title2, design: .serif).weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 16) {
                            Label(tour.hasPlaqueConfirmedArrival ? "At plaque" : tour.remainingDistanceText, systemImage: "figure.walk")
                            Label(tour.hasPlaqueConfirmedArrival ? "Arrived" : tour.remainingTimeText, systemImage: "clock")
                            if tour.isRoutingInFlight && tour.currentRoute == nil {
                                ProgressView().controlSize(.small)
                            }
                        }
                        .font(.subheadline.weight(.medium)).monospacedDigit()
                        .accessibilityElement(children: .combine)
                    }
                    Spacer(minLength: 0)
                }
                if let onEnterAR {
                    Button(action: onEnterAR) {
                        HStack {
                            Spacer()
                            Label("View in AR", systemImage: "camera.viewfinder")
                            Spacer()
                            Image(systemName: "chevron.right").font(.subheadline)
                        }
                        .font(.headline).padding(.horizontal, 18).padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain).foregroundStyle(AppTheme.ivory)
                    .background(AppTheme.forest, in: RoundedRectangle(cornerRadius: 14))
                }
                if let onDetails {
                    Button(action: onDetails) {
                        HStack {
                            Label("Stop details", systemImage: "doc.text")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(.body.weight(.medium)).frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
                if tour.isSignPresented {
                    Button {
                        tour.closeSign()
                    } label: {
                        Label(tour.nextStop == nil ? "Finish tour" : "Continue to next stop", systemImage: "arrow.right")
                            .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
                routeStatus
            }
            .foregroundStyle(AppTheme.ink)
            .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)
            .background(AppTheme.parchment)
        }
    }

    @ViewBuilder
    private var routeStatus: some View {
        if tour.isRouteAnEstimate {
            Label("Estimated distance · Walking route unavailable", systemImage: "info.circle")
                .font(.footnote).foregroundStyle(AppTheme.warning)
        } else if let instruction = tour.currentInstruction {
            Text(instruction).font(.footnote).foregroundStyle(AppTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        } else if tour.routingError != nil {
            Label("Couldn't update directions. Showing the last route.", systemImage: "wifi.exclamationmark")
                .font(.footnote).foregroundStyle(AppTheme.secondaryInk)
        }
    }
}
