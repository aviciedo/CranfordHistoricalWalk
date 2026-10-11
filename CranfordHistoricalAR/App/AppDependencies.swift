import Foundation
import SwiftUI
import TourCore

/// Composition root. Everything with side effects is created here once and injected
/// through the SwiftUI environment, so views and view models never reach for singletons.
@MainActor
@Observable
final class AppDependencies {
    let configuration: AppConfiguration
    let stopService: any HistoricalStopService
    let tourViewModel: TourViewModel

    init(configuration: AppConfiguration, stopService: any HistoricalStopService, tourViewModel: TourViewModel) {
        self.configuration = configuration
        self.stopService = stopService
        self.tourViewModel = tourViewModel
    }

    static func live(configuration: AppConfiguration) -> AppDependencies {
        let stopService = BundledJSONHistoricalStopService()
        let tour = TourViewModel(stopService: stopService)
        return AppDependencies(configuration: configuration, stopService: stopService, tourViewModel: tour)
    }

    /// Used by SwiftUI previews.
    static func preview() -> AppDependencies {
        let stopService = InMemoryHistoricalStopService(stops: HistoricalStop.previewStops)
        let tour = TourViewModel(stopService: stopService)
        return AppDependencies(configuration: .empty, stopService: stopService, tourViewModel: tour)
    }
}
