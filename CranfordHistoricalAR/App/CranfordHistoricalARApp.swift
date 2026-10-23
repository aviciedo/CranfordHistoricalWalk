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

    var body: some View {
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                SharedNarrationBar()
                BottomNavigationBar(selection: $navigation.selectedTab)
            }
            .background(AppTheme.navigationBackground.ignoresSafeArea(edges: .bottom))
        }
        .environment(navigation)
        .tint(AppTheme.accent)
        .onChange(of: tour.isShowingTour) { _, showing in
            navigation.selectedTab = showing ? .map : .home
        }
        .task { await tour.loadStopsIfNeeded() }
    }
}
