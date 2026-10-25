import SwiftUI
import TourCore

/// A geographic overview using Google when configured, otherwise Apple; no GPS permission is requested.
struct HomeMapView: View {
    @Environment(AppNavigation.self) private var navigation
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
                    onUserGesture: { mapModel.userDidMoveCamera() },
                    onMarkerTap: { mapModel.select(stopID: $0) },
                    markerStyle: .numberedDot,
                    selectedStopID: mapModel.selectedStopID,
                    showsStopPopup: false,
                    reservesZoomControls: true,
                    showsCompass: false,
                    overviewIncludesUserLocation: false,
                    fitInsets: UIEdgeInsets(top: 56, left: 40, bottom: 40, right: 40),
                    onMapTap: dismissPopup,
                    onCameraIdle: { mapModel.cameraDidSettle(zoom: $0) }
                )
                .onAppear { mapModel.requestOverview(animated: false) }
                .onChange(of: tour.stops.count) { _, _ in mapModel.requestOverview(animated: false) }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                AppleTourMapView(markers: mapModel.markers(for: tour), userPuck: nil,
                    routeCoordinates: [], cameraRequest: mapModel.cameraRequest,
                    onUserGesture: { mapModel.userDidMoveCamera() },
                    onMarkerTap: { mapModel.select(stopID: $0) },
                    reservesZoomControls: true,
                    onCameraIdle: { mapModel.cameraDidSettle(zoom: $0) })
                    .onAppear { mapModel.requestOverview(animated: false) }
                    .onChange(of: tour.stops.count) { _, _ in mapModel.requestOverview(animated: false) }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .overlay(alignment: .topLeading) {
            if let stop = mapModel.selectedStopID.flatMap(tour.stop(withID:)) {
                GeometryReader { viewport in
                    // Short maps put the card left of the zoom controls. Taller maps leave
                    // room below it. The title, X and View stop action remain outside body scroll.
                    let compact = viewport.size.height < 360
                    HomeStopPopup(stop: stop, onClose: dismissPopup) {
                        dismissPopup()
                        detailStop = stop
                    }
                    .frame(width: max(140, min(300, viewport.size.width - (compact ? 96 : 24))))
                    .frame(maxHeight: max(160, viewport.size.height - (compact ? 24 : 152)), alignment: .top)
                    .padding(12)
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            VStack(spacing: 10) {
                zoomButton("plus", label: "Zoom in", enabled: mapModel.canZoomIn, step: 1)
                zoomButton("minus", label: "Zoom out", enabled: mapModel.canZoomOut, step: -1)
            }
            .padding(.trailing, 12).padding(.bottom, 24)
        }
        .onChange(of: navigation.pendingStopReturn) { _, _ in restoreStopReturn() }
        .onAppear { restoreStopReturn() }
        .onChange(of: navigation.homeReturnID) { _, _ in detailStop = nil; dismissPopup() }
        .sheet(item: $detailStop, onDismiss: dismissPopup) {
            HistoricalSignSheet(stop: $0)
        }
    }

    private func dismissPopup() {
        mapModel.select(stopID: nil)
        mapModel.clearViewedStop()
    }

    private func zoomButton(_ symbol: String, label: String, enabled: Bool, step: Float) -> some View {
        Button { mapModel.requestZoom(by: step) } label: {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(AppTheme.forest)
                .frame(width: 48, height: 48)
                .background(.white, in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(!enabled).opacity(enabled ? 1 : 0.45)
        .accessibilityLabel(label)
        .accessibilityIdentifier(step > 0 ? "home.map.zoomIn" : "home.map.zoomOut")
    }

    private func restoreStopReturn() {
        if let id = navigation.takeStopReturn(for: .home) { detailStop = tour.stop(withID: id) }
    }
}

/// One presentation on both map providers. A marker tap previews a place; only the
/// explicit action opens its story. None of these actions starts or retargets a walk.
private struct HomeStopPopup: View {
    let stop: HistoricalStop
    let onClose: () -> Void
    let onOpen: () -> Void

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }.scrollBounceBehavior(.basedOnSize)
        }
        .padding(12)
        .foregroundStyle(AppTheme.forest)
        .background(AppTheme.ivory.opacity(0.98), in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.16), radius: 6, y: 3)
        .accessibilityIdentifier("home.map.popup")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Text(stop.name).font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 17, weight: .medium))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss stop popup")
                .accessibilityHint("Closes only this popup")
                .accessibilityIdentifier("home.map.popup.close")
            }
            ViewThatFits(in: .vertical) {
                information.fixedSize(horizontal: false, vertical: true)
                ScrollView { information }.scrollBounceBehavior(.basedOnSize)
            }
            Button(action: onOpen) {
                HStack {
                    Text("View stop")
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(AppTheme.ivory)
                .background(AppTheme.forest, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View \(stop.name) stop page")
            .accessibilityHint("Opens photographs and the story without changing your walk")
            .accessibilityIdentifier("home.map.popup.openStop")
        }
    }

    private var information: some View {
        Text(stop.markerInformation).font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    let deps = AppDependencies.preview()
    return HomeMapView().frame(height: 300).padding(24)
        .environment(deps).environment(deps.tourViewModel).environment(AppNavigation())
        .task { await deps.tourViewModel.loadStopsIfNeeded() }
}
