import CoreLocation
import GoogleMaps
import SwiftUI
import TourCore
import UIKit

/// Thin `UIViewRepresentable` around `GMSMapView` (the Maps SDK is UIKit-only, which is the one
/// place the spec allows UIKit). All decisions live in `MapViewModel`/`TourViewModel`; this view
/// only diffs models into markers, polylines and camera moves.
struct GoogleMapView: UIViewRepresentable {
    var markers: [StopMarkerModel]
    var userPuck: UserPuckModel?
    var routeCoordinates: [CLLocationCoordinate2D]
    var cameraRequest: MapCameraRequest?
    var bottomInset: CGFloat
    var onUserGesture: () -> Void
    var onMarkerTap: (String) -> Void
    var markerStyle: StopMarkerStyle = .labeledPin
    /// Highlighted stop for dot styles (the labeled pin style has no selection state).
    var selectedStopID: String? = nil
    var reservesNavigationControls = false
    var reservesZoomControls = false
    var showsCompass = true
    var overviewIncludesUserLocation = true
    /// Padding used when fitting all stops into view.
    var fitInsets = UIEdgeInsets(top: 90, left: 40, bottom: 40, right: 40)
    /// Tap on the map away from any marker (used to dismiss callouts).
    var onMapTap: () -> Void = {}
    /// Camera came to rest at this zoom level.
    var onCameraIdle: (Float) -> Void = { _ in }

    static let cranfordFallbackCamera = GMSCameraPosition(latitude: 40.6584, longitude: -74.3035, zoom: 15.2)

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> GMSMapView {
        let options = GMSMapViewOptions()
        options.camera = Self.cranfordFallbackCamera
        options.frame = .zero
        let mapView = GMSMapView(options: options)
        mapView.delegate = context.coordinator
        // The puck is drawn from TourViewModel's single location source (works in simulation too).
        mapView.isMyLocationEnabled = false
        mapView.settings.myLocationButton = false
        mapView.settings.compassButton = showsCompass
        mapView.settings.tiltGestures = false
        // Pinch, pan and double-tap zoom are on by default; make it explicit so a future change cannot
        // silently disable them.
        mapView.settings.zoomGestures = true
        mapView.settings.scrollGestures = true
        mapView.isBuildingsEnabled = false
        mapView.isIndoorEnabled = false
        mapView.isTrafficEnabled = false
        mapView.mapStyle = MapStyle.style(for: context.environment.colorScheme)
        context.coordinator.mapView = mapView
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        context.coordinator.parent = self
        mapView.padding = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
        if context.coordinator.colorScheme != context.environment.colorScheme {
            context.coordinator.colorScheme = context.environment.colorScheme
            mapView.mapStyle = MapStyle.style(for: context.environment.colorScheme)
        }
        context.coordinator.render(markers: markers, style: markerStyle, selectedID: selectedStopID)
        context.coordinator.updateMarkerSizes()
        context.coordinator.render(userPuck: userPuck)
        context.coordinator.render(route: routeCoordinates)
        context.coordinator.apply(cameraRequest: cameraRequest)
    }

    // MARK: Coordinator

    @MainActor
    final class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: GoogleMapView
        weak var mapView: GMSMapView?
        var colorScheme: ColorScheme?

        private var markersByID: [String: GMSMarker] = [:]
        private var markerModels: [String: StopMarkerModel] = [:]
        private var iconCache: [String: UIImage] = [:]
        private var markerStyle: StopMarkerStyle = .labeledPin
        private var markerColorScheme: ColorScheme?
        private var selectedID: String?
        private var stopPopup: StopNameInfoWindow?
        private var popupSignature: String?
        private var cameraRetryCount = 0
        private var markerSnapshotTask: Task<Void, Never>?
        private let markerLeaders = StopMapLeaderView()

        private var userMarker: GMSMarker?
        private var accuracyCircle: GMSCircle?
        private var lastPuck: UserPuckModel?

        private var polyline: GMSPolyline?
        private var polylineCasing: GMSPolyline?
        private var lastRoute: [CLLocationCoordinate2D] = []

        private var lastCameraRequestID: Int = -1
        /// Maps SDK can deliver `didTapAt` for the same gesture as a marker tap; ignore those.
        private var ignoreMapTapUntil: Date?

        init(_ parent: GoogleMapView) {
            self.parent = parent
        }

        // MARK: Markers

        func render(markers: [StopMarkerModel], style: StopMarkerStyle, selectedID newSelectedID: String?) {
            guard let mapView else { return }
            let styleChanged = style != markerStyle || markerColorScheme != colorScheme
            markerColorScheme = colorScheme
            let previousSelected = selectedID
            markerStyle = style
            selectedID = newSelectedID

            let incoming = Set(markers.map(\.id))
            for (id, marker) in markersByID where !incoming.contains(id) {
                marker.map = nil
                markersByID[id] = nil
                markerModels[id] = nil
            }
            for model in markers {
                let isSelected = model.id == newSelectedID
                if let existing = markersByID[model.id] {
                    let selectionChanged = previousSelected != newSelectedID
                        && (model.id == previousSelected || isSelected)
                    if markerModels[model.id] != model || styleChanged || selectionChanged {
                        applyAppearance(existing, model: model, isSelected: isSelected)
                        markerModels[model.id] = model
                    }
                } else {
                    let marker = GMSMarker(position: model.coordinate)
                    marker.userData = model.id
                    marker.appearAnimation = .pop
                    applyAppearance(marker, model: model, isSelected: isSelected)
                    marker.map = mapView
                    markersByID[model.id] = marker
                    markerModels[model.id] = model
                }
            }
            syncSelectedMarker(on: mapView, selectedID: newSelectedID)
        }

        private func applyAppearance(_ marker: GMSMarker, model: StopMarkerModel, isSelected: Bool) {
            marker.title = model.name
            marker.snippet = model.information
            marker.isTappable = true
            marker.groundAnchor = groundAnchor
            marker.zIndex = zIndex(for: model.state, isSelected: isSelected)
            marker.position = model.coordinate
            applyIcon(marker, image: icon(for: model, isSelected: isSelected))
        }

        /// Dot styles use `iconView` so the whole 56 pt control is tappable, not just opaque pixels
        /// of a padded `UIImage`. Labeled pins keep `icon` (the artwork is already the hit box).
        private func applyIcon(_ marker: GMSMarker, image: UIImage?) {
            if markerStyle == .labeledPin {
                marker.iconView = nil
                marker.icon = image
                marker.tracksViewChanges = false
                return
            }
            if markerStyle == .numberedDot {
                let view = (marker.iconView as? StopMapIconView) ?? StopMapIconView()
                view.imageView.image = image
                marker.icon = nil
                marker.iconView = view
                marker.tracksViewChanges = false
                return
            }
            let view = UIImageView(image: image)
            view.bounds = CGRect(x: 0, y: 0, width: 56, height: 56)
            view.contentMode = .center
            view.isUserInteractionEnabled = false
            marker.icon = nil
            marker.iconView = view
            marker.tracksViewChanges = false
        }

        private func syncSelectedMarker(on mapView: GMSMapView, selectedID: String?) {
            // SDK info windows are raster snapshots; use a real view for an interactive X.
            mapView.selectedMarker = nil
            guard let selectedID, let marker = markersByID[selectedID] else {
                stopPopup?.removeFromSuperview()
                stopPopup = nil
                popupSignature = nil
                return
            }
            let width = max(120, min(300, mapView.bounds.width - 24))
            let maximumHeight = max(100, mapView.bounds.height - 84)
            let signature = "\(selectedID)|\(marker.title ?? "")|\(marker.snippet ?? "")|\(width)|\(maximumHeight)"
            if popupSignature != signature {
                stopPopup?.removeFromSuperview()
                let popup = StopNameInfoWindow(title: marker.title ?? "", details: marker.snippet,
                                               width: width, maximumHeight: maximumHeight) { [weak self] in
                    self?.dismissStopPopup()
                }
                stopPopup = popup
                popupSignature = signature
                mapView.addSubview(popup)
            }
            updatePopupPlacement()
        }

        private func dismissStopPopup() {
            stopPopup?.removeFromSuperview()
            stopPopup = nil
            popupSignature = nil
            selectedID = nil
            mapView?.selectedMarker = nil
            parent.onMapTap()
        }

        private func updatePopupPlacement() {
            guard let mapView, let popup = stopPopup, let id = selectedID,
                  let marker = markersByID[id], !mapView.bounds.isEmpty else { return }
            let point = mapView.projection.point(for: marker.position)
            let maxX = max(12, mapView.bounds.width - popup.bounds.width - 12)
            let maxY = max(12, mapView.bounds.height - max(parent.bottomInset, 48) - popup.bounds.height - 12)
            popup.frame.origin = CGPoint(x: min(maxX, max(12, point.x - popup.bounds.width / 2)),
                                         y: min(maxY, max(12, point.y - popup.bounds.height - 28)))
            mapView.bringSubviewToFront(popup)
        }

        /// Pins stand on their tip; dots are centred on the coordinate.
        private var groundAnchor: CGPoint {
            markerStyle == .labeledPin ? CGPoint(x: 0.5, y: 1.0) : CGPoint(x: 0.5, y: 0.5)
        }

        private func zIndex(for state: StopMarkerModel.State, isSelected: Bool) -> Int32 {
            if isSelected { return 40 }
            switch state {
            case .current: return 30
            case .upcoming: return 20
            case .visited: return 10
            }
        }

        private func icon(for model: StopMarkerModel, isSelected: Bool) -> UIImage? {
            let key = "\(markerStyle)|\(isSelected)|\(model.order)|\(model.state)|\(model.name)|\(colorScheme == .dark)"
            if let cached = iconCache[key] { return cached }
            let scheme = colorScheme ?? .light
            let renderer: ImageRenderer<AnyView>
            switch markerStyle {
            case .labeledPin:
                renderer = ImageRenderer(content: AnyView(StopMarkerLabel(model: model).environment(\.colorScheme, scheme)))
            case .numberedDot:
                let image = StopMapArtwork.image(for: model, isSelected: isSelected, scheme: scheme)
                iconCache[key] = image
                return image
            case .dot:
                renderer = ImageRenderer(content: AnyView(StopDotMarker(model: model, isSelected: isSelected, showsNumber: markerStyle == .numberedDot).environment(\.colorScheme, scheme)))
            }
            renderer.scale = UITraitCollection.current.displayScale
            let image = renderer.uiImage
            iconCache[key] = image
            return image
        }

        /// Recompute from canonical sites during camera changes, using identical Apple/Google math.
        func updateMarkerSizes() {
            guard markerStyle == .numberedDot, let mapView, !mapView.bounds.isEmpty else { return }
            let models = markerModels.values.sorted { ($0.order, $0.id) < ($1.order, $1.id) }
            let points = models.map { model -> SIMD2<Double> in
                let point = mapView.projection.point(for: model.coordinate)
                return SIMD2(Double(point.x), Double(point.y))
            }
            let latitude = mapView.camera.target.latitude * Double.pi / 180.0
            let metersPerPoint = 156543.03392 * cos(latitude) / pow(2.0, Double(mapView.camera.zoom))
            let viewport = StopMapLeaderView.viewport(in: mapView.bounds, bottomInset: parent.bottomInset)
            let reserved = StopMapLeaderView.reservedAreas(in: mapView.bounds, controls: parent.reservesNavigationControls,
                                                         zoomControls: parent.reservesZoomControls)
            let layout = MapMarkerSizing.layout(points: points, metersPerPoint: metersPerPoint,
                                                viewport: viewport, reservedAreas: reserved)
            for (model, placement) in zip(models, layout.placements) {
                guard let marker = markersByID[model.id], let view = marker.iconView as? StopMapIconView else { continue }
                marker.tracksViewChanges = true
                view.resize(scale: CGFloat(layout.scale))
                // This display coordinate is derived anew from the original GPS point each frame.
                // Models, walking routes, camera fitting and location services retain the true site.
                if placement.isVisible {
                    marker.position = mapView.projection.coordinate(for: CGPoint(x: placement.center.x, y: placement.center.y))
                }
                marker.opacity = placement.isVisible ? 1 : 0
                marker.isTappable = placement.isVisible
                marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
            }
            markerLeaders.update(layout, in: mapView)
            updatePopupPlacement()
            markerSnapshotTask?.cancel()
            markerSnapshotTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled, let self else { return }
                for marker in self.markersByID.values { marker.tracksViewChanges = false }
            }
        }

        // MARK: User puck

        func render(userPuck: UserPuckModel?) {
            guard let mapView else { return }
            guard let puck = userPuck else {
                userMarker?.map = nil
                accuracyCircle?.map = nil
                userMarker = nil
                accuracyCircle = nil
                lastPuck = nil
                return
            }
            guard puck != lastPuck else { return }
            lastPuck = puck

            if userMarker == nil {
                let marker = GMSMarker(position: puck.coordinate)
                marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
                marker.isFlat = true
                marker.zIndex = 100
                marker.isTappable = false
                marker.map = mapView
                userMarker = marker
                let circle = GMSCircle(position: puck.coordinate, radius: puck.accuracyMeters)
                circle.fillColor = UIColor.systemBlue.withAlphaComponent(0.12)
                circle.strokeColor = UIColor.systemBlue.withAlphaComponent(0.25)
                circle.strokeWidth = 1
                circle.zIndex = 5
                circle.map = mapView
                accuracyCircle = circle
            }
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.35)
            userMarker?.position = puck.coordinate
            accuracyCircle?.position = puck.coordinate
            CATransaction.commit()
            accuracyCircle?.radius = max(puck.accuracyMeters, 3)

            let key = "puck|\(puck.heading != nil)|\(puck.isSimulated)"
            if iconCache[key] == nil {
                let renderer = ImageRenderer(content: UserPuckView(hasHeading: puck.heading != nil, isSimulated: puck.isSimulated))
                renderer.scale = UITraitCollection.current.displayScale
                iconCache[key] = renderer.uiImage
            }
            userMarker?.icon = iconCache[key]
            userMarker?.rotation = puck.heading ?? 0
        }

        // MARK: Route

        static func routesMatch(_ lhs: [CLLocationCoordinate2D], _ rhs: [CLLocationCoordinate2D]) -> Bool {
            lhs.count == rhs.count && zip(lhs, rhs).allSatisfy {
                $0.latitude == $1.latitude && $0.longitude == $1.longitude
            }
        }

        func render(route: [CLLocationCoordinate2D]) {
            guard let mapView else { return }
            // Compare every point: a reroute can keep its endpoints and midpoint while
            // changing the streets in between. Do not leave the old path on screen.
            guard !Self.routesMatch(route, lastRoute) else { return }
            lastRoute = route

            guard route.count >= 2 else {
                polyline?.map = nil
                polylineCasing?.map = nil
                polyline = nil
                polylineCasing = nil
                return
            }
            let path = GMSMutablePath()
            route.forEach(path.add)

            if polylineCasing == nil {
                let casing = GMSPolyline(path: path)
                casing.strokeWidth = 9
                casing.strokeColor = UIColor.white.withAlphaComponent(0.9)
                casing.zIndex = 1
                casing.map = mapView
                polylineCasing = casing
            } else {
                polylineCasing?.path = path
            }
            if polyline == nil {
                let line = GMSPolyline(path: path)
                line.strokeWidth = 5
                line.strokeColor = UIColor(AppTheme.heritageGreen)
                line.zIndex = 2
                line.map = mapView
                polyline = line
            } else {
                polyline?.path = path
            }
        }

        // MARK: Camera

        func apply(cameraRequest: MapCameraRequest?) {
            guard let mapView, let request = cameraRequest, request.id != lastCameraRequestID,
                  request.id == parent.cameraRequest?.id else { return }
            // A bounds fit is computed against the map's current size; before the first layout pass
            // that size is zero and the fit would land on the wrong zoom. Try again shortly.
            if mapView.bounds.isEmpty, cameraRetryCount < 20 {
                cameraRetryCount += 1
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(50))
                    self?.apply(cameraRequest: request)
                }
                return
            }
            cameraRetryCount = 0
            lastCameraRequestID = request.id

            let update: GMSCameraUpdate
            switch request.kind {
            case .fitAll:
                let coordinates = markerModels.values.map(\.coordinate)
                    + (parent.overviewIncludesUserLocation ? (lastPuck.map { [$0.coordinate] } ?? []) : [])
                guard var bounds = coordinates.first.map({ GMSCoordinateBounds(coordinate: $0, coordinate: $0) }) else {
                    mapView.animate(to: GoogleMapView.cranfordFallbackCamera)
                    return
                }
                for c in coordinates.dropFirst() { bounds = bounds.includingCoordinate(c) }
                update = GMSCameraUpdate.fit(bounds, with: parent.fitInsets)
            case .follow(let coordinate, let bearing):
                let position = GMSCameraPosition(target: coordinate, zoom: max(mapView.camera.zoom, 16.5), bearing: bearing ?? mapView.camera.bearing, viewingAngle: 0)
                update = GMSCameraUpdate.setCamera(position)
            case .fitUserAndDestination(let a, let b):
                var bounds = GMSCoordinateBounds(coordinate: a, coordinate: b)
                for coordinate in parent.routeCoordinates { bounds = bounds.includingCoordinate(coordinate) }
                update = GMSCameraUpdate.fit(bounds, with: parent.fitInsets)
            case .zoomTo(let zoom):
                update = GMSCameraUpdate.zoom(to: zoom)
            }
            if request.animated {
                mapView.animate(with: update)
            } else {
                mapView.moveCamera(update)
            }
        }

        // MARK: GMSMapViewDelegate

        nonisolated func mapView(_ mapView: GMSMapView, willMove gesture: Bool) {
            guard gesture else { return }
            Task { @MainActor in self.parent.onUserGesture() }
        }

        nonisolated func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            let id = marker.userData as? String
            let displayPosition = marker.position
            Task { @MainActor in
                let position = id.flatMap { self.markerModels[$0]?.coordinate } ?? displayPosition
                self.ignoreMapTapUntil = Date().addingTimeInterval(0.4)
                if let id { self.parent.onMarkerTap(id) }
                self.mapView?.animate(toLocation: position)
            }
            // Consume the SDK tap; the selected stop drives the interactive popup and details.
            return true
        }

        nonisolated func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            Task { @MainActor in
                if let until = self.ignoreMapTapUntil, Date() < until { return }
                self.dismissStopPopup()
            }
        }

        nonisolated func mapView(_ mapView: GMSMapView, markerInfoWindow marker: GMSMarker) -> UIView? {
            nil // All stop popups are live overlay views, not SDK snapshots.
        }

        nonisolated func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
            MainActor.assumeIsolated {
                self.updateMarkerSizes()
                self.updatePopupPlacement()
            }
        }

        nonisolated func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
            let zoom = position.zoom
            Task { @MainActor in
                self.updateMarkerSizes()
                if let map = self.mapView { self.syncSelectedMarker(on: map, selectedID: self.selectedID) }
                self.parent.onCameraIdle(zoom)
            }
        }
    }
}

/// Shared Google/Apple artwork: large landmark with a consistent bottom-left number badge.
@MainActor
enum StopMapArtwork {
    static func image(for marker: StopMarkerModel, isSelected: Bool = false, scheme: ColorScheme = .light) -> UIImage {
        let renderer = ImageRenderer(content:
            ZStack(alignment: .bottomLeading) {
                StopListIllustration(stopID: marker.id)
                    .frame(width: 96, height: 70)
                    .frame(width: 100, height: 80, alignment: .top)
                Text("\(marker.order)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(marker.state == .current ? AppTheme.terracotta : AppTheme.forest, in: Circle())
                    .overlay(Circle().strokeBorder(isSelected ? AppTheme.brass : .white, lineWidth: 2))
            }
            .frame(width: CGFloat(MapMarkerSizing.width), height: CGFloat(MapMarkerSizing.height))
            .environment(\.colorScheme, scheme))
        renderer.scale = 3
        return renderer.uiImage ?? UIImage()
    }
}

/// A 44-point touch target remains available even when the visible map artwork is small.
@MainActor
final class StopMapIconView: UIView {
    let imageView = UIImageView()

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
        resize(scale: 1)
    }

    required init?(coder: NSCoder) { nil }

    func resize(scale: CGFloat) {
        let size = CGSize(width: CGFloat(MapMarkerSizing.width) * scale,
                          height: CGFloat(MapMarkerSizing.height) * scale)
        bounds = CGRect(x: 0, y: 0, width: max(44, size.width), height: max(44, size.height))
        imageView.frame = CGRect(x: (bounds.width - size.width) / 2,
                                 y: (bounds.height - size.height) / 2,
                                 width: size.width, height: size.height)
    }
}

/// Lightweight, noninteractive location lines. It never steals map gestures or marker taps.
@MainActor
final class StopMapLeaderView: UIView {
    private let lines = CAShapeLayer()
    private let sites = CAShapeLayer()

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        backgroundColor = .clear
        lines.fillColor = nil
        lines.strokeColor = UIColor(AppTheme.forest).withAlphaComponent(0.65).cgColor
        lines.lineWidth = 1.25
        lines.lineCap = .round
        sites.fillColor = UIColor(AppTheme.forest).cgColor
        sites.strokeColor = UIColor(AppTheme.ivory).cgColor
        sites.lineWidth = 1
        layer.addSublayer(lines)
        layer.addSublayer(sites)
    }

    required init?(coder: NSCoder) { nil }

    static func viewport(in bounds: CGRect, bottomInset: CGFloat = 0) -> CGRect {
        bounds.inset(by: UIEdgeInsets(top: 10, left: 10, bottom: max(32, bottomInset + 10), right: 10))
    }

    static func reservedAreas(in bounds: CGRect, controls: Bool, zoomControls: Bool = false) -> [CGRect] {
        if controls {
            if bounds.height < CGFloat(MapScreenSizing.compactControlsThreshold) {
                return [CGRect(x: bounds.maxX - 192, y: bounds.maxY - 80, width: 184, height: 72)]
            }
            return [CGRect(x: bounds.maxX - 76, y: bounds.maxY - 204, width: 68, height: 196)]
        }
        if zoomControls { return [CGRect(x: bounds.maxX - 76, y: bounds.maxY - 144, width: 68, height: 136)] }
        return []
    }

    func update(_ layout: MapMarkerSizing.Layout, in map: UIView) {
        if superview !== map { map.addSubview(self) }
        frame = map.bounds
        let path = UIBezierPath()
        let dots = UIBezierPath()
        for placement in layout.placements where placement.isVisible {
            guard let end = placement.leaderEnd else { continue }
            let site = CGPoint(x: placement.site.x, y: placement.site.y)
            path.move(to: site)
            path.addLine(to: CGPoint(x: end.x, y: end.y))
            dots.append(UIBezierPath(ovalIn: CGRect(x: site.x - 2.5, y: site.y - 2.5, width: 5, height: 5)))
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        lines.path = path.cgPath
        sites.path = dots.cgPath
        CATransaction.commit()
    }
}

/// A live map overlay: its X dismisses only this popup, independently of screen navigation.
@MainActor
final class StopNameInfoWindow: UIView {
    init(title: String, details: String? = nil, width: CGFloat, maximumHeight: CGFloat,
         onClose: @escaping () -> Void) {
        let heading = UILabel()
        heading.text = title
        heading.font = .preferredFont(forTextStyle: .headline)
        heading.textColor = UIColor(AppTheme.forest)
        heading.numberOfLines = 0
        heading.adjustsFontForContentSizeCategory = true
        let headingHeight = max(28, ceil(heading.sizeThatFits(CGSize(width: width - 68, height: .greatestFiniteMagnitude)).height))
        let body = UILabel()
        body.text = details
        body.font = .preferredFont(forTextStyle: .footnote)
        body.textColor = UIColor(AppTheme.forest)
        body.numberOfLines = 0
        body.adjustsFontForContentSizeCategory = true
        let bodyHeight = ceil(body.sizeThatFits(CGSize(width: width - 24, height: .greatestFiniteMagnitude)).height)
        let contentHeight = max(44, headingHeight) + (bodyHeight > 0 ? bodyHeight + 12 : 0)
        super.init(frame: CGRect(x: 0, y: 0, width: width, height: min(maximumHeight, contentHeight + 24)))
        backgroundColor = UIColor(AppTheme.ivory).withAlphaComponent(0.98)
        layer.cornerRadius = 14
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.16
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 3)

        let scroll = UIScrollView(frame: bounds.insetBy(dx: 12, dy: 12))
        scroll.contentSize = CGSize(width: width - 24, height: contentHeight)
        heading.frame = CGRect(x: 0, y: 0, width: width - 68, height: headingHeight)
        body.frame = CGRect(x: 0, y: max(44, headingHeight) + 8, width: width - 24, height: bodyHeight)
        scroll.addSubview(heading)
        scroll.addSubview(body)
        addSubview(scroll)

        let close = UIButton(type: .system)
        close.frame = CGRect(x: width - 48, y: 4, width: 44, height: 44)
        close.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)), for: .normal)
        close.tintColor = UIColor(AppTheme.forest)
        close.backgroundColor = UIColor(AppTheme.ivory)
        close.layer.cornerRadius = 22
        close.accessibilityLabel = "Dismiss stop popup"
        close.accessibilityIdentifier = "map.popup.close"
        close.addAction(UIAction { _ in onClose() }, for: .touchUpInside)
        addSubview(close)
        accessibilityElements = [heading, close, body]
    }

    required init?(coder: NSCoder) { nil }
}

/// Compact marker for overview maps with many stops: a dot, optionally numbered, that grows and
/// gains a brass ring when selected. No text label, so dense clusters never overlap into mush.
struct StopDotMarker: View {
    let model: StopMarkerModel
    let isSelected: Bool
    let showsNumber: Bool

    private var fill: Color {
        switch model.state {
        case .current: return AppTheme.heritageGreen
        case .upcoming: return AppTheme.heritageGreen
        case .visited: return AppTheme.visited
        }
    }

    private var diameter: CGFloat {
        if isSelected { return showsNumber ? 44 : 30 }
        return showsNumber ? 40 : 14
    }

    var body: some View {
        ZStack {
            if isSelected {
                Circle().fill(AppTheme.brass.opacity(0.28)).frame(width: diameter + 12, height: diameter + 12)
            }
            Circle()
                .fill(fill)
                .frame(width: diameter, height: diameter)
                .overlay(Circle().strokeBorder(isSelected ? AppTheme.brass : .white, lineWidth: isSelected ? 3 : 2))
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            if showsNumber || isSelected {
                Group {
                    if model.state == .visited {
                        Image(systemName: "checkmark").font(.system(size: isSelected ? 20 : 18, weight: .bold))
                    } else {
                        Text("\(model.order)").font(.system(size: isSelected ? 20 : 18, weight: .bold, design: .rounded))
                    }
                }
                .foregroundStyle(model.state == .visited ? Color(light: .white, dark: AppTheme.forest) : .white)
            }
        }
        .frame(width: 56, height: 56)
    }
}

// MARK: - Marker artwork (rendered to images via ImageRenderer)

/// Numbered pin with the stop name underneath so names are visible without tapping (spec §4).
struct StopMarkerLabel: View {
    let model: StopMarkerModel

    private var fill: Color {
        switch model.state {
        case .current: return AppTheme.heritageGreen
        case .upcoming: return AppTheme.brass
        case .visited: return AppTheme.visited
        }
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(model.name)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.thinMaterial, in: Capsule())
                .foregroundStyle(.primary)
            ZStack {
                PinShape()
                    .fill(fill)
                    .frame(width: model.state == .current ? 34 : 28, height: model.state == .current ? 44 : 36)
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                Group {
                    if model.state == .visited {
                        Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                    } else {
                        Text("\(model.order)").font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                }
                .foregroundStyle(.white)
                .offset(y: model.state == .current ? -7 : -6)
            }
        }
        .padding(4)
    }
}

/// Teardrop pin.
struct PinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = rect.width / 2
        let center = CGPoint(x: rect.midX, y: rect.minY + r)
        p.addArc(center: center, radius: r, startAngle: .degrees(150), endAngle: .degrees(30), clockwise: false)
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.maxX - r * 0.1, y: rect.minY + r * 1.9))
        p.addQuadCurve(to: CGPoint(x: center.x - r * cos(.pi / 6), y: center.y + r * sin(.pi / 6)), control: CGPoint(x: rect.minX + r * 0.1, y: rect.minY + r * 1.9))
        p.closeSubpath()
        return p
    }
}

/// Blue dot with an optional heading cone; the image is rotated by the marker's `rotation`.
struct UserPuckView: View {
    let hasHeading: Bool
    let isSimulated: Bool

    var body: some View {
        ZStack {
            if hasHeading {
                HeadingCone()
                    .fill(LinearGradient(colors: [Color.blue.opacity(0.45), Color.blue.opacity(0)], startPoint: .bottom, endPoint: .top))
                    .frame(width: 56, height: 56)
                    .offset(y: -22)
            }
            Circle().fill(.white).frame(width: 24, height: 24).shadow(radius: 2)
            Circle().fill(isSimulated ? AppTheme.warning : Color.blue).frame(width: 16, height: 16)
        }
        .frame(width: 72, height: 72)
    }
}

struct HeadingCone: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.3))
        p.closeSubpath()
        return p
    }
}

// MARK: - Map styling

enum MapStyle {
    /// Muted, archival look so markers and the route stand out (spec §13). Not a copy of any product's style.
    static func style(for scheme: ColorScheme) -> GMSMapStyle? {
        try? GMSMapStyle(jsonString: scheme == .dark ? darkJSON : lightJSON)
    }

    private static let lightJSON = """
    [
      {"elementType":"geometry","stylers":[{"color":"#ECE8DF"}]},
      {"elementType":"labels.text.fill","stylers":[{"color":"#304639"}]},
      {"elementType":"labels.text.stroke","stylers":[{"color":"#F7F4EF"}]},
      {"featureType":"poi","stylers":[{"visibility":"off"}]},
      {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#CCD7BF"},{"visibility":"on"}]},
      {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
      {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#E2DDD3"}]},
      {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
      {"featureType":"transit","stylers":[{"visibility":"simplified"}]},
      {"featureType":"water","elementType":"geometry","stylers":[{"color":"#A5CBDA"}]}
    ]
    """

    private static let darkJSON = """
    [
      {"elementType":"geometry","stylers":[{"color":"#1d2820"}]},
      {"elementType":"labels.text.fill","stylers":[{"color":"#D9C9B2"}]},
      {"elementType":"labels.text.stroke","stylers":[{"color":"#1d2820"}]},
      {"featureType":"poi","stylers":[{"visibility":"off"}]},
      {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#1f2a25"},{"visibility":"on"}]},
      {"featureType":"road","elementType":"geometry","stylers":[{"color":"#354436"}]},
      {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#182119"}]},
      {"featureType":"transit","stylers":[{"visibility":"simplified"}]},
      {"featureType":"water","elementType":"geometry","stylers":[{"color":"#15222a"}]}
    ]
    """
}
