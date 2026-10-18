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
    var showsCompass = true
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
        private var cameraRetryCount = 0

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
            marker.snippet = nil
            marker.isTappable = true
            marker.groundAnchor = groundAnchor
            marker.zIndex = zIndex(for: model.state, isSelected: isSelected)
            marker.position = model.coordinate
            applyIcon(marker, image: icon(for: model, isSelected: isSelected))
        }

        /// Dot styles use `iconView` so the whole 44 pt control is tappable, not just opaque pixels
        /// of a padded `UIImage`. Labeled pins keep `icon` (the artwork is already the hit box).
        private func applyIcon(_ marker: GMSMarker, image: UIImage?) {
            if markerStyle == .labeledPin {
                marker.iconView = nil
                marker.icon = image
                marker.tracksViewChanges = false
                return
            }
            let side: CGFloat = 44
            let view = UIImageView(image: image)
            view.bounds = CGRect(x: 0, y: 0, width: side, height: side)
            view.contentMode = .center
            view.isUserInteractionEnabled = false
            marker.icon = nil
            marker.tracksViewChanges = true
            marker.iconView = view
            marker.tracksViewChanges = false
        }

        private func syncSelectedMarker(on mapView: GMSMapView, selectedID: String?) {
            if let selectedID, let marker = markersByID[selectedID] {
                if mapView.selectedMarker !== marker {
                    mapView.selectedMarker = marker
                }
            } else if mapView.selectedMarker != nil {
                mapView.selectedMarker = nil
            }
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
            case .dot, .numberedDot:
                renderer = ImageRenderer(content: AnyView(StopDotMarker(model: model, isSelected: isSelected, showsNumber: markerStyle == .numberedDot).environment(\.colorScheme, scheme)))
            }
            renderer.scale = UITraitCollection.current.displayScale
            let image = renderer.uiImage
            iconCache[key] = image
            return image
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
            guard let mapView, let request = cameraRequest, request.id != lastCameraRequestID else { return }
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
                let coordinates = markerModels.values.map(\.coordinate) + (lastPuck.map { [$0.coordinate] } ?? [])
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
                let bounds = GMSCoordinateBounds(coordinate: a, coordinate: b)
                update = GMSCameraUpdate.fit(bounds, with: UIEdgeInsets(top: 110, left: 60, bottom: 60, right: 60))
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
            let position = marker.position
            Task { @MainActor in
                self.ignoreMapTapUntil = Date().addingTimeInterval(0.4)
                if let id { self.parent.onMarkerTap(id) }
                self.mapView?.animate(toLocation: position)
            }
            // Consume the tap so we can show both the SDK info window (via selectedMarker in
            // render) and the SwiftUI callout. Returning false used to race with didTapAt.
            return true
        }

        nonisolated func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            Task { @MainActor in
                if let until = self.ignoreMapTapUntil, Date() < until { return }
                self.parent.onMapTap()
            }
        }

        nonisolated func mapView(_ mapView: GMSMapView, markerInfoWindow marker: GMSMarker) -> UIView? {
            // Maps SDK delegates run on the main thread; UIKit construction is main-actor isolated.
            MainActor.assumeIsolated {
                let title = marker.title ?? ""
                guard !title.isEmpty else { return nil }
                return StopNameInfoWindow(title: title)
            }
        }

        nonisolated func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
            let zoom = position.zoom
            Task { @MainActor in self.parent.onCameraIdle(zoom) }
        }
    }
}

/// In-map popup for a tapped stop. Name only; the SwiftUI `HomeStopCallout` adds address. No logic.
final class StopNameInfoWindow: UIView {
    init(title: String) {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .label
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        let fitting = label.sizeThatFits(CGSize(width: 220, height: 80))
        let width = min(220, max(96, ceil(fitting.width)))
        let height = max(22, ceil(fitting.height))
        super.init(frame: CGRect(x: 0, y: 0, width: width + 24, height: height + 16))
        backgroundColor = UIColor.systemBackground.withAlphaComponent(0.96)
        layer.cornerRadius = 12
        clipsToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 2)
        label.frame = bounds.insetBy(dx: 12, dy: 8)
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(label)
        isUserInteractionEnabled = false
        accessibilityLabel = title
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
        if isSelected { return 30 }
        return showsNumber ? 24 : 14
    }

    var body: some View {
        ZStack {
            if isSelected {
                Circle().fill(AppTheme.brass.opacity(0.28)).frame(width: diameter + 16, height: diameter + 16)
            }
            Circle()
                .fill(fill)
                .frame(width: diameter, height: diameter)
                .overlay(Circle().strokeBorder(isSelected ? AppTheme.brass : .white, lineWidth: isSelected ? 3 : 2))
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            if showsNumber || isSelected {
                Group {
                    if model.state == .visited {
                        Image(systemName: "checkmark").font(.system(size: isSelected ? 13 : 10, weight: .bold))
                    } else {
                        Text("\(model.order)").font(.system(size: isSelected ? 13 : 11, weight: .bold, design: .rounded))
                    }
                }
                .foregroundStyle(.white)
            }
        }
        .frame(width: 48, height: 48)
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
      {"elementType":"geometry","stylers":[{"color":"#f3efe6"}]},
      {"elementType":"labels.text.fill","stylers":[{"color":"#5f5a4f"}]},
      {"elementType":"labels.text.stroke","stylers":[{"color":"#f8f5ee"}]},
      {"featureType":"poi","stylers":[{"visibility":"off"}]},
      {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#dfe6d3"},{"visibility":"on"}]},
      {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
      {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#e2dccd"}]},
      {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#fbf7ee"}]},
      {"featureType":"transit","stylers":[{"visibility":"simplified"}]},
      {"featureType":"water","elementType":"geometry","stylers":[{"color":"#bfd0d6"}]}
    ]
    """

    private static let darkJSON = """
    [
      {"elementType":"geometry","stylers":[{"color":"#1d1f22"}]},
      {"elementType":"labels.text.fill","stylers":[{"color":"#9a9892"}]},
      {"elementType":"labels.text.stroke","stylers":[{"color":"#1d1f22"}]},
      {"featureType":"poi","stylers":[{"visibility":"off"}]},
      {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#1f2a25"},{"visibility":"on"}]},
      {"featureType":"road","elementType":"geometry","stylers":[{"color":"#2c2f33"}]},
      {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#1a1c1f"}]},
      {"featureType":"transit","stylers":[{"visibility":"simplified"}]},
      {"featureType":"water","elementType":"geometry","stylers":[{"color":"#15222a"}]}
    ]
    """
}
