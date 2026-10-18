import SwiftUI
import TourCore

/// Main tour screen (spec §4): full-bleed map, tour summary at the top, persistent navigation
/// panel at the bottom.
struct TourView: View {
    @Environment(TourViewModel.self) private var tour
    @Environment(AppDependencies.self) private var dependencies
    @State private var mapModel = MapViewModel()
    @State private var isShowingStopList = false
    @State private var isShowingAR = false
    @State private var isShowingSignDetails = false
    @State private var isShowingDeveloperControls = false
    @State private var listenStop: HistoricalStop?
    @State private var panelHeight: CGFloat = 170

    var body: some View {
        ZStack {
            if tour.phase == .complete {
                TourCompleteView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                tourContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: tour.phase)
    }

    private var tourContent: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                TourMapView(mapModel: mapModel, bottomInset: panelHeight)

                VStack {
                    TourHeaderView()
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    Spacer()
                }

                VStack(spacing: 10) {
                    if let arrived = tour.presentedSignStop {
                        ArrivalCard(stop: arrived, onEnterAR: { isShowingAR = true }, onRead: { isShowingSignDetails = true })
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    NextStopCard(onEnterAR: tour.currentStop == nil ? nil : { isShowingAR = true })
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: PanelHeightKey.self, value: proxy.size.height + 10)
                    }
                )
                .animation(.spring(duration: 0.4), value: tour.presentedSignStop?.id)
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
                    Menu {
                        Button("Stops", systemImage: "list.bullet") { isShowingStopList = true }
                        Button("Fit whole tour", systemImage: "map") { mapModel.requestOverview() }
                        #if DEVELOPER_MENU
                        Divider()
                        Button("Developer Controls", systemImage: "hammer") { isShowingDeveloperControls = true }
                        #endif
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More")
                }
            }
            #if DEVELOPER_MENU
            .sheet(isPresented: $isShowingDeveloperControls) {
                DeveloperControlsView()
                    .presentationDetents([.large])
            }
            #endif
            .sheet(isPresented: $isShowingStopList) {
                StopListSheet()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $isShowingAR) {
                ARTourView()
            }
            .sheet(isPresented: $isShowingSignDetails) {
                if let stop = tour.presentedSignStop ?? tour.currentStop {
                    HistoricalSignSheet(stop: stop)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(item: $listenStop) { stop in
                HistoricalSignSheet(stop: stop)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .onChange(of: mapModel.selectedStopID) { _, id in
                if let id, let stop = tour.stop(withID: id) {
                    listenStop = stop
                }
                mapModel.select(stopID: nil)
            }
            .onChange(of: tour.currentStop?.id) { _, _ in
                mapModel.showUserAndDestination(tour: tour)
                dependencies.imageLoader.prefetch([tour.currentStop, tour.nextStop].compactMap { $0 })
            }
            .task {
                tour.startLocationIfPossible()
                dependencies.imageLoader.prefetch([tour.currentStop, tour.nextStop].compactMap { $0 })
            }
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
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(tour.stops) { stop in
                        VStack(alignment: .leading, spacing: 12) {
                            StopRow(stop: stop, isCurrent: stop.id == tour.currentStop?.id, isCompleted: tour.isCompleted(stop))
                            StopPhoto(stop: stop, height: 160)
                            NarrationControls(stop: stop)
                        }
                        .padding(14)
                        .background(AppTheme.parchment, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(AppTheme.brass.opacity(0.2), lineWidth: 1)
                        )
                    }

                    if let status = tour.dataStatus {
                        Text(status)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 4)
                    }
                }
                .padding(16)
            }
            .background(AppTheme.parchment)
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
