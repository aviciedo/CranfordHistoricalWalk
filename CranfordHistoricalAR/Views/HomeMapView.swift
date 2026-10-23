import SwiftUI
import TourCore

/// A geographic overview using Google when configured, otherwise Apple; no GPS permission is requested.
struct HomeMapView: View {
    @Environment(TourViewModel.self) private var tour
    @State private var mapModel = MapViewModel()
    @State private var detailStop: HistoricalStop?

    var body: some View {
        Group {
            if GoogleMapsBootstrap.isConfigured {
                GoogleMapView(
                    markers: mapModel.markers(for: tour),
                    userPuck: mapModel.userPuck(for: tour),
                    routeCoordinates: [],
                    cameraRequest: mapModel.cameraRequest,
                    bottomInset: 0,
                    onUserGesture: {},
                    onMarkerTap: { id in
                        mapModel.select(stopID: id)
                        detailStop = tour.stop(withID: id)
                    },
                    markerStyle: .numberedDot,
                    selectedStopID: mapModel.selectedStopID,
                    showsCompass: false,
                    overviewIncludesUserLocation: false,
                    fitInsets: UIEdgeInsets(top: 56, left: 40, bottom: 40, right: 40)
                )
                .onAppear { mapModel.requestOverview(animated: false) }
                .onChange(of: tour.stops.count) { _, _ in mapModel.requestOverview(animated: false) }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                AppleTourMapView(markers: mapModel.markers(for: tour), userPuck: nil,
                    routeCoordinates: [], cameraRequest: mapModel.cameraRequest,
                    onUserGesture: { mapModel.userDidMoveCamera() },
                    onMarkerTap: { detailStop = tour.stop(withID: $0) })
                    .onAppear { mapModel.requestOverview(animated: false) }
                    .onChange(of: tour.stops.count) { _, _ in mapModel.requestOverview(animated: false) }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .sheet(item: $detailStop, onDismiss: { mapModel.select(stopID: nil) }) {
            HistoricalSignSheet(stop: $0)
        }
    }
}

#Preview {
    let deps = AppDependencies.preview()
    return HomeMapView().frame(height: 300).padding(24)
        .environment(deps).environment(deps.tourViewModel).environment(AppNavigation())
        .task { await deps.tourViewModel.loadStopsIfNeeded() }
}
