import SwiftUI
import TourCore

/// Main tour screen (spec §4). Stage 1: navigation shell with a stop list; the Google map,
/// live navigation panel and AR entry are added in later stages.
struct TourView: View {
    @Environment(TourViewModel.self) private var tour

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                stopList
                NextStopCard()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
            .navigationTitle(tour.tourName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Home", systemImage: "chevron.left", action: tour.leaveTour)
                }
            }
        }
    }

    private var stopList: some View {
        List {
            Section {
                ForEach(tour.stops) { stop in
                    StopRow(stop: stop, isCurrent: stop.id == tour.currentStop?.id, isCompleted: tour.isCompleted(stop))
                }
            } header: {
                Text("Stops")
            } footer: {
                if let status = tour.dataStatus {
                    Text(status).font(.caption2)
                }
            }
            Color.clear.frame(height: 140).listRowBackground(Color.clear)
        }
        .listStyle(.insetGrouped)
    }
}

struct StopRow: View {
    let stop: HistoricalStop
    let isCurrent: Bool
    let isCompleted: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(isCompleted ? AppTheme.visited : (isCurrent ? AppTheme.heritageGreen : Color.secondary.opacity(0.25)))
                    .frame(width: 30, height: 30)
                if isCompleted {
                    Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                } else {
                    Text("\(stop.order)").font(.caption.weight(.bold)).foregroundStyle(isCurrent ? .white : .primary)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(stop.name).font(.headline)
                Text(stop.shortDescription).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                if stop.isSample {
                    EyebrowText("Sample location", color: AppTheme.warning)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Persistent bottom panel (spec §4). Stage 1 shows the stop name; distance/time arrive in Stage 3.
struct NextStopCard: View {
    @Environment(TourViewModel.self) private var tour

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                if let current = tour.currentStop {
                    EyebrowText("Next stop")
                    Text(current.name)
                        .font(AppTheme.Fonts.title)
                        .lineLimit(2)
                    HStack(spacing: 18) {
                        Label("—", systemImage: "figure.walk")
                        Label("—", systemImage: "clock")
                    }
                    .font(AppTheme.Fonts.metric)
                    .foregroundStyle(.secondary)
                } else if tour.phase == .complete {
                    EyebrowText("Tour complete")
                    Text("You visited every stop.").font(AppTheme.Fonts.title)
                } else {
                    EyebrowText("Walking tour")
                    Text("Loading stops…").font(AppTheme.Fonts.title)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    let deps = AppDependencies.preview()
    return TourView()
        .environment(deps.tourViewModel)
        .task { await deps.tourViewModel.loadStopsIfNeeded(); deps.tourViewModel.startTour() }
}
