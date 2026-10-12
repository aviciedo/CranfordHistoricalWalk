import SwiftUI
import TourCore

/// First screen (spec §23).
struct HomeView: View {
    @Environment(TourViewModel.self) private var tour
    @State private var isShowingDeveloperControls = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppTheme.parchment.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .padding(.top, 24)
                        .modifier(DebugMenuGesture(isPresented: $isShowingDeveloperControls))

                    Spacer(minLength: 16)

                    HomeMapView()
                        .frame(height: min(proxy.size.height * 0.46, 420))
                        .padding(.horizontal, 24)
                        .accessibilityLabel("Map of Cranford with \(tour.stops.count) historical stops. Tap a dot to see the stop name.")

                    Spacer(minLength: 16)

                    footer
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            VStack(spacing: -2) {
                Text("CRANFORD")
                    .font(AppTheme.Fonts.display(40))
                    .tracking(6)
                Text("HISTORICAL AR")
                    .font(AppTheme.Fonts.display(24))
                    .tracking(8)
                    .foregroundStyle(AppTheme.brass)
            }
            .foregroundStyle(AppTheme.ink)
            .multilineTextAlignment(.center)

            Text("See the history around you.")
                .font(.system(.title3, design: .serif).italic())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(spacing: 14) {
            if case .failed(let message) = tour.loadState {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.warning)
                    .multilineTextAlignment(.center)
            }

            Button(action: tour.startTour) {
                HStack(spacing: 10) {
                    Image(systemName: "figure.walk")
                    Text("START WALKING TOUR")
                        .tracking(1.5)
                }
                .font(.system(.headline, design: .default).weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(AppTheme.heritageGreen, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .foregroundStyle(.white)
            }
            .disabled(tour.loadState != .loaded)
            .opacity(tour.loadState == .loaded ? 1 : 0.5)

            VStack(spacing: 6) {
                Label("Explore historical sites through augmented reality.", systemImage: "arkit")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                // Caption comes from the tour document (`dataStatus`), never from the view.
                if let status = tour.dataStatus, !status.isEmpty {
                    Text(status)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                ARCoreHomeDisclosure()
                    .padding(.top, 4)
            }
        }
    }
}

/// Debug builds: a long press on the title opens Developer Controls (spec §19 "only accessible
/// through a debug menu"). Compiles to a no-op in Release.
private struct DebugMenuGesture: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        #if DEVELOPER_MENU
        content
            .onLongPressGesture(minimumDuration: 1.2) { isPresented = true }
            .sheet(isPresented: $isPresented) {
                DeveloperControlsView()
                    .presentationDetents([.large])
            }
        #else
        content
        #endif
    }
}

/// An abstract, hand-drawn-feeling map: a river ribbon, a few street strokes and the stops
/// laid out by their real relative coordinates. It is a stylization, not a surveyed map.
struct StylizedCranfordMapView: View {
    let stops: [HistoricalStop]
    static let maxNumberedStops = 12

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(colors: [Color(red: 0.93, green: 0.90, blue: 0.83), Color(red: 0.87, green: 0.83, blue: 0.74)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(AppTheme.brass.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 20, y: 10)

            Canvas { context, size in
                drawStreets(in: &context, size: size)
                drawRiver(in: &context, size: size)
                drawStops(in: &context, size: size)
            }
            .padding(18)

            VStack {
                Spacer()
                HStack {
                    EyebrowText("Cranford, New Jersey", color: AppTheme.ink.opacity(0.6))
                    Spacer()
                    EyebrowText("\(stops.count) stops", color: AppTheme.ink.opacity(0.6))
                }
                .padding(18)
            }
        }
    }

    private func drawStreets(in context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        let rows = 5, cols = 6
        for r in 1..<rows {
            let y = size.height * CGFloat(r) / CGFloat(rows)
            path.move(to: CGPoint(x: 0, y: y + sin(CGFloat(r)) * 6))
            path.addLine(to: CGPoint(x: size.width, y: y - cos(CGFloat(r)) * 6))
        }
        for c in 1..<cols {
            let x = size.width * CGFloat(c) / CGFloat(cols)
            path.move(to: CGPoint(x: x + cos(CGFloat(c)) * 5, y: 0))
            path.addLine(to: CGPoint(x: x - sin(CGFloat(c)) * 5, y: size.height))
        }
        context.stroke(path, with: .color(AppTheme.ink.opacity(0.08)), lineWidth: 1)
    }

    private func drawRiver(in context: inout GraphicsContext, size: CGSize) {
        var river = Path()
        river.move(to: CGPoint(x: size.width * 0.05, y: size.height * 0.15))
        river.addCurve(
            to: CGPoint(x: size.width * 0.95, y: size.height * 0.85),
            control1: CGPoint(x: size.width * 0.45, y: size.height * -0.05),
            control2: CGPoint(x: size.width * 0.55, y: size.height * 1.05)
        )
        context.stroke(river, with: .color(Color(red: 0.55, green: 0.66, blue: 0.70).opacity(0.55)), style: StrokeStyle(lineWidth: 10, lineCap: .round))
    }

    private func drawStops(in context: inout GraphicsContext, size: CGSize) {
        guard !stops.isEmpty else { return }
        let lats = stops.map(\.latitude), lngs = stops.map(\.longitude)
        let minLat = lats.min()!, maxLat = lats.max()!, minLng = lngs.min()!, maxLng = lngs.max()!
        let latSpan = max(maxLat - minLat, 0.002), lngSpan = max(maxLng - minLng, 0.002)
        let inset: CGFloat = 26

        func point(for stop: HistoricalStop) -> CGPoint {
            let x = inset + (CGFloat((stop.longitude - minLng) / lngSpan)) * (size.width - inset * 2)
            let y = inset + (1 - CGFloat((stop.latitude - minLat) / latSpan)) * (size.height - inset * 2)
            return CGPoint(x: x, y: y)
        }

        let ordered = stops.sorted { $0.order < $1.order }
        var route = Path()
        for (i, stop) in ordered.enumerated() {
            if i == 0 {
                route.move(to: point(for: stop))
            } else {
                route.addLine(to: point(for: stop))
            }
        }
        context.stroke(route, with: .color(AppTheme.heritageGreen.opacity(0.5)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [6, 6]))

        // Numbers only while they stay legible; with many stops the dots alone read better.
        let showsNumbers = ordered.count <= StylizedCranfordMapView.maxNumberedStops
        let radius: CGFloat = showsNumbers ? 7 : 5
        for stop in ordered {
            let p = point(for: stop)
            let halo = Path(ellipseIn: CGRect(x: p.x - radius - 6, y: p.y - radius - 6, width: (radius + 6) * 2, height: (radius + 6) * 2))
            context.fill(halo, with: .color(AppTheme.brass.opacity(0.22)))
            let dot = Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2))
            context.fill(dot, with: .color(AppTheme.heritageGreen))
            context.stroke(dot, with: .color(.white), lineWidth: 2)
            if showsNumbers {
                context.draw(
                    Text("\(stop.order)").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundColor(.white),
                    at: p
                )
            }
        }
    }
}

#Preview {
    let deps = AppDependencies.preview()
    return HomeView()
        .environment(deps)
        .environment(deps.tourViewModel)
}
