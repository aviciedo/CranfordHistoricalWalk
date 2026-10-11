import SwiftUI
import TourCore

/// "HISTORICAL WALK / 7 STOPS / 2.1 MILES / ~42 MINUTES" (spec §12), computed from real legs.
struct TourHeaderView: View {
    @Environment(TourViewModel.self) private var tour

    var body: some View {
        let summary = tour.tourSummary
        GlassCard(padding: 14) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    EyebrowText("Historical walk", color: AppTheme.brass)
                    HStack(spacing: 4) {
                        Text("\(summary.stopCount)")
                        Text("STOPS").font(AppTheme.Fonts.eyebrow).tracking(1.2).foregroundStyle(.secondary)
                        Text("·").foregroundStyle(.tertiary)
                        Text("\(tour.progress.completedCount) visited").font(.footnote).foregroundStyle(.secondary)
                    }
                    .font(AppTheme.Fonts.metric)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if summary.pendingLegCount > 0 && summary.totalDistanceMeters == 0 {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.mini)
                            Text("Calculating route…").font(.footnote).foregroundStyle(.secondary)
                        }
                    } else {
                        Text(DistanceFormatter.headerDistance(meters: summary.totalDistanceMeters))
                            .font(AppTheme.Fonts.metric).monospacedDigit()
                        Text(DistanceFormatter.approximateDuration(seconds: summary.totalWalkingSeconds))
                            .font(.footnote.weight(.medium)).foregroundStyle(.secondary).monospacedDigit()
                        if !summary.isFromWalkingRoutes {
                            Text(summary.pendingLegCount > 0 ? "partial" : "estimate")
                                .font(.caption2).foregroundStyle(AppTheme.warning)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
