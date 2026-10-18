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
        }
    }
}

/// Native tabs retain one tour and one audio player across every screen.
struct RootView: View {
    @Environment(TourViewModel.self) private var tour
    @State private var navigation = AppNavigation()

    var body: some View {
        TabView(selection: $navigation.selectedTab) {
            HomeView()
                .safeAreaInset(edge: .bottom, spacing: 0) { SharedNarrationBar() }
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppNavigation.Tab.home)
            TourView()
                .safeAreaInset(edge: .bottom, spacing: 0) { SharedNarrationBar() }
                .tabItem { Label("Map", systemImage: "map") }
                .tag(AppNavigation.Tab.map)
            StopsView()
                .safeAreaInset(edge: .bottom, spacing: 0) { SharedNarrationBar() }
                .tabItem { Label("Stops", systemImage: "mappin.and.ellipse") }
                .tag(AppNavigation.Tab.stops)
        }
        .environment(navigation)
        .tint(AppTheme.accent)
        .toolbarBackground(AppTheme.parchment, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onChange(of: tour.isShowingTour) { _, showing in
            navigation.selectedTab = showing ? .map : .home
        }
        .task { await tour.loadStopsIfNeeded() }
    }
}
