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
    let locationService: any LocationService
    let tourViewModel: TourViewModel

    init(configuration: AppConfiguration, stopService: any HistoricalStopService, locationService: any LocationService, tourViewModel: TourViewModel) {
        self.configuration = configuration
        self.stopService = stopService
        self.locationService = locationService
        self.tourViewModel = tourViewModel
    }

    static func live(configuration: AppConfiguration) -> AppDependencies {
        GoogleMapsBootstrap.configure(with: configuration)
        let stopService = BundledJSONHistoricalStopService()
        let locationService = CoreLocationService()
        let tour = TourViewModel(stopService: stopService, locationService: locationService)
        return AppDependencies(configuration: configuration, stopService: stopService, locationService: locationService, tourViewModel: tour)
    }

    /// Used by SwiftUI previews.
    static func preview() -> AppDependencies {
        let stopService = InMemoryHistoricalStopService(stops: HistoricalStop.previewStops)
        let locationService = CoreLocationService()
        let tour = TourViewModel(stopService: stopService, locationService: locationService)
        return AppDependencies(configuration: .empty, stopService: stopService, locationService: locationService, tourViewModel: tour)
    }
}
