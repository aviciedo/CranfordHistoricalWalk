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
            SharedNarrationBar()
                .fixedSize(horizontal: false, vertical: true)
            BottomNavigationBar(selection: $navigation.selectedTab)
                .fixedSize(horizontal: false, vertical: true)
                .background(AppTheme.navigationBackground.ignoresSafeArea(edges: .bottom))
        }
        .environment(navigation)
        .tint(AppTheme.accent)
        .onChange(of: tour.isShowingTour) { _, showing in
            navigation.selectedTab = showing ? .map : .home
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                dependencies.narrationPlayer.checkpointPlayback()
                tour.checkpointWalk()
            }
        }
        .task { await tour.loadStopsIfNeeded() }
    }
}
