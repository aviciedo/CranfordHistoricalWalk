import SwiftUI
import TourCore

/// Main tour screen (spec §4): full-bleed map, tour summary at the top, persistent navigation
/// panel at the bottom.
struct TourView: View {
    @Environment(TourViewModel.self) private var tour
    @State private var mapModel = MapViewModel()
    @State private var isShowingStopList = false
    @State private var panelHeight: CGFloat = 170

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                TourMapView(mapModel: mapModel, bottomInset: panelHeight)

                VStack {
                    TourHeaderView()
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    Spacer()
                }

                NextStopCard()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(key: PanelHeightKey.self, value: proxy.size.height + 10)
                        }
                    )
            }
            .onPreferenceChange(PanelHeightKey.self) { panelHeight = $0 }
            .navigationTitle(tour.tourName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.regularMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Home", systemImage: "chevron.left", action: tour.leaveTour)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Stops", systemImage: "list.bullet") { isShowingStopList = true }
                }
            }
            .sheet(isPresented: $isShowingStopList) {
                StopListSheet()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .onChange(of: mapModel.selectedStopID) { _, id in
                guard id != nil else { return }
                mapModel.select(stopID: nil)
            }
            .onChange(of: tour.currentStop?.id) { _, _ in
                mapModel.showUserAndDestination(tour: tour)
            }
            .task { tour.startLocationIfPossible() }
        }
    }
}

private struct PanelHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 170
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct StopListSheet: View {
    @Environment(TourViewModel.self) private var tour
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(tour.stops) { stop in
                        StopRow(stop: stop, isCurrent: stop.id == tour.currentStop?.id, isCompleted: tour.isCompleted(stop))
                    }
                } footer: {
                    if let status = tour.dataStatus {
                        Text(status).font(.caption2)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Stops")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
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

#Preview {
    let deps = AppDependencies.preview()
    return TourView()
        .environment(deps)
        .environment(deps.tourViewModel)
        .task { await deps.tourViewModel.loadStopsIfNeeded(); deps.tourViewModel.startTour() }
}
