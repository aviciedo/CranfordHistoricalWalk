import SwiftUI
import TourCore

struct StopsView: View {
    var body: some View {
        NavigationStack {
            StopsContent()
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct StopsContent: View {
    @Environment(AppNavigation.self) private var navigation
    @Environment(TourViewModel.self) private var tour
    @State private var detailStop: HistoricalStop?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenPageHeader(onBack: { navigation.goBack() }) {
                Text("Stops")
            }
            GeometryReader { viewport in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(tour.stops) { stop in
                            Button { detailStop = stop } label: {
                                HStack(spacing: 10) {
                                    StopCollectionIllustration(stopID: stop.id,
                                        isSketchUnlocked: tour.activities[stop.id].plaqueUnlockedAt != nil)
                                        // Center every silhouette in the same column, including portrait artwork.
                                        .frame(width: 104, height: stop.id == "hpab-004" ? 104 : 88, alignment: .center)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(stop.name).font(.system(.title3, design: .serif).weight(.semibold))
                                            .fixedSize(horizontal: false, vertical: true)
                                        ForEach(statusLabels(for: stop), id: \.self) { status in
                                            Text(status).font(.caption).foregroundStyle(AppTheme.secondaryInk)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: "chevron.right").font(.subheadline)
                                }
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, minHeight: rowHeight(in: viewport.size.height), alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel((["Stop \(stop.order)", stop.name] + statusLabels(for: stop)).joined(separator: ", "))
                            .accessibilityHint("Opens stop details")
                            Divider()
                        }
                    }
                    .padding(.horizontal, 24).padding(.bottom, 8)
                }
            }
        }
        .background(AppTheme.ivory.ignoresSafeArea(edges: .top)).foregroundStyle(AppTheme.ink)
        .sheet(item: $detailStop) { HistoricalSignSheet(stop: $0) }
        .onChange(of: navigation.pendingStopReturn) { _, _ in restoreStopReturn() }
        .onAppear { restoreStopReturn() }
        .onChange(of: navigation.homeReturnID) { _, _ in detailStop = nil }
    }

    /// Visit is the only text status; artwork reflects the independent sketch unlock.
    private func statusLabels(for stop: HistoricalStop) -> [String] {
        var labels: [String] = []
        if tour.activities[stop.id].visitedAt != nil || tour.isCompleted(stop) { labels.append("Visited") }
        return labels
    }

    private func restoreStopReturn() {
        if let id = navigation.takeStopReturn(for: .stops) { detailStop = tour.stop(withID: id) }
    }

    private func rowHeight(in availableHeight: CGFloat) -> CGFloat {
        let count = max(tour.stops.count, 1)
        // This viewport already excludes the actual header, player and navigation. Text may grow beyond
        // this minimum; the list stays scrollable at larger accessibility sizes.
        return max(100, (availableHeight - 8 - CGFloat(count)) / CGFloat(count))
    }
}

/// Stops-list-only artwork. Physical visits alone never paint an undiscovered sketch.
struct StopCollectionIllustration: View {
    let stopID: String
    let isSketchUnlocked: Bool

    static func assetName(for stopID: String, isSketchUnlocked: Bool) -> String? {
        if isSketchUnlocked, let watercolor = SketchArtwork.assetName(for: stopID) { return watercolor }
        switch stopID {
        case "hpab-001": return "stop-ink-mill"
        case "hpab-002": return "stop-ink-greystone"
        case "hpab-003": return "stop-ink-river"
        case "hpab-004": return "stop-ink-church"
        case "hpab-005": return "stop-ink-hotel"
        default: return nil
        }
    }

    var body: some View {
        Group {
            if let asset = Self.assetName(for: stopID, isSketchUnlocked: isSketchUnlocked) {
                Image(asset).renderingMode(.original).resizable().scaledToFit()
            } else {
                StopListIllustration(stopID: stopID).saturation(0)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Original-color landmark cutouts; the church painting follows the owner’s field photograph.
struct StopListIllustration: View {
    let stopID: String

    var body: some View {
        Group {
            switch stopID {
            case "hpab-001":
                Image("mill-map-landmark").renderingMode(.original).resizable().scaledToFit()
            case "hpab-002":
                Image("greystone-map-landmark").renderingMode(.original).resizable().scaledToFit()
            case "hpab-003":
                Image("rahway-river-illustration").renderingMode(.original).resizable().scaledToFit()
            case "hpab-004":
                Image("first-baptist-church-illustration").renderingMode(.original).resizable().scaledToFit()
            default:
                Canvas { context, size in
                    context.scaleBy(x: size.width / 100, y: size.height / 90)
                    drawBuilding(in: &context, isChurch: stopID == "hpab-004")
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func drawBuilding(in context: inout GraphicsContext, isChurch: Bool) {
        let wall = Color(red: 0.76, green: 0.68, blue: 0.53)
        let roof = Color(red: 0.57, green: 0.30, blue: 0.22)
        let trim = Color(red: 0.26, green: 0.33, blue: 0.27)
        let body = CGRect(x: 16, y: 36, width: 68, height: 43)
        context.fill(Path(body), with: .color(wall))
        context.stroke(Path(body), with: .color(trim.opacity(0.7)), lineWidth: 1)
        var roofPath = Path()
        roofPath.move(to: CGPoint(x: 10, y: 37))
        roofPath.addLine(to: CGPoint(x: 50, y: isChurch ? 16 : 23))
        roofPath.addLine(to: CGPoint(x: 90, y: 37))
        roofPath.closeSubpath()
        context.fill(roofPath, with: .color(roof))
        if isChurch {
            context.fill(Path(CGRect(x: 44, y: 18, width: 12, height: 17)), with: .color(wall))
            var spire = Path()
            spire.move(to: CGPoint(x: 41, y: 19))
            spire.addLine(to: CGPoint(x: 50, y: 3))
            spire.addLine(to: CGPoint(x: 59, y: 19))
            spire.closeSubpath()
            context.fill(spire, with: .color(trim))
            context.fill(Path(ellipseIn: CGRect(x: 45, y: 44, width: 10, height: 10)), with: .color(trim))
        }
        for x in [25.0, 65.0] {
            for y in (isChurch ? [46.0] : [44.0, 60.0]) {
                let window = CGRect(x: x, y: y, width: 10, height: 13)
                context.fill(Path(roundedRect: window, cornerRadius: isChurch ? 5 : 1), with: .color(trim))
                context.fill(Path(CGRect(x: x + 4.5, y: y + 1, width: 1, height: 11)), with: .color(wall))
            }
        }
        context.fill(Path(roundedRect: CGRect(x: 43, y: 61, width: 14, height: 18), cornerRadius: 2), with: .color(trim))
        if !isChurch {
            context.fill(Path(CGRect(x: 12, y: 56, width: 76, height: 3)), with: .color(roof))
        }
        context.fill(Path(roundedRect: CGRect(x: 11, y: 79, width: 78, height: 3), cornerRadius: 1.5), with: .color(wall))
        for x in [13.0, 80.0] {
            context.fill(Path(ellipseIn: CGRect(x: x - 5, y: 70, width: 14, height: 11)), with: .color(Color(red: 0.40, green: 0.52, blue: 0.35)))
        }
    }
}
