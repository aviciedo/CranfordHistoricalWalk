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
    @State private var destinationHeight: CGFloat = 200

    var body: some View {
        VStack(spacing: 0) {
            ScreenReturnBar(onBack: { navigation.goBack() })
                .padding(.horizontal, 22).padding(.top, 8)
            header
            if tour.phase == .complete {
                Button { isShowingSummary = true } label: {
                    HStack {
                        Label("Walk complete", systemImage: "checkmark.circle")
                        Spacer()
                        Text("View summary")
                        Image(systemName: "chevron.right").font(.caption)
                    }
                    .font(.subheadline).frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).padding(.horizontal, 22)
            }
            GeometryReader { viewport in
                ScrollView {
                    VStack(spacing: 0) {
                        map.frame(height: typeSize.isAccessibilitySize ? 260 : max(260, viewport.size.height - destinationHeight - 24))
                        VStack(spacing: 0) { destination }
                            .fixedSize(horizontal: false, vertical: true)
                            .background {
                                GeometryReader { panel in
                                    Color.clear.preference(key: MapDestinationHeight.self, value: panel.size.height)
                                }
                            }
                    }
                    // Keep the last line/actions clear of the persistent player and tabs.
                    .padding(.bottom, 24)
                }
                .onPreferenceChange(MapDestinationHeight.self) { destinationHeight = $0 }
                .accessibilityIdentifier("map.scrollContent")
            }
        }
        .background(AppTheme.ivory.ignoresSafeArea(edges: .top)).foregroundStyle(AppTheme.ink)
        .sheet(item: $detailStop) { HistoricalSignSheet(stop: $0) }
        .sheet(isPresented: $isShowingSummary) {
            NavigationStack {
                Group {
                    if tour.phase == .complete {
                        TourCompleteView()
                    } else {
                        VStack(alignment: .leading, spacing: 24) {
                            if tour.phase == .inProgress { TourHeaderView() }
                            else {
                                Text("\(tour.stops.count) historical stops")
                                    .font(.system(.title2, design: .serif))
                            }
                            Button("Show the whole route") {
                                mapModel.requestOverview()
                                isShowingSummary = false
                            }
                            .frame(minHeight: 44)
                            Spacer()
                        }
                        .padding(24).background(AppTheme.parchment)
                    }
                }
                .navigationTitle(tour.phase == .complete ? "Walk summary" : "Your walk")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        ScreenBackButton { isShowingSummary = false }
                    }
                    ToolbarItem(placement: .confirmationAction) { ScreenHomeButton() }
                }
            }
            .dismissOnReturnHome()
        }

        #if DEVELOPER_MENU
        .sheet(isPresented: $isShowingDeveloperControls) { DeveloperControlsView() }
        #endif
        .fullScreenCover(isPresented: $isShowingAR) { ARTourView() }
        .onChange(of: navigation.pendingStopReturn) { _, _ in restoreStopReturn() }
        .onAppear { restoreStopReturn() }
        .onChange(of: navigation.homeReturnID) { _, _ in
            detailStop = nil
            isShowingSummary = false
            isShowingDeveloperControls = false
            isShowingAR = false
        }
        .onChange(of: mapModel.selectedStopID) { _, id in
            if let id { detailStop = tour.stop(withID: id) }
            mapModel.select(stopID: nil)
        }
        .onChange(of: navigation.focusedStopID) { _, _ in focusRequestedStop() }
        .onChange(of: tour.currentStop?.id) { _, _ in
            mapModel.showUserAndDestination(tour: tour)
            dependencies.imageLoader.prefetch([tour.currentStop, tour.nextStop].compactMap { $0 })
        }
        .task {
            if tour.isWalkingActive { tour.startLocationIfPossible() }
            focusRequestedStop()
            dependencies.imageLoader.prefetch([tour.currentStop, tour.nextStop].compactMap { $0 })
        }
    }

    private var header: some View {
        HStack {
            Text("Map").font(.system(.largeTitle, design: .serif).weight(.semibold))
                .modifier(WalkDebugGesture(isPresented: $isShowingDeveloperControls))
            Spacer()
        }
        .padding(.horizontal, 22).padding(.vertical, 12)
    }

    private var map: some View {
        TourMapView(mapModel: mapModel, bottomInset: 0, onEnterAR: enterWalkingAR)
            .clipped()
    }

    @ViewBuilder
    private var destination: some View {
        if let viewed = mapModel.viewedStopID.flatMap(tour.stop(withID:)) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Viewing").font(.caption).foregroundStyle(AppTheme.secondaryInk)
                    Text(viewed.name).font(.system(.headline, design: .serif))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button("View stop") { detailStop = viewed }.frame(minHeight: 44)
                Button { mapModel.clearViewedStop() } label: {
                    Image(systemName: "xmark").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Clear viewed place")
            }
            .buttonStyle(.plain).padding(.horizontal, 22).padding(.vertical, 8)
            if tour.phase == .inProgress { Divider() }
        }
        if tour.phase == .inProgress {
            NextStopCard(onDetails: { detailStop = tour.currentStop })
        } else if tour.phase == .notStarted && mapModel.viewedStopID == nil {
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

    private func restoreStopReturn() {
        if let id = navigation.takeStopReturn(for: .map) { detailStop = tour.stop(withID: id) }
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

private struct MapDestinationHeight: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
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
