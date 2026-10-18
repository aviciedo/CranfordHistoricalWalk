import SwiftUI
import TourCore

/// The map portion of the tour screen: Google map, user location, markers, camera controls and
/// the location/permission notices. Keeps no business logic.
struct TourMapView: View {
    @Environment(TourViewModel.self) private var tour
    var mapModel: MapViewModel
    var bottomInset: CGFloat

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if GoogleMapsBootstrap.isConfigured {
                GoogleMapView(
                    markers: mapModel.markers(for: tour),
                    userPuck: mapModel.userPuck(for: tour),
                    routeCoordinates: tour.currentRoute?.clCoordinates ?? [],
                    cameraRequest: mapModel.cameraRequest,
                    bottomInset: bottomInset,
                    onUserGesture: { mapModel.userDidMoveCamera() },
                    onMarkerTap: { mapModel.select(stopID: $0) },
                    markerStyle: .numberedDot,
                    selectedStopID: mapModel.selectedStopID
                )
                .onChange(of: tour.userLocation) { _, _ in
                    mapModel.followIfNeeded(tour: tour)
                }
                .onAppear {
                    if tour.userLocation != nil {
                        mapModel.requestFollow(tour: tour)
                    } else {
                        mapModel.requestOverview()
                    }
                }
                .onChange(of: tour.userLocation == nil) { _, isNil in
                    if !isNil, mapModel.cameraMode == .overview { mapModel.requestFollow(tour: tour) }
                }
            } else {
                MapUnavailableView(stops: tour.stops)
            }

            VStack(alignment: .trailing, spacing: 12) {
                if let issue = tour.locationIssue {
                    LocationIssueBanner(issue: issue)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if GoogleMapsBootstrap.isConfigured {
                    MapControlStack(mapModel: mapModel)
                }
            }
            .padding(.top, 8)
            .padding(.trailing, 12)
            .animation(.easeInOut(duration: 0.25), value: tour.locationIssue)
        }
    }
}

/// Recenter / overview buttons.
struct MapControlStack: View {
    @Environment(TourViewModel.self) private var tour
    var mapModel: MapViewModel

    var body: some View {
        VStack(spacing: 0) {
            Button {
                mapModel.requestFollow(tour: tour)
            } label: {
                Image(systemName: mapModel.cameraMode == .follow ? "location.fill" : "location")
                    .frame(width: 44, height: 44)
            }
            .disabled(tour.userLocation == nil)
            .accessibilityLabel("Center on my location")

            Divider().frame(width: 28)

            Button {
                mapModel.showUserAndDestination(tour: tour)
            } label: {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Show route to next stop")
        }
        .font(.system(size: 17, weight: .medium))
        .foregroundStyle(.primary)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}

struct LocationIssueBanner: View {
    @Environment(TourViewModel.self) private var tour
    let issue: TourViewModel.LocationIssue

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(issue.isBlocking ? AppTheme.warning : AppTheme.brass)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(issue.title).font(.subheadline.weight(.semibold))
                Text(issue.message).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                actions
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(.leading, 12)
    }

    private var icon: String {
        switch issue {
        case .permissionNotDetermined: return "location"
        case .permissionDenied, .permissionRestricted: return "location.slash"
        case .reducedAccuracy: return "scope"
        case .waitingForSignal: return "antenna.radiowaves.left.and.right"
        case .poorAccuracy: return "wifi.exclamationmark"
        case .failure: return "exclamationmark.triangle"
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch issue {
        case .permissionNotDetermined:
            Button("Allow location") { tour.startLocationIfPossible() }
                .font(.footnote.weight(.semibold))
                .padding(.top, 2)
        case .permissionDenied, .reducedAccuracy:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: url)
                    .font(.footnote.weight(.semibold))
                    .padding(.top, 2)
            }
        default:
            EmptyView()
        }
    }
}

/// Shown when no Maps SDK key is configured (spec §21: "Google Maps unavailable").
/// The tour remains usable: the stylized map and the list still work.
struct MapUnavailableView: View {
    let stops: [HistoricalStop]

    var body: some View {
        StylizedCranfordMapView(stops: stops)
            .overlay(alignment: .topLeading) {
                Label("Live map unavailable", systemImage: "wifi.exclamationmark")
                    .font(.footnote.weight(.medium))
                    .padding(10).background(AppTheme.parchment, in: Capsule())
                    .padding(12).allowsHitTesting(false)
            }
    }
}
