import SwiftUI

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

    var body: some View {
        GeometryReader { viewport in
            VStack(spacing: 0) {
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                // Real layout siblings: screens receive only the height above the footer.
                // This avoids relying on inset propagation through the native TabView.
                SharedNarrationBar(availableHeight: viewport.size.height)
                    .fixedSize(horizontal: false, vertical: true)
                BottomNavigationBar(selection: $navigation.selectedTab)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(AppTheme.navigationBackground.ignoresSafeArea(edges: .bottom))
            }
        }
        // Paint the status-bar/notch area without moving content outside its safe area.
        .background(AppTheme.ivory.ignoresSafeArea())
        .environment(navigation)
        .tint(AppTheme.accent)
        .onChange(of: navigation.homeReturnID) { _, _ in tour.cancelPendingPassportPresentation() }
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
    }
}
