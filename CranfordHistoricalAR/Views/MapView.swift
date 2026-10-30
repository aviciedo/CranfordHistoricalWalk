import SwiftUI
import MapKit
import TourCore

/// The map portion of the tour screen: Google map, user location, markers, camera controls and
/// the location/permission notices. Keeps no business logic.
struct TourMapView: View {
    @Environment(TourViewModel.self) private var tour
    var mapModel: MapViewModel
    var bottomInset: CGFloat
    @State private var appleMapError: String?

    var body: some View {
        GeometryReader { viewport in
            ZStack(alignment: .top) {
                if GoogleMapsBootstrap.isConfigured {
                    GoogleMapView(
                        markers: mapModel.markers(for: tour, emphasizesDestinationOnly: true),
                        userPuck: mapModel.userPuck(for: tour),
                        routeCoordinates: [], // Only recorded walking trail is drawn; route remains available for guidance.
                        cameraRequest: mapModel.cameraRequest,
                        bottomInset: bottomInset,
                        onUserGesture: { mapModel.userDidMoveCamera() },
                        onMarkerTap: { mapModel.select(stopID: $0) },
                        markerStyle: .numberedDot,
                        selectedStopID: mapModel.viewedStopID,
                        reservesNavigationControls: false,
                        showsCompass: false,
                        fitInsets: UIEdgeInsets(top: 40, left: 40, bottom: 56, right: 96),
                        onMapTap: { mapModel.clearViewedStop() },
                        trailSegments: mapModel.walkedTrailCoordinates(for: tour).map { $0.map(\.clLocationCoordinate) }
                    )
                } else {
                    AppleTourMapView(markers: mapModel.markers(for: tour, emphasizesDestinationOnly: true),
                        userPuck: mapModel.userPuck(for: tour),
                        routeCoordinates: [], // Only recorded walking trail is drawn; route remains available for guidance.
                        cameraRequest: mapModel.cameraRequest,
                        onUserGesture: { mapModel.userDidMoveCamera() },
                        onMarkerTap: { mapModel.select(stopID: $0) },
                        onMapError: { appleMapError = $0 }, reservesNavigationControls: false,
                        trailSegments: mapModel.walkedTrailCoordinates(for: tour).map { $0.map(\.clLocationCoordinate) })
                }

                if let appleMapError, !GoogleMapsBootstrap.isConfigured {
                    Label(appleMapError, systemImage: "wifi.exclamationmark")
                        .font(.footnote).padding(12)
                        .background(AppTheme.parchment, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 12).padding(.top, tour.locationIssue == nil ? 8 : 110)
                        .allowsHitTesting(false)
                }
                if let issue = tour.locationIssue {
                    LocationIssueBanner(issue: issue)
                        .padding(.top, 8).padding(.trailing, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button { mapModel.showUserAndDestination(tour: tour) } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(AppTheme.forest)
                        .frame(width: 48, height: 48).background(.white, in: Circle())
                        .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Recenter walking route")
                .accessibilityHint("Shows your location, departure stop and destination")
                .accessibilityIdentifier("map.recenter")
                    .padding(.trailing, 16).padding(.bottom, 20)
            }
            .onChange(of: viewport.size) { _, size in
                guard size.width > 0, size.height > 0 else { return }
                mapModel.mapViewportDidChange()
            }
        }
        .onChange(of: tour.userLocation) { _, _ in mapModel.updateWalkingFrame(tour: tour) }
        .onChange(of: tour.currentRoute) { _, _ in mapModel.updateWalkingFrame(tour: tour, routeChanged: true) }
        .onAppear { if mapModel.cameraRequest == nil { mapModel.showUserAndDestination(tour: tour) } }
        .onChange(of: tour.stops.count) { _, _ in
            if mapModel.cameraMode == .overview { mapModel.showUserAndDestination(tour: tour) }
        }
        .onChange(of: tour.userLocation == nil) { _, isNil in
            if !isNil, mapModel.cameraMode == .overview { mapModel.showUserAndDestination(tour: tour) }
        }
        .animation(.easeInOut(duration: 0.25), value: tour.locationIssue)
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
                Label("Illustrated overview · Not walking directions", systemImage: "map")
                    .font(.footnote.weight(.medium))
                    .padding(10).background(AppTheme.parchment, in: Capsule())
                    .padding(12).allowsHitTesting(false)
            }
    }
}

/// Real geographic fallback. Uses the app's single GPS source; never requests location itself.
struct AppleTourMapView: UIViewRepresentable {
    var markers: [StopMarkerModel]
    var userPuck: UserPuckModel?
    var routeCoordinates: [CLLocationCoordinate2D]
    var cameraRequest: MapCameraRequest?
    var onUserGesture: () -> Void
    var onMarkerTap: (String) -> Void
    var onMapError: (String?) -> Void = { _ in }
    var reservesNavigationControls = false
    var reservesZoomControls = false
    var onCameraIdle: (Float) -> Void = { _ in }
    var trailSegments: [[CLLocationCoordinate2D]] = []

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.showsUserLocation = false
        map.showsCompass = false
        map.isPitchEnabled = false
        let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        configuration.pointOfInterestFilter = .excludingAll
        map.preferredConfiguration = configuration
        map.pointOfInterestFilter = .excludingAll
        map.overrideUserInterfaceStyle = .light
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.render(on: map)
    }

    final class SiteAnnotation: NSObject, MKAnnotation {
        let stopID: String?
        @objc dynamic var coordinate: CLLocationCoordinate2D
        var title: String?
        var marker: StopMarkerModel?
        init(marker: StopMarkerModel) {
            stopID = marker.id; coordinate = marker.coordinate; title = marker.name; self.marker = marker
        }
        init(puck: UserPuckModel) {
            stopID = nil; coordinate = puck.coordinate; title = puck.isSimulated ? "Practice location" : "Your location"
        }
    }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: AppleTourMapView
        private var sites: [String: SiteAnnotation] = [:]
        private var puck: SiteAnnotation?
        private var route: MKPolyline?
        private var accuracy: MKCircle?
        private var geometry: [GeoCoordinate] = []
        private var trails: [MKPolyline] = []
        private var trailGeometry: [[GeoCoordinate]] = []
        private var cameraID: Int?
        private var hasFitInitialMap = false
        private var layoutRetry: Task<Void, Never>?
        private var layoutAttempts = 0
        private var markerImages: [String: UIImage] = [:]
        private var markerScale: CGFloat = 1
        private var markerPlacements: [String: MapMarkerSizing.Placement] = [:]
        private let markerLeaders = StopMapLeaderView()

        init(_ parent: AppleTourMapView) { self.parent = parent }

        func render(on map: MKMapView) {
            let trace = parent.trailSegments.map { $0.map(\.geoCoordinate) }
            if trace != trailGeometry {
                map.removeOverlays(trails)
                trailGeometry = trace
                trails = parent.trailSegments.filter { $0.count >= 2 }.map { MKPolyline(coordinates: $0, count: $0.count) }
                map.addOverlays(trails, level: .aboveRoads)
            }
            let ids = Set(parent.markers.map(\.id))
            for id in Array(sites.keys) where !ids.contains(id) {
                if let site = sites.removeValue(forKey: id) { map.removeAnnotation(site) }
            }
            for marker in parent.markers {
                if let site = sites[marker.id] {
                    if site.marker != marker {
                        site.coordinate = marker.coordinate; site.title = marker.name; site.marker = marker
                        if let view = map.view(for: site) { configure(view, for: site) }
                    }
                } else {
                    let site = SiteAnnotation(marker: marker); sites[marker.id] = site; map.addAnnotation(site)
                }
            }
            if let sample = parent.userPuck {
                if let puck {
                    UIView.animate(withDuration: 0.35, delay: 0, options: [.beginFromCurrentState, .curveLinear]) {
                        puck.coordinate = sample.coordinate
                    }
                }
                else { let point = SiteAnnotation(puck: sample); puck = point; map.addAnnotation(point) }
                if let accuracy { map.removeOverlay(accuracy) }
                let circle = MKCircle(center: sample.coordinate, radius: max(0, sample.accuracyMeters))
                accuracy = circle; map.addOverlay(circle, level: .aboveRoads)
            } else {
                if let puck { map.removeAnnotation(puck) }; puck = nil
                if let accuracy { map.removeOverlay(accuracy) }; accuracy = nil
            }
            let points = parent.routeCoordinates.map { GeoCoordinate($0) }
            if geometry != points {
                geometry = points
                if let route { map.removeOverlay(route) }; route = nil
                if parent.routeCoordinates.count >= 2 {
                    let line = MKPolyline(coordinates: parent.routeCoordinates, count: parent.routeCoordinates.count)
                    route = line; map.addOverlay(line, level: .aboveRoads)
                }
            }
            // A bounds fit needs the hosting view's real size, not its initial zero frame.
            guard !map.bounds.isEmpty else {
                if layoutRetry == nil, layoutAttempts < 20 {
                    layoutAttempts += 1
                    layoutRetry = Task { @MainActor [weak self, weak map] in
                        try? await Task.sleep(for: .milliseconds(50))
                        guard let self, let map else { return }
                        self.layoutRetry = nil
                        self.render(on: map)
                    }
                }
                return
            }
            layoutAttempts = 0
            if let request = parent.cameraRequest, request.id != cameraID {
                cameraID = request.id
                switch request.kind {
                case .fitAll: fit(parent.markers.map(\.coordinate), on: map, animated: request.animated)
                case .follow(let coordinate, let bearing):
                    let camera = MKMapCamera(lookingAtCenter: coordinate, fromDistance: 850, pitch: 0, heading: bearing ?? 0)
                    map.setCamera(camera, animated: request.animated)
                case .fitUserAndDestination(let user, let destination):
                    fit([user, destination] + parent.routeCoordinates, on: map, animated: request.animated)
                case .fitWalkingLeg(let coordinates):
                    fit(coordinates.map(\.clLocationCoordinate), on: map, animated: request.animated)
                case .zoomTo(let target):
                    let current = zoomLevel(on: map)
                    let factor = pow(2.0, Double(current - target))
                    let camera = MKMapCamera(lookingAtCenter: map.centerCoordinate,
                        fromDistance: max(1, map.camera.centerCoordinateDistance) * factor,
                        pitch: map.camera.pitch, heading: map.camera.heading)
                    map.setCamera(camera, animated: request.animated)
                }
                hasFitInitialMap = !parent.markers.isEmpty
            } else if !hasFitInitialMap && !parent.markers.isEmpty {
                fit(parent.markers.map(\.coordinate), on: map, animated: false)
                hasFitInitialMap = true
            }
            updateMarkerSizes(on: map)
        }

        private func fit(_ coordinates: [CLLocationCoordinate2D], on map: MKMapView, animated: Bool) {
            guard !coordinates.isEmpty else { return }
            var bounds = MKMapRect.null
            for coordinate in coordinates {
                let point = MKMapPoint(coordinate)
                bounds = bounds.union(MKMapRect(x: point.x, y: point.y, width: 1, height: 1))
            }
            // Give coincident user/destination a usable street-level region.
            let minimum = 250 / MKMetersPerMapPointAtLatitude(coordinates[0].latitude)
            if bounds.width < minimum { bounds = bounds.insetBy(dx: -(minimum - bounds.width) / 2, dy: 0) }
            if bounds.height < minimum { bounds = bounds.insetBy(dx: 0, dy: -(minimum - bounds.height) / 2) }
            map.setVisibleMapRect(bounds, edgePadding: UIEdgeInsets(top: min(40, map.bounds.height * 0.2), left: 40, bottom: min(56, map.bounds.height * 0.3), right: 96), animated: animated)
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            let recognizers = mapView.subviews.flatMap { $0.gestureRecognizers ?? [] } + (mapView.gestureRecognizers ?? [])
            if recognizers.contains(where: { $0.state == .began || $0.state == .changed }) { parent.onUserGesture() }
        }

        private func zoomLevel(on map: MKMapView) -> Float {
            guard map.bounds.width > 0 else { return MapZoomPolicy.initial }
            let metersPerPoint = map.visibleMapRect.size.width / Double(map.bounds.width)
                * MKMetersPerMapPointAtLatitude(map.centerCoordinate.latitude)
            return MapZoomPolicy.level(metersPerPoint: metersPerPoint, latitude: map.centerCoordinate.latitude)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            updateMarkerSizes(on: mapView)
            let zoom = zoomLevel(on: mapView)
            Task { @MainActor [weak self] in self?.parent.onCameraIdle(zoom) }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let site = annotation as? SiteAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: "tour.site") ?? MKAnnotationView(annotation: site, reuseIdentifier: "tour.site")
            view.annotation = site; view.canShowCallout = false
            configure(view, for: site)
            return view
        }

        private func configure(_ view: MKAnnotationView, for site: SiteAnnotation) {
            view.isAccessibilityElement = true
            view.accessibilityLabel = site.title
            if let marker = site.marker {
                if !marker.isIllustrated {
                    view.subviews.filter { $0 is StopMapIconView }.forEach { $0.removeFromSuperview() }
                    let key = "compact|\(marker.id)|\(marker.order)"
                    if markerImages[key] == nil { markerImages[key] = StopMapArtwork.compactImage(for: marker) }
                    view.image = markerImages[key]
                    view.zPriority = .defaultSelected
                    view.bounds = CGRect(x: 0, y: 0, width: 44, height: 44)
                    view.centerOffset = .zero
                    view.isHidden = false
                    view.displayPriority = .required
                    view.accessibilityTraits = .button
                    view.accessibilityHint = "View stop"
                    return
                }
                view.image = nil
                let icon = (view.subviews.first { $0 is StopMapIconView } as? StopMapIconView) ?? StopMapIconView()
                if icon.superview == nil { view.addSubview(icon) }
                let key = "\(marker.id)|\(marker.order)|\(marker.state)"
                if markerImages[key] == nil { markerImages[key] = StopMapArtwork.image(for: marker) }
                icon.setArtwork(markerImages[key])
                icon.resize(scale: markerScale)
                view.bounds = icon.bounds
                icon.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
                if let placement = markerPlacements[marker.id] {
                    view.centerOffset = CGPoint(x: placement.center.x - placement.site.x,
                                                y: placement.center.y - placement.site.y)
                    view.isHidden = !placement.isVisible
                } else {
                    view.centerOffset = .zero
                }
                view.accessibilityTraits = .button
                view.accessibilityHint = "View stop"
                view.displayPriority = .required
                view.zPriority = marker.state == .current ? .max : .defaultSelected
            } else {
                view.subviews.filter { $0 is StopMapIconView }.forEach { $0.removeFromSuperview() }
                view.image = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { context in
                    UIColor.white.setFill(); context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: 24, height: 24))
                    UIColor.systemBlue.setFill(); context.cgContext.fillEllipse(in: CGRect(x: 3, y: 3, width: 18, height: 18))
                }
                view.isHidden = false
                view.centerOffset = .zero; view.displayPriority = .required; view.zPriority = .max
                view.accessibilityTraits = .updatesFrequently
                view.accessibilityHint = nil
            }
        }

        private func updateMarkerSizes(on map: MKMapView) {
            guard !map.bounds.isEmpty else { return }
            let models = parent.markers.filter(\.isIllustrated).sorted { ($0.order, $0.id) < ($1.order, $1.id) }
            let points = models.map { marker -> SIMD2<Double> in
                let point = map.convert(marker.coordinate, toPointTo: map)
                return SIMD2(Double(point.x), Double(point.y))
            }
            let metersPerPoint = map.visibleMapRect.size.width / Double(map.bounds.width)
                * MKMetersPerMapPointAtLatitude(map.centerCoordinate.latitude)
            let compactAreas = parent.markers.filter { !$0.isIllustrated }.map { marker -> CGRect in
                let point = map.convert(marker.coordinate, toPointTo: map)
                return CGRect(x: point.x - 22, y: point.y - 22, width: 44, height: 44)
            }
            let recenterArea = CGRect(x: map.bounds.maxX - 72, y: map.bounds.maxY - 76, width: 64, height: 64)
            let layout = MapMarkerSizing.layout(points: points, metersPerPoint: metersPerPoint,
                viewport: StopMapLeaderView.viewport(in: map.bounds),
                reservedAreas: compactAreas + (parent.reservesNavigationControls ? [] : [recenterArea]) + StopMapLeaderView.reservedAreas(in: map.bounds, controls: parent.reservesNavigationControls,
                                                              zoomControls: parent.reservesZoomControls))
            markerScale = CGFloat(layout.scale)
            markerPlacements = Dictionary(uniqueKeysWithValues: zip(models, layout.placements).map { ($0.id, $1) })
            for site in sites.values {
                guard let view = map.view(for: site) else { continue }
                configure(view, for: site)
            }
            markerLeaders.update(layout, in: map)
        }

        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            updateMarkerSizes(on: mapView)
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let site = view.annotation as? SiteAnnotation, let id = site.stopID else { return }
            parent.onMarkerTap(id)
            mapView.deselectAnnotation(site, animated: false)
        }

        func mapView(_ mapView: MKMapView, didFailLoadingMapWithError error: Error) {
            parent.onMapError("Map couldn’t load. Check your connection before following the route.")
        }

        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) { parent.onMapError(nil) }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.1)
                return renderer
            }
            let renderer = MKPolylineRenderer(overlay: overlay)
            let isTrail = (overlay as? MKPolyline).map { line in trails.contains { $0 === line } } ?? false
            renderer.strokeColor = UIColor(AppTheme.forest)
            renderer.lineWidth = isTrail ? 4 : 5; renderer.lineCap = .round; renderer.lineJoin = .round
            return renderer
        }
    }
}
