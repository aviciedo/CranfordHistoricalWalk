import SwiftUI
import TourCore

/// The map portion of the tour screen: Google map, user location, markers, camera controls and
/// the location/permission notices. Keeps no business logic.
struct TourMapView: View {
    @Environment(TourViewModel.self) private var tour
    var mapModel: MapViewModel
    var bottomInset: CGFloat
    var onEnterAR: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
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
                    selectedStopID: mapModel.selectedStopID,
                    showsCompass: false,
                    fitInsets: UIEdgeInsets(top: 28, left: 30, bottom: 30, right: 74)
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

            if let issue = tour.locationIssue {
                LocationIssueBanner(issue: issue)
                    .padding(.top, 8).padding(.trailing, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottomTrailing) {
            MapControlStack(mapModel: mapModel, onEnterAR: onEnterAR)
                .padding(.trailing, 16).padding(.bottom, 20)
        }
        .animation(.easeInOut(duration: 0.25), value: tour.locationIssue)
    }
}

/// AR entry, recenter and overview controls.
struct MapControlStack: View {
    @Environment(TourViewModel.self) private var tour
    var mapModel: MapViewModel
    var onEnterAR: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button(action: onEnterAR) {
                Image(systemName: "camera.viewfinder")
                    .frame(width: 46, height: 46)
                    .background(.white, in: Circle())
                    .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
            }
            .disabled(tour.loadState != .loaded)
            .opacity(tour.loadState == .loaded ? 1 : 0.45)
            .accessibilityLabel("AR walking directions")
            .accessibilityHint("Opens camera guidance to \(tour.currentStop?.name ?? tour.stops.first?.name ?? "the next tour stop")")
            .accessibilityIdentifier("map.enterAR")

            if GoogleMapsBootstrap.isConfigured {
                Button {
                    mapModel.requestFollow(tour: tour)
                } label: {
                    Image(systemName: "location.fill")
                        .frame(width: 46, height: 46)
                        .background(.white, in: Circle())
                        .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
                }
                .disabled(tour.userLocation == nil)
                .opacity(tour.userLocation == nil ? 0.45 : 1)
                .accessibilityLabel("Center on my location")

                Button {
                    mapModel.showUserAndDestination(tour: tour)
                } label: {
                    Image(systemName: "scope")
                        .frame(width: 46, height: 46)
                        .background(.white, in: Circle())
                        .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
                }
                .accessibilityLabel("Show route to next stop")
            }
        }
        .font(.system(size: 19, weight: .medium))
        .buttonStyle(.plain)
        .foregroundStyle(AppTheme.forest)
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
