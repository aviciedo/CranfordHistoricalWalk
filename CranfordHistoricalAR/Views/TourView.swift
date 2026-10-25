import SwiftUI
import TourCore

/// Selected map-first design. The map and the destination panel occupy separate areas,
/// leaving the map provider's attribution and gestures clear of the player and controls.
struct TourView: View {
    @Environment(TourViewModel.self) private var tour
    @Environment(AppDependencies.self) private var dependencies
    @Environment(AppNavigation.self) private var navigation
    @State private var mapModel = MapViewModel()
    @State private var isShowingAR = false
    @State private var isShowingSummary = false
    @State private var isShowingDeveloperControls = false
    @State private var detailStop: HistoricalStop?

    var body: some View {
        VStack(spacing: 0) {
            ScreenPageHeader(onBack: { navigation.goBack() }) {
                Text("Map")
                    .modifier(WalkDebugGesture(isPresented: $isShowingDeveloperControls))
            }
            if tour.phase == .complete {
                Button { isShowingSummary = true } label: {
                    HStack {
                        Label("Walk finished", systemImage: "checkmark.circle")
                        Spacer()
                        Text("View summary")
                        Image(systemName: "chevron.right").font(.caption)
                    }
                    .font(.subheadline).frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).padding(.horizontal, 24)
            }
            GeometryReader { viewport in
                ScrollView {
                    DestinationFirstMapLayout(availableSize: viewport.size) {
                        map.padding(.horizontal, 24)
                        VStack(spacing: 0) { destination }
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
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
            .holdsWalkingContext()
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
        .onChange(of: tour.walkSessionID) { _, _ in mapModel.showUserAndDestination(tour: tour) }
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

    private var map: some View {
        TourMapView(mapModel: mapModel, bottomInset: 0, onEnterAR: enterWalkingAR)
            .clipShape(RoundedRectangle(cornerRadius: 16))
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
            .buttonStyle(.plain).padding(.horizontal, 24).padding(.vertical, 8)
            if tour.phase == .inProgress { Divider() }
        }
        if tour.phase == .complete, let fromID = tour.automaticTransitionFromStopID {
            VStack(alignment: .leading, spacing: 4) {
                Text(tour.currentStop.map { "Now guiding you to \($0.name)" } ?? "Walk finished")
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Button("Undo · Stay at \(tour.stop(withID: fromID)?.name ?? "previous stop")") {
                    tour.undoAutomaticTransition()
                }
                .buttonStyle(.plain).font(.subheadline).frame(minHeight: 44)
            }
            .padding(.horizontal, 24).padding(.vertical, 8)
            .accessibilityIdentifier("map.automaticTransition")
        }
        if tour.phase == .inProgress {
            NextStopCard(onDetails: { detailStop = tour.currentStop })
        } else if tour.phase == .notStarted && mapModel.viewedStopID == nil {
            Button {
                tour.startTour()
                navigation.selectedTab = .map
            } label: {
                Label(tour.startWalkTitle, systemImage: "figure.walk")
                    .fixedSize(horizontal: false, vertical: true)
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(.plain).foregroundStyle(AppTheme.ivory)
            .background(AppTheme.forest, in: RoundedRectangle(cornerRadius: 14))
            .disabled(tour.loadState != .loaded)
            .padding(.horizontal, 24).padding(.vertical, 12)
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

/// Measure the destination directly in the same layout pass, rather than feeding a
/// PreferenceKey back into a ScrollView's map height. The footer is never compressed.
struct DestinationFirstMapLayout: Layout {
    let availableSize: CGSize

    private func metrics(for subviews: Subviews) -> MapScreenSizing.Metrics {
        guard availableSize.width > 0, availableSize.height > 0 else {
            return MapScreenSizing.metrics(availableHeight: 0, destinationHeight: 0)
        }
        let proposal = ProposedViewSize(width: availableSize.width, height: nil)
        let footerHeight = subviews[1].sizeThatFits(proposal).height
        return MapScreenSizing.metrics(availableHeight: Double(availableSize.height),
                                       destinationHeight: Double(footerHeight))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let sizes = metrics(for: subviews)
        return CGSize(width: availableSize.width, height: CGFloat(sizes.contentHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let sizes = metrics(for: subviews)
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.minY), anchor: .topLeading,
            proposal: ProposedViewSize(width: availableSize.width, height: CGFloat(sizes.mapHeight)))
        subviews[1].place(at: CGPoint(x: bounds.minX, y: bounds.minY + CGFloat(sizes.mapHeight + sizes.gap)),
            anchor: .topLeading, proposal: ProposedViewSize(width: availableSize.width,
                                                          height: CGFloat(sizes.destinationHeight)))
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
