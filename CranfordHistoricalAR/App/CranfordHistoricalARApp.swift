import SwiftUI
import TourCore

@main
struct CranfordHistoricalARApp: App {
    @State private var dependencies: AppDependencies

    init() {
        let configuration = AppConfiguration.fromMainBundle()
        _dependencies = State(initialValue: AppDependencies.live(configuration: configuration))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(dependencies)
                .environment(dependencies.tourViewModel)
                .tint(AppTheme.accent)
                .preferredColorScheme(.light)
        }
    }
}

/// Native tabs retain one tour and one audio player across every screen.
struct RootView: View {
    @Environment(TourViewModel.self) private var tour
    @Environment(AppDependencies.self) private var dependencies
    @State private var navigation = AppNavigation()
    @Environment(\.scenePhase) private var scenePhase
    private var isMapActive: Bool { navigation.selectedTab == .map && scenePhase == .active }

    var body: some View {
        AppContentShell {
            TabView(selection: $navigation.selectedTab) {
                HomeView()
                    .tabItem { Label("Home", systemImage: "house") }
                    .tag(AppNavigation.Tab.home)
                    .toolbar(.hidden, for: .tabBar)
                TourView()
                    .tabItem { Label("Map", systemImage: "map") }
                    .tag(AppNavigation.Tab.map)
                    .toolbar(.hidden, for: .tabBar)
                StopsView()
                    .tabItem { Label("Stops", systemImage: "mappin") }
                    .tag(AppNavigation.Tab.stops)
                    .toolbar(.hidden, for: .tabBar)
            }
            .toolbar(.hidden, for: .tabBar)
        } player: { height in
            SharedNarrationBar(availableHeight: height)
        } navigation: {
            BottomNavigationBar(selection: $navigation.selectedTab)
        }
        // Paint the status-bar/notch area without moving content outside its safe area.
        .background(AppTheme.ivory.ignoresSafeArea())
        .environment(navigation)
        .tint(AppTheme.accent)
        .onChange(of: navigation.homeReturnID) { _, _ in tour.pendingSketchStopID = nil }
        .onChange(of: tour.isShowingTour) { _, showing in
            navigation.selectedTab = showing ? .map : .home
        }
        .onChange(of: navigation.selectedTab, initial: true) { _, tab in
            tour.isAutomaticNavigationVisible = tab == .map && scenePhase == .active
        }
        .onChange(of: scenePhase) { _, phase in
            tour.isAutomaticNavigationVisible = navigation.selectedTab == .map && phase == .active
            if phase != .active {
                dependencies.narrationPlayer.checkpointPlayback()
                tour.checkpointWalk()
            }
        }
        .task { await tour.loadStopsIfNeeded() }
        .task(id: isMapActive) {
            guard isMapActive else { return }
            // A paused itinerary still needs live positioning. This never starts the walk.
            tour.startLocationIfPossible()
            while !Task.isCancelled {
                tour.refreshMapLocationIfNeeded()
                do { try await Task.sleep(for: .seconds(5)) }
                catch { return }
            }
        }
    }
}

/// One footer reservation for every tab. Ignoring only the container's lower safe area
/// lets the compact bar sit nearer the edge while keyboard avoidance remains native.
struct AppContentShell<Content: View, Player: View, Navigation: View>: View {
    private let content: Content
    private let player: (CGFloat) -> Player
    private let navigation: Navigation

    init(@ViewBuilder content: () -> Content,
         @ViewBuilder player: @escaping (CGFloat) -> Player,
         @ViewBuilder navigation: () -> Navigation) {
        self.content = content()
        self.player = player
        self.navigation = navigation()
    }

    var body: some View {
        GeometryReader { viewport in
            let bottom = AppFooterSizing.bottomClearance(safeAreaBottom: Double(viewport.safeAreaInsets.bottom))
            let usableHeight = viewport.size.height + viewport.safeAreaInsets.bottom - CGFloat(bottom)
            VStack(spacing: 0) {
                content.frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
                player(usableHeight).fixedSize(horizontal: false, vertical: true)
                navigation.fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, CGFloat(bottom))
            .background(AppTheme.navigationBackground.ignoresSafeArea(edges: .bottom))
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}
