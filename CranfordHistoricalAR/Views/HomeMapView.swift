import SwiftUI
import TourCore

/// Interactive Google map of Cranford for the first screen (spec §23): every stop as a dot,
/// framed to fit, pinch/pan/double-tap enabled. Tapping a dot shows a callout with the stop's
/// name; tapping the map (or the ×) dismisses it. Falls back to the stylized map when the Maps
/// SDK has no key so the screen never goes blank. Selection/camera state lives in `MapViewModel`.
struct HomeMapView: View {
    @Environment(TourViewModel.self) private var tour
    @State private var mapModel = MapViewModel()

    private static let cornerRadius: CGFloat = 28

    var body: some View {
        if GoogleMapsBootstrap.isConfigured {
            liveMap
        } else {
            StylizedCranfordMapView(stops: tour.stops)
        }
    }

    private var liveMap: some View {
        ZStack(alignment: .bottom) {
            GoogleMapView(
                markers: mapModel.markers(for: tour),
                userPuck: nil,
                routeCoordinates: [],
                cameraRequest: mapModel.cameraRequest,
                bottomInset: 0,
                onUserGesture: {},
                onMarkerTap: { mapModel.toggleSelection(stopID: $0) },
                markerStyle: mapModel.overviewMarkerStyle,
                selectedStopID: mapModel.selectedStopID,
                showsCompass: false,
                fitInsets: UIEdgeInsets(top: 28, left: 28, bottom: 28, right: 28),
                onMapTap: { mapModel.select(stopID: nil) },
                onCameraIdle: { mapModel.cameraDidSettle(zoom: $0) }
            )
            .onAppear { mapModel.requestOverview() }
            .onChange(of: tour.stops.count) { _, _ in
                mapModel.select(stopID: nil)
                mapModel.requestOverview()
            }

            if let stop = mapModel.selectedStopID.flatMap(tour.stop(withID:)) {
                HomeStopCallout(stop: stop, isVisited: tour.isCompleted(stop)) {
                    mapModel.select(stopID: nil)
                }
                .padding(12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: mapModel.selectedStopID)
        .clipShape(RoundedRectangle(cornerRadius: HomeMapView.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: HomeMapView.cornerRadius, style: .continuous)
                .strokeBorder(AppTheme.brass.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
    }
}

/// Place-card style callout for the selected stop. Readable at a glance, dismissable, no logic.
struct HomeStopCallout: View {
    let stop: HistoricalStop
    let isVisited: Bool
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(isVisited ? AppTheme.visited : AppTheme.heritageGreen)
                    .frame(width: 30, height: 30)
                if isVisited {
                    Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                } else {
                    Text("\(stop.order)").font(.caption.weight(.bold)).foregroundStyle(.white)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(stop.name)
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if !stop.address.isEmpty {
                    Text(stop.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if stop.isSample {
                    EyebrowText("Sample location", color: AppTheme.warning)
                }
            }
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .frame(width: 28, height: 28)
                    .background(.quaternary, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

#Preview {
    let deps = AppDependencies.preview()
    return HomeMapView()
        .frame(height: 340)
        .padding(24)
        .environment(deps)
        .environment(deps.tourViewModel)
        .task { await deps.tourViewModel.loadStopsIfNeeded() }
}
