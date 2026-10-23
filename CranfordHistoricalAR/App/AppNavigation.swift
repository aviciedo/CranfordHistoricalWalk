import Observation

/// Presentation only. Browsing and changing tabs never change the guided destination.
@MainActor
@Observable
final class AppNavigation {
    enum Tab: Hashable { case home, map, stops }
    struct StopReturn: Equatable {
        let stopID: String
        let tab: Tab
    }
    private var mapOrigin: StopReturn?
    private(set) var pendingStopReturn: StopReturn?
    private var tabHistory: [Tab] = []
    private var isRestoringTab = false
    private(set) var homeReturnID = 0
    var selectedTab: Tab = .home {
        didSet {
            if oldValue != selectedTab && !isRestoringTab {
                tabHistory.append(oldValue)
                // Leaving Map through the tabs ends the direct Show on map return path.
                if oldValue == .map { mapOrigin = nil }
            }
        }
    }
    var focusedStopID: String?
    enum StoryMode: String, CaseIterable { case listen = "Listen", read = "Read" }
    var photoSelections: [String: Int] = [:]

    /// Back at a root tab returns to the previously opened tab, without creating a loop.
    func goBack() {
        pendingStopReturn = nil
        focusedStopID = nil
        isRestoringTab = true
        if selectedTab == .map, let origin = mapOrigin {
            mapOrigin = nil
            if origin.tab != .map, tabHistory.last == origin.tab { _ = tabHistory.popLast() }
            selectedTab = origin.tab
            pendingStopReturn = origin
        } else {
            selectedTab = tabHistory.popLast() ?? .home
        }
        isRestoringTab = false
    }

    /// A new signal is emitted even when a nested presentation was opened from Home.
    func goHome() {
        focusedStopID = nil
        tabHistory.removeAll()
        mapOrigin = nil
        pendingStopReturn = nil
        isRestoringTab = true
        selectedTab = .home
        isRestoringTab = false
        homeReturnID &+= 1
    }

    /// The hosting tab consumes this request once it becomes visible again.
    func takeStopReturn(for tab: Tab) -> String? {
        guard let request = pendingStopReturn, request.tab == tab else { return nil }
        pendingStopReturn = nil
        return request.stopID
    }

    func showOnMap(stopID: String) {
        pendingStopReturn = nil
        mapOrigin = StopReturn(stopID: stopID, tab: selectedTab)
        focusedStopID = stopID
        selectedTab = .map
    }
}
