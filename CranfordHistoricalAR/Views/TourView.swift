import SwiftUI
import TourCore

/// Selected map-first design. The map and the destination panel occupy separate areas,
/// leaving the map provider's attribution and gestures clear of the player and controls.
struct TourView: View {
    @Environment(TourViewModel.self) private var tour
    @Environment(AppDependencies.self) private var dependencies
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var mapModel = MapViewModel()
    @State private var isShowingAR = false
    @State private var isShowingSummary = false
    @State private var isShowingDeveloperControls = false
    @State private var detailStop: HistoricalStop?

    var body: some View {
        Group {
            if tour.phase == .complete {
                TourCompleteView()
            } else {
                VStack(spacing: 0) {
                    header
                    if typeSize.isAccessibilitySize {
                        ScrollView {
                            map.frame(height: 220)
                            destination
                        }
                    } else {
                        map.frame(maxHeight: .infinity)
                        destination.fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .background(AppTheme.parchment).foregroundStyle(AppTheme.ink)
        .sheet(item: $detailStop) { HistoricalSignSheet(stop: $0) }
        .sheet(isPresented: $isShowingSummary) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 24) {
                    if tour.phase == .inProgress {
                        TourHeaderView()
                    } else {
                        Text("\(tour.stops.count) historical stops")
                            .font(.system(.title2, design: .serif))
                    }
                    Button("Show the whole route") { mapModel.requestOverview(); isShowingSummary = false }
                        .frame(minHeight: 44)
                    Spacer()
                }
                .padding(24).background(AppTheme.parchment)
                .navigationTitle("Your walk").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { isShowingSummary = false }
                    }
                }
            }
        }
        #if DEVELOPER_MENU
        .sheet(isPresented: $isShowingDeveloperControls) { DeveloperControlsView() }
        #endif
        .fullScreenCover(isPresented: $isShowingAR) { ARTourView() }
        .onChange(of: mapModel.selectedStopID) { _, id in
            if let id { detailStop = tour.stop(withID: id) }
            mapModel.select(stopID: nil)
        }
        .onChange(of: navigation.focusedStopID) { _, _ in focusRequestedStop() }
        .onChange(of: tour.arrivalStoryStopID) { _, id in
            if let id, !isShowingAR, navigation.selectedTab == .map {
                detailStop = tour.stop(withID: id)
            }
        }
        .onChange(of: tour.currentStop?.id) { _, _ in
            mapModel.showUserAndDestination(tour: tour)
            dependencies.imageLoader.prefetch([tour.currentStop, tour.nextStop].compactMap { $0 })
        }
        .task {
            if tour.phase == .inProgress { tour.startLocationIfPossible() }
            focusRequestedStop()
            if let id = tour.arrivalStoryStopID, !isShowingAR { detailStop = tour.stop(withID: id) }
            dependencies.imageLoader.prefetch([tour.currentStop, tour.nextStop].compactMap { $0 })
        }
    }

    private var header: some View {
        HStack {
            Text("Your walk").font(.system(.largeTitle, design: .serif).weight(.semibold))
                .modifier(WalkDebugGesture(isPresented: $isShowingDeveloperControls))
            Spacer()
            Button { isShowingSummary = true } label: {
                Text(tour.currentStop.map { "\($0.order) of \(tour.stops.count)" } ?? "\(tour.stops.count) stops")
                    .font(.subheadline.weight(.medium)).frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain).foregroundStyle(AppTheme.secondaryInk)
            .accessibilityLabel("Tour summary")
        }
        .padding(.horizontal, 22).padding(.vertical, 12)
    }

    private var map: some View {
        TourMapView(mapModel: mapModel, bottomInset: 0, onEnterAR: enterWalkingAR)
            .clipped()
    }

    @ViewBuilder
    private var destination: some View {
        if tour.phase == .inProgress {
            NextStopCard(onEnterAR: { isShowingAR = true }, onDetails: { detailStop = tour.currentStop })
        } else {
            Button {
                tour.startTour()
                navigation.selectedTab = .map
            } label: {
                Label("Start walking tour", systemImage: "figure.walk")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(.plain).foregroundStyle(AppTheme.ivory)
            .background(AppTheme.forest, in: RoundedRectangle(cornerRadius: 14))
            .disabled(tour.loadState != .loaded)
            .padding(20)
        }
    }

    private func enterWalkingAR() {
        // Start/resume the shared destination; opening the camera never skips a stop or story.
        guard tour.prepareForARFromDetails() else { return }
        isShowingAR = true
    }

    private func focusRequestedStop() {
        guard let id = navigation.focusedStopID, let stop = tour.stop(withID: id) else { return }
        mapModel.show(stop: stop)
        navigation.focusedStopID = nil
    }
}

private struct WalkDebugGesture: ViewModifier {
    @Binding var isPresented: Bool
    func body(content: Content) -> some View {
        #if DEVELOPER_MENU
        content.onLongPressGesture { isPresented = true }
        #else
        content
        #endif
    }
}

#Preview {
    let deps = AppDependencies.preview()
    return TourView()
        .environment(deps).environment(deps.tourViewModel).environment(AppNavigation())
        .task { await deps.tourViewModel.loadStopsIfNeeded(); deps.tourViewModel.startTour() }
}
