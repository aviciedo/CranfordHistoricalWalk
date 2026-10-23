import SwiftUI
import TourCore

struct HomeView: View {
    @Environment(TourViewModel.self) private var tour
    @Environment(AppNavigation.self) private var navigation
    @State private var isShowingDeveloperControls = false
    @ScaledMetric(relativeTo: .body) private var homeContentReserve: CGFloat = 220

    var body: some View {
        GeometryReader { viewport in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Cranford Uncovered")
                        .font(.system(.largeTitle, design: .serif).weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .modifier(DebugMenuGesture(isPresented: $isShowingDeveloperControls))
                    #if DEVELOPER_MENU
                    Button {
                        isShowingDeveloperControls = true
                    } label: {
                        Label("Developer", systemImage: "wrench.and.screwdriver")
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.medium))
                    .accessibilityHint("Opens testing tools and live GPS coordinates")
                    #endif
                    HomeMapView().frame(height: mapHeight(in: viewport.size.height))
                    if let destination = tour.currentStop {
                        Text("Next: \(destination.name)").font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                    Button {
                        if tour.phase == .complete { tour.resetTour() }
                        tour.startTour()
                        navigation.selectedTab = .map
                    } label: {
                        Label(tour.phase == .inProgress ? "Continue your walk" : (tour.phase == .complete ? "Walk it again" : "Start a walk"), systemImage: "figure.walk")
                            .frame(maxWidth: .infinity).padding(.vertical, 17)
                    }
                    .buttonStyle(.plain).font(.headline)
                    .foregroundStyle(AppTheme.ivory)
                    .background(AppTheme.forest, in: RoundedRectangle(cornerRadius: 14))
                    .disabled(tour.loadState != .loaded)
                    .opacity(tour.loadState == .loaded ? 1 : 0.5)

                    Button { navigation.selectedTab = .stops } label: {
                        HStack {
                            Text("Explore the stops")
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        }
                        .frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).font(.subheadline.weight(.medium))
                    .accessibilityHint("Listen, read and view photographs without starting a walk or enabling location")

                    if case .failed(let message) = tour.loadState {
                        Text(message).font(.footnote).foregroundStyle(AppTheme.warning)
                        Button("Try again") { Task { await tour.loadStopsIfNeeded() } }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
        .background(AppTheme.ivory.ignoresSafeArea(edges: .top)).foregroundStyle(AppTheme.ink)
        .task {
            if tour.isWalkingActive && tour.locationAuthorization == .authorized { tour.startLocationIfPossible() }
        }
    }

    private func mapHeight(in availableHeight: CGFloat) -> CGFloat {
        // RootView already removes the shared player/navigation from this viewport. Reserve
        // space for the title and actions. Let the map use the remaining height; short
        // screens and larger text stay scrollable without compressing touch targets.
        #if DEVELOPER_MENU
        let reserved = homeContentReserve + 60 // Developer's 44-point target plus its gap.
        #else
        let reserved = homeContentReserve
        #endif
        return max(240, min(520, availableHeight - reserved - (tour.currentStop == nil ? 0 : 36)))
    }
}

private struct DebugMenuGesture: ViewModifier {
    @Environment(AppNavigation.self) private var navigation
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        #if DEVELOPER_MENU
        content
            .onLongPressGesture(minimumDuration: 1.2) { isPresented = true }
            .onChange(of: navigation.homeReturnID) { _, _ in isPresented = false }
            .sheet(isPresented: $isPresented) {
                DeveloperControlsView()
                    .presentationDetents([.large])
            }
        #else
        content
        #endif
    }
}

/// Offline illustrated map. Streets and landmark drawings are decorative, not navigation data.
struct StylizedCranfordMapView: View {
    let stops: [HistoricalStop]
    @State private var zoom: CGFloat = 1
    @State private var pan = CGSize.zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var drag = CGSize.zero
    @State private var selectedStop: HistoricalStop?
    @State private var isShowingStopName = false

    private let ink = AppTheme.ink
    private let paper = AppTheme.parchment

    var body: some View {
        GeometryReader { proxy in
            let transform = IllustratedMapTransform(
                scale: zoom * pinch,
                offset: CGSize(width: pan.width + drag.width, height: pan.height + drag.height),
                size: proxy.size
            )
            ZStack {
                paper
                Canvas { context, size in
                    context.translateBy(x: size.width / 2 + transform.offset.width, y: size.height / 2 + transform.offset.height)
                    context.scaleBy(x: transform.scale, y: transform.scale)
                    context.translateBy(x: -size.width / 2, y: -size.height / 2)
                    drawStreets(in: &context, size: size)
                    drawRiver(in: &context, size: size)
                    drawTour(in: &context, size: size)
                    for stop in stops {
                        drawLandmark(for: stop, in: &context, size: size)
                    }
                }
                .allowsHitTesting(false)

                // Match the painted illustration bounds, including transparent gaps. Number
                // buttons are layered above these targets so overlapping taps stay predictable.
                ForEach(stops) { stop in
                    let bounds = landmarkBounds(for: stop, size: proxy.size)
                    Button {
                        selectedStop = stop
                        isShowingStopName = true
                    } label: {
                        Color.clear
                            .frame(width: max(44, bounds.width * transform.scale),
                                   height: max(44, bounds.height * transform.scale))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHidden(true) // The numbered control names the same action.
                    .position(transform.project(CGPoint(x: bounds.midX, y: bounds.midY), in: proxy.size))
                }

                ForEach(stops.sorted { $0.order < $1.order }) { stop in
                    Button {
                        selectedStop = stop
                        isShowingStopName = true
                    } label: {
                        Text("\(stop.order)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(AppTheme.heritageGreen, in: Circle())
                            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                            .padding(5)
                            .background(AppTheme.brass.opacity(0.25), in: Circle())
                            .frame(width: 56, height: 56)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Stop \(stop.order), \(stop.name)")
                    .accessibilityHint("Opens the stop popup")
                    .position(transform.project(point(for: stop, size: proxy.size), in: proxy.size))
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                MagnificationGesture()
                    .updating($pinch) { value, state, _ in state = value }
                    .onEnded { value in
                        let next = IllustratedMapTransform(scale: zoom * value, offset: pan, size: proxy.size)
                        zoom = next.scale
                        pan = next.offset
                    }
                    .simultaneously(with:
                        DragGesture(minimumDistance: 8)
                            .updating($drag) { value, state, _ in state = value.translation }
                            .onEnded { value in
                                let next = IllustratedMapTransform(
                                    scale: zoom,
                                    offset: CGSize(width: pan.width + value.translation.width, height: pan.height + value.translation.height),
                                    size: proxy.size
                                )
                                pan = next.offset
                            }
                    )
            )
            .overlay(alignment: .topTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { zoom = 1; pan = .zero }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(ink)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reset illustrated map zoom")
                .padding(10)
            }
            .overlay(alignment: .bottom) {
                Text("Schematic streets · Pinch to zoom · Tap a stop")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(paper.opacity(0.94), in: Capsule())
                    .padding(8)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(AppTheme.brass.opacity(0.4), lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
        }
        .alert(selectedStop?.name ?? "Historical stop", isPresented: $isShowingStopName) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(selectedStop?.markerInformation ?? "")
        }
    }

    private func point(for stop: HistoricalStop, size: CGSize) -> CGPoint {
        IllustratedMapProjection.point(for: stop.coordinate, among: stops.map(\.coordinate), size: size)
    }

    private func drawStreets(in context: inout GraphicsContext, size: CGSize) {
        // An engraving-style street grid, deliberately schematic rather than a surveyed street map.
        for column in 0..<6 {
            for row in 0..<6 {
                let block = CGRect(x: CGFloat(column) * size.width / 5 + 9,
                                   y: CGFloat(row) * size.height / 5 + 9,
                                   width: size.width / 5 - 18, height: size.height / 5 - 18)
                guard block.width > 0, block.height > 0 else { continue }
                let shape = Path(roundedRect: block, cornerRadius: 5)
                context.fill(shape, with: .color(Color(red: 0.64, green: 0.67, blue: 0.46).opacity(0.12)))
                context.stroke(shape, with: .color(ink.opacity(0.06)), lineWidth: 1)
            }
        }
        var streets = Path()
        for index in 0...5 {
            let x = CGFloat(index) * size.width / 5
            streets.move(to: CGPoint(x: x - 10, y: 0))
            streets.addLine(to: CGPoint(x: x + 10, y: size.height))
            let y = CGFloat(index) * size.height / 5
            streets.move(to: CGPoint(x: 0, y: y + 8))
            streets.addLine(to: CGPoint(x: size.width, y: y - 8))
        }
        streets.move(to: CGPoint(x: 0, y: size.height * 0.8))
        streets.addLine(to: CGPoint(x: size.width, y: size.height * 0.25))
        context.stroke(streets, with: .color(ink.opacity(0.18)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        context.stroke(streets, with: .color(Color(red: 0.99, green: 0.96, blue: 0.86)), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
    }

    private func drawRiver(in context: inout GraphicsContext, size: CGSize) {
        var river = Path()
        river.move(to: CGPoint(x: size.width * 0.06, y: -10))
        river.addCurve(to: CGPoint(x: size.width * 0.96, y: size.height + 10),
                       control1: CGPoint(x: size.width * 0.65, y: size.height * 0.18),
                       control2: CGPoint(x: size.width * 0.25, y: size.height * 0.82))
        context.stroke(river, with: .color(Color(red: 0.44, green: 0.60, blue: 0.62).opacity(0.55)), style: StrokeStyle(lineWidth: 12, lineCap: .round))
        context.stroke(river, with: .color(.white.opacity(0.2)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }

    private func drawTour(in context: inout GraphicsContext, size: CGSize) {
        var route = Path()
        for (index, stop) in stops.sorted(by: { $0.order < $1.order }).enumerated() {
            if index == 0 { route.move(to: point(for: stop, size: size)) }
            else { route.addLine(to: point(for: stop, size: size)) }
        }
        context.stroke(route, with: .color(AppTheme.heritageGreen.opacity(0.5)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 5]))
    }

    private func landmarkBounds(for stop: HistoricalStop, size: CGSize) -> CGRect {
        let center = point(for: stop, size: size)
        if stop.id == "hpab-001" || stop.id == "hpab-002" {
            return CGRect(x: center.x - 15, y: center.y - 60, width: 90, height: 67.5)
        }
        let x = center.x + (stop.order.isMultiple(of: 2) ? -22 : 22)
        return CGRect(x: x - 22, y: center.y - 64, width: 46, height: 54)
    }

    private func drawLandmark(for stop: HistoricalStop, in context: inout GraphicsContext, size: CGSize) {
        if stop.id == "hpab-001" || stop.id == "hpab-002" {
            let assetName = stop.id == "hpab-001" ? "mill-map-landmark" : "greystone-map-landmark"
            context.draw(Image(assetName), in: landmarkBounds(for: stop, size: size))
            return
        }
        // Decorative architectural sketches, not reconstructions of the historic buildings.
        let location = point(for: stop, size: size)
        var sketch = context
        sketch.translateBy(x: location.x + (stop.order.isMultiple(of: 2) ? -22 : 22), y: location.y - 30)
        sketch.scaleBy(x: 0.62, y: 0.62)
        let color = ink.opacity(0.8)
        var outline = Path()
        if stop.id == "hpab-003" {
            // River bridge with stone piers and an arch.
            outline.move(to: CGPoint(x: -30, y: 0))
            outline.addLine(to: CGPoint(x: 30, y: 0))
            outline.move(to: CGPoint(x: -30, y: 6))
            outline.addLine(to: CGPoint(x: 30, y: 6))
            outline.addLine(to: CGPoint(x: 30, y: 25))
            outline.addLine(to: CGPoint(x: 17, y: 25))
            outline.addQuadCurve(to: CGPoint(x: -17, y: 25), control: CGPoint(x: 0, y: -7))
            outline.addLine(to: CGPoint(x: -30, y: 25))
            outline.closeSubpath()
            for x in stride(from: -24, through: 24, by: 12) {
                    outline.move(to: CGPoint(x: CGFloat(x), y: -7))
                    outline.addLine(to: CGPoint(x: CGFloat(x), y: 0))
            }
        } else {
            let width: CGFloat = stop.id == "hpab-004" ? 30 : 48
            outline.addRect(CGRect(x: -width / 2, y: -4, width: width, height: 30))
            outline.move(to: CGPoint(x: -width / 2 - 5, y: -4))
            outline.addLine(to: CGPoint(x: 0, y: -24))
            outline.addLine(to: CGPoint(x: width / 2 + 5, y: -4))
            outline.closeSubpath()
            outline.addRect(CGRect(x: -4, y: 12, width: 8, height: 14))
            for x in [CGFloat(-14), CGFloat(10)] {
                outline.addRect(CGRect(x: x, y: 2, width: 5, height: 6))
            }
            if stop.id == "hpab-001" {
                // Mill waterwheel and spokes.
                outline.addEllipse(in: CGRect(x: 16, y: 4, width: 26, height: 26))
                outline.addEllipse(in: CGRect(x: 20, y: 8, width: 18, height: 18))
                for index in 0..<8 {
                    let angle = Double(index) * .pi / 4
                    outline.move(to: CGPoint(x: 29, y: 17))
                    outline.addLine(to: CGPoint(x: 29 + cos(angle) * 12, y: 17 + sin(angle) * 12))
                }
            } else if stop.id == "hpab-004" {
                // Church steeple and cross.
                outline.addRect(CGRect(x: -5, y: -31, width: 10, height: 17))
                outline.move(to: CGPoint(x: -7, y: -31))
                outline.addLine(to: CGPoint(x: 0, y: -44))
                outline.addLine(to: CGPoint(x: 7, y: -31))
                outline.closeSubpath()
                outline.move(to: CGPoint(x: 0, y: -53))
                outline.addLine(to: CGPoint(x: 0, y: -43))
                outline.move(to: CGPoint(x: -4, y: -49))
                outline.addLine(to: CGPoint(x: 4, y: -49))
            } else if stop.id == "hpab-002" {
                // Manor chimneys.
                outline.addRect(CGRect(x: -17, y: -25, width: 5, height: 12))
                outline.addRect(CGRect(x: 12, y: -25, width: 5, height: 12))
            } else {
                // Hotel balcony and upper-floor windows.
                outline.move(to: CGPoint(x: -25, y: 11))
                outline.addLine(to: CGPoint(x: 25, y: 11))
                for x in stride(from: -20, through: 20, by: 10) {
                    outline.move(to: CGPoint(x: CGFloat(x), y: 8))
                    outline.addLine(to: CGPoint(x: CGFloat(x), y: 14))
                }
            }
        }
        sketch.fill(outline, with: .color(paper.opacity(0.7)))
        sketch.stroke(outline, with: .color(color), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
        var ground = Path()
        ground.move(to: CGPoint(x: -34, y: 29))
        ground.addLine(to: CGPoint(x: 37, y: 29))
        sketch.stroke(ground, with: .color(ink.opacity(0.35)), lineWidth: 1)
    }
}

/// Keeps pinch zoom and pan within the map's bounds. Shared by drawing and real marker buttons.
struct IllustratedMapTransform {
    let scale: CGFloat
    let offset: CGSize

    init(scale: CGFloat, offset: CGSize, size: CGSize) {
        let scale = min(max(scale.isFinite ? scale : 1, 1), 4)
        self.scale = scale
        let limitX = max(size.width, 0) * (scale - 1) / 2
        let limitY = max(size.height, 0) * (scale - 1) / 2
        self.offset = CGSize(width: min(max(offset.width.isFinite ? offset.width : 0, -limitX), limitX),
                             height: min(max(offset.height.isFinite ? offset.height : 0, -limitY), limitY))
    }

    func project(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: (point.x - size.width / 2) * scale + size.width / 2 + offset.width,
                y: (point.y - size.height / 2) * scale + size.height / 2 + offset.height)
    }
}

/// Fits the stop coordinates in the illustration without claiming the decorative streets are geographic.
enum IllustratedMapProjection {
    static func point(for coordinate: GeoCoordinate, among coordinates: [GeoCoordinate], size: CGSize) -> CGPoint {
        guard let minLat = coordinates.map(\.latitude).min(), let maxLat = coordinates.map(\.latitude).max(),
              let minLng = coordinates.map(\.longitude).min(), let maxLng = coordinates.map(\.longitude).max() else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }
        let longitudeSpan = max(maxLng - minLng, 0.002)
        let latitudeSpan = max(maxLat - minLat, 0.002)
        let width = max(size.width - 88, 0)
        let height = max(size.height - 128, 0)
        return CGPoint(x: size.width / 2 + CGFloat((coordinate.longitude - (minLng + maxLng) / 2) / longitudeSpan) * width,
                       y: size.height / 2 - CGFloat((coordinate.latitude - (minLat + maxLat) / 2) / latitudeSpan) * height)
    }
}

#Preview {
    let deps = AppDependencies.preview()
    return HomeView()
        .environment(deps)
        .environment(deps.tourViewModel)
        .environment(AppNavigation())
}
