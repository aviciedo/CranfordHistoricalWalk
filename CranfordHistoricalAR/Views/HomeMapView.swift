import SwiftUI
import TourCore

/// A live overview when configured; the offline illustration remains clearly labeled.
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
                    fitInsets: UIEdgeInsets(top: 28, left: 28, bottom: 28, right: 28)
                )
                .onAppear { mapModel.requestOverview() }
                .onChange(of: tour.stops.count) { _, _ in mapModel.requestOverview() }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                StylizedCranfordMapView(stops: tour.stops)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Illustrated map of the historical stops")
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
