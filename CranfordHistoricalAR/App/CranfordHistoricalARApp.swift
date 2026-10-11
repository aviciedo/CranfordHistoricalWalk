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

/// Switches between the first screen and the tour once the user taps "Start Walking Tour".
struct RootView: View {
    @Environment(TourViewModel.self) private var tour

    var body: some View {
        ZStack {
            if tour.isShowingTour {
                TourView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                HomeView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: tour.isShowingTour)
        .task { await tour.loadStopsIfNeeded() }
    }
}
