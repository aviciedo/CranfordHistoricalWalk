import CoreLocation
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
    let directionsService: any DirectionsService
    let tourViewModel: TourViewModel

    init(configuration: AppConfiguration, stopService: any HistoricalStopService, locationService: any LocationService, directionsService: any DirectionsService, tourViewModel: TourViewModel) {
        self.configuration = configuration
        self.stopService = stopService
        self.locationService = locationService
        self.directionsService = directionsService
        self.tourViewModel = tourViewModel
    }

    /// One provider per AR session. ARCore is used only when it is actually compiled in.
    func makeGeoSpatialProvider() -> any GeoSpatialProvider {
        #if ARCORE_GEOSPATIAL && canImport(ARCoreGeospatial)
        if configuration.arCoreGeospatialEnabled, configuration.hasRoutesKey {
            return ARCoreGeoSpatialProvider(apiKey: configuration.googleRoutesAPIKey)
        }
        #endif
        return CoreLocationGeoSpatialProvider()
    }

    static func live(configuration: AppConfiguration) -> AppDependencies {
        GoogleMapsBootstrap.configure(with: configuration)
        let stopService = BundledJSONHistoricalStopService()
        let locationService = CoreLocationService()
        let directionsService = DirectionsServiceFactory.make(configuration: configuration)
        let tour = TourViewModel(stopService: stopService, locationService: locationService, directionsService: directionsService)
        return AppDependencies(configuration: configuration, stopService: stopService, locationService: locationService, directionsService: directionsService, tourViewModel: tour)
    }

    /// Used by SwiftUI previews.
    static func preview() -> AppDependencies {
        let stopService = InMemoryHistoricalStopService(stops: HistoricalStop.previewStops)
        let locationService = CoreLocationService()
        let directionsService = PreviewDirectionsService()
        let tour = TourViewModel(stopService: stopService, locationService: locationService, directionsService: directionsService)
        return AppDependencies(configuration: .empty, stopService: stopService, locationService: locationService, directionsService: directionsService, tourViewModel: tour)
    }
}

/// Offline directions for previews/tests: a two-point route at walking pace, labeled as simulated.
struct PreviewDirectionsService: DirectionsService {
    func walkingRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> WalkingRoute {
        var route = WalkingRoute.straightLineEstimate(from: GeoCoordinate(origin), to: GeoCoordinate(destination))
        route.source = .simulated
        return route
    }
}
