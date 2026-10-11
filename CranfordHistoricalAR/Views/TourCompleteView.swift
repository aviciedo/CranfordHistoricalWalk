import SwiftUI
import TourCore

/// "TOUR COMPLETE" (spec §12): total distance, total walking time, sites visited.
/// Figures come from the tour's routed legs and recorded movement — nothing is hard-coded.
struct TourCompleteView: View {
    @Environment(TourViewModel.self) private var tour

    var body: some View {
        let figures = tour.completionFigures
        ZStack {
            AppTheme.parchment.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(AppTheme.brass)
                        EyebrowText("Tour complete", color: AppTheme.brass)
                        Text(tour.tourName)
                            .font(AppTheme.Fonts.display(34))
                            .foregroundStyle(AppTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 36)

                    VStack(spacing: 0) {
                        statRow(
                            label: "Total distance",
                            value: DistanceFormatter.distance(meters: figures.distanceMeters),
                            detail: figures.isDistanceMeasured ? "measured from your walk" : "from the walking route",
                            systemImage: "figure.walk"
                        )
                        Divider().padding(.leading, 52)
                        statRow(
                            label: "Walking time",
                            value: DistanceFormatter.duration(seconds: figures.walkingSeconds),
                            detail: elapsedDetail(figures),
                            systemImage: "clock"
                        )
                        Divider().padding(.leading, 52)
                        statRow(
                            label: "Historical sites visited",
                            value: "\(figures.visitedCount) of \(figures.totalStops)",
                            detail: nil,
                            systemImage: "building.columns"
                        )
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))

                    if !figures.isFromWalkingRoutes {
                        Label("Some legs used straight-line estimates because walking directions were unavailable.", systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        EyebrowText("Stops")
                        ForEach(tour.stops) { stop in
                            HStack(spacing: 12) {
                                Image(systemName: tour.isCompleted(stop) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(tour.isCompleted(stop) ? AppTheme.visited : .secondary)
                                Text(stop.name).font(.subheadline)
                                Spacer()
                            }
                        }
                    }

                    VStack(spacing: 12) {
                        Button(action: tour.leaveTour) {
                            Text("Done")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.heritageGreen)

                        Button(action: tour.resetTour) {
                            Text("Walk it again")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    private func elapsedDetail(_ figures: TourCompletionFigures) -> String? {
        guard let elapsed = figures.elapsedSeconds, elapsed > figures.walkingSeconds else { return nil }
        return "\(DistanceFormatter.duration(seconds: elapsed)) including time at the stops"
    }

    private func statRow(label: String, value: String, detail: String?, systemImage: String) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(AppTheme.brass)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                EyebrowText(label)
                Text(value)
                    .font(AppTheme.Fonts.metric)
                    .monospacedDigit()
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let deps = AppDependencies.preview()
    return TourCompleteView()
        .environment(deps)
        .environment(deps.tourViewModel)
        .task {
            await deps.tourViewModel.loadStopsIfNeeded()
            deps.tourViewModel.startTour()
            while deps.tourViewModel.phase == .inProgress { deps.tourViewModel.completeCurrentStopAndAdvance() }
        }
}
