import Observation

/// Presentation only. Browsing and changing tabs never change the guided destination.
@MainActor
@Observable
final class AppNavigation {
    enum Tab: Hashable { case home, map, stops }
    var selectedTab: Tab = .home
    var focusedStopID: String?
    var isNarrationMinimized = false

    func showOnMap(stopID: String) {
        focusedStopID = stopID
        selectedTab = .map
    }
}
