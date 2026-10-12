import SwiftUI
import TourCore

/// Persistent navigation panel (spec §4, §11, §12). Values come straight from `TourViewModel`
/// and update with every location sample.
struct NextStopCard: View {
    @Environment(TourViewModel.self) private var tour
    var onEnterAR: (() -> Void)? = nil

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                switch tour.phase {
                case .inProgress:
                    inProgressContent
                case .complete:
                    EyebrowText("Tour complete")
                    Text("You visited every stop.").font(AppTheme.Fonts.title)
                case .notStarted:
                    EyebrowText("Walking tour")
                    Text(tour.loadState == .loaded ? "Ready when you are." : "Loading stops…").font(AppTheme.Fonts.title)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .animation(.easeInOut(duration: 0.25), value: tour.currentStop?.id)
    }

    @ViewBuilder
    private var inProgressContent: some View {
        if let previous = tour.lastCompletedStop {
            HStack(spacing: 6) {
                EyebrowText("Current")
                Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(AppTheme.visited)
                Text(previous.name).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        if let current = tour.currentStop {
            EyebrowText("Next stop", color: AppTheme.heritageGreen)
            Text(current.name)
                .font(AppTheme.Fonts.title)
                .lineLimit(2)
                .contentTransition(.opacity)

            HStack(alignment: .firstTextBaseline, spacing: 18) {
                metric(systemImage: "figure.walk", value: tour.remainingDistanceText)
                metric(systemImage: "clock", value: tour.remainingTimeText)
                if tour.isRoutingInFlight && tour.currentRoute == nil {
                    ProgressView().controlSize(.small)
                }
                Spacer(minLength: 0)
                if let onEnterAR {
                    Button(action: onEnterAR) {
                        Label("Enter AR", systemImage: "arkit")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(AppTheme.heritageGreen, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }

            NarrationControls(stop: current)

            footnote
        }
    }

    private func metric(systemImage: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).foregroundStyle(.secondary)
            Text(value)
                .font(AppTheme.Fonts.metric)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .animation(.easeInOut(duration: 0.2), value: value)
    }

    @ViewBuilder
    private var footnote: some View {
        if let instruction = tour.currentInstruction, !tour.isRouteAnEstimate {
            Label(instruction, systemImage: "arrow.triangle.turn.up.right.diamond")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else if tour.isRouteAnEstimate {
            Label(tour.routingError ?? "Straight-line estimate — walking route unavailable.", systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(AppTheme.warning)
                .lineLimit(2)
        } else if let error = tour.routingError {
            Label(error, systemImage: "wifi.exclamationmark")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}
