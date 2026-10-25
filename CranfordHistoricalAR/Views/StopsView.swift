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
                                    StopListIllustration(stopID: stop.id)
                                        .aspectRatio(stop.id == "hpab-004" ? 1 : stop.id == "hpab-005" ? 100.0 / 90.0 : 4.0 / 3.0,
                                                     contentMode: .fit)
                                        .frame(width: 104, height: 88, alignment: .trailing)
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

    /// The list shows earned place accomplishments only; reading and availability
    /// remain on the detail page and never imply a physical visit or bonus discovery.
    private func statusLabels(for stop: HistoricalStop) -> [String] {
        var labels: [String] = []
        if tour.activities[stop.id].visitedAt != nil || tour.isCompleted(stop) { labels.append("Visited") }
        if tour.activities[stop.id].bonusFoundAt != nil { labels.append("On-site bonus unlocked") }
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

/// Transparent landmark thumbnails. Stop 4 follows the supplied First Baptist Church photograph.
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
                FirstBaptistChurchThumbnail()
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

    
/// Photo-informed, transparent architectural artwork for First Baptist Church.
/// Canvas is intentionally unfilled so the ivory Stops page shows through.
private struct FirstBaptistChurchThumbnail: View {
    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 100, y: size.height / 100)
            let outline = Color(red: 0.30, green: 0.37, blue: 0.34)
            let siding = Color(red: 0.95, green: 0.94, blue: 0.89)
            let trim = Color(red: 0.82, green: 0.82, blue: 0.75)
            let brick = Color(red: 0.63, green: 0.35, blue: 0.28)
            let glass = Color(red: 0.31, green: 0.47, blue: 0.56)
            let foliage = Color(red: 0.44, green: 0.52, blue: 0.36)

            func polygon(_ points: [CGPoint], fill: Color, stroke: Color = .clear) {
                var p = Path()
                guard let first = points.first else { return }
                p.move(to: first)
                for point in points.dropFirst() { p.addLine(to: point) }
                p.closeSubpath()
                context.fill(p, with: .color(fill))
                if stroke != .clear { context.stroke(p, with: .color(stroke), lineWidth: 1.1) }
            }
            // Building silhouette, characteristic front-facing steep gable and right chimney.
            context.fill(Path(CGRect(x: 79, y: 26, width: 8, height: 56)), with: .color(brick))
            polygon([CGPoint(x: 7,y: 47),CGPoint(x: 50,y: 21),
                     CGPoint(x: 94,y: 47),CGPoint(x: 90,y: 85),CGPoint(x: 10,y: 85)],
                    fill: siding, stroke: outline)
            polygon([CGPoint(x: 5,y: 48),CGPoint(x: 50,y: 19),CGPoint(x: 95,y: 48),
                     CGPoint(x: 90,y: 48),CGPoint(x: 50,y: 25),CGPoint(x: 11,y: 48)],
                    fill: trim, stroke: outline)
            // Central tower and open bell cupola.
            context.fill(Path(CGRect(x: 39, y: 18, width: 22, height: 58)), with: .color(siding))
            context.stroke(Path(CGRect(x: 39, y: 18, width: 22, height: 58)), with: .color(outline), lineWidth: 1.2)
            context.fill(Path(CGRect(x: 37, y: 8, width: 26, height: 13)), with: .color(siding))
            context.stroke(Path(CGRect(x: 37, y: 8, width: 26, height: 13)), with: .color(outline), lineWidth: 1.3)
            polygon([CGPoint(x: 35,y: 8),CGPoint(x: 50,y: 0),CGPoint(x: 65,y: 8)], fill: outline)
            for x in stride(from: 41.0, through: 59.0, by: 6.0) {
                context.fill(Path(CGRect(x: x, y: 10, width: 1.3, height: 10)), with: .color(outline.opacity(0.8)))
            }
            // Horizontal clapboard lines on the tower.
            for y in stride(from: 27.0, through: 54.0, by: 4.0) {
                var line = Path(); line.move(to: CGPoint(x: 40,y: y)); line.addLine(to: CGPoint(x: 60,y: y))
                context.stroke(line, with: .color(trim), lineWidth: 0.7)
            }
            // Rose window and the two taller arched stained-glass windows.
            context.fill(Path(ellipseIn: CGRect(x: 45, y: 31, width: 10, height: 10)), with: .color(glass))
            context.stroke(Path(ellipseIn: CGRect(x: 45, y: 31, width: 10, height: 10)), with: .color(outline), lineWidth: 1.2)
            for x in [19.0, 71.0] {
                context.fill(Path(roundedRect: CGRect(x: x, y: 52, width: 11, height: 25), cornerRadius: 5.5), with: .color(glass))
                context.stroke(Path(roundedRect: CGRect(x: x, y: 52, width: 11, height: 25), cornerRadius: 5.5), with: .color(outline), lineWidth: 1.4)
                var cross = Path();cross.move(to: CGPoint(x:x+5.5,y:54));cross.addLine(to: CGPoint(x:x+5.5,y:76))
                cross.move(to: CGPoint(x:x+1,y:65));cross.addLine(to: CGPoint(x:x+10,y:65))
                context.stroke(cross, with: .color(trim), lineWidth: 0.9)
            }
            // Entrance, wood doors and brick steps.
            context.fill(Path(CGRect(x: 42, y: 61, width: 16, height: 24)), with: .color(brick))
            context.stroke(Path(CGRect(x: 42, y: 61, width: 16, height: 24)), with: .color(outline), lineWidth: 1)
            var seam = Path();seam.move(to: CGPoint(x:50,y:62));seam.addLine(to: CGPoint(x:50,y:85))
            context.stroke(seam, with: .color(trim), lineWidth: 1)
            for (i,w) in [23.0,28.0,33.0].enumerated() {
                context.fill(Path(CGRect(x: 50-w/2,y: 84+Double(i)*3,width:w,height:2.2)), with: .color(brick))
            }
            // Foreground lettering board and shrubs match the field photograph's silhouette.
            for x in [10.0, 85.0] {
                context.fill(Path(ellipseIn: CGRect(x:x,y:80,width:18,height:14)), with: .color(foliage))
            }
            context.fill(Path(roundedRect: CGRect(x: 37, y: 78, width: 38, height: 20), cornerRadius: 2), with: .color(brick))
            context.fill(Path(roundedRect: CGRect(x: 39, y: 80, width: 34, height: 14), cornerRadius: 1), with: .color(siding))
            context.stroke(Path(roundedRect: CGRect(x: 39, y: 80, width: 34, height: 14), cornerRadius: 1), with: .color(outline), lineWidth: 1.2)
            for y in [83.0, 86.0, 89.0] {
                context.fill(Path(CGRect(x: 43, y: y, width: 26, height: 1)), with: .color(outline.opacity(0.8)))
            }
        }
        .accessibilityLabel("Illustration of First Baptist Church")
    }
}
