import SwiftUI
import TourCore

struct StopsView: View {
    var body: some View {
        NavigationStack {
            StopsContent()
                .navigationTitle("The stops")
                .toolbarBackground(AppTheme.parchment, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

struct StopsContent: View {
    @Environment(TourViewModel.self) private var tour
    @State private var detailStop: HistoricalStop?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(tour.stops) { stop in
                    Button { detailStop = stop } label: {
                        HStack(spacing: 14) {
                            StopListIllustration(stopID: stop.id)
                                .frame(width: 82, height: 76)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Stop \(stop.order)").font(.subheadline).foregroundStyle(AppTheme.secondaryInk)
                                Text(stop.name).font(.system(.title3, design: .serif).weight(.semibold))
                                if let visit = tour.lastRecordedVisit(for: stop) {
                                    Label("\(visit.evidence == .recognizedPlaque ? "Plaque verified" : "Visited") \(visit.activatedAt.formatted(date: .abbreviated, time: .omitted))", systemImage: "checkmark.circle.fill")
                                        .font(.caption).foregroundStyle(AppTheme.visited)
                                } else if tour.isCompleted(stop) {
                                    Label(stop.hasPlaqueReference ? "Story completed · No saved plaque verification" : "Practice visit", systemImage: "checkmark.circle")
                                        .font(.caption).foregroundStyle(AppTheme.secondaryInk)
                                } else if stop.id == tour.currentStop?.id {
                                    Text("Next on your walk").font(.caption).foregroundStyle(AppTheme.secondaryInk)
                                }
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right").font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Stop \(stop.order), \(stop.name), details and narration")
                    .padding(.vertical, 20)
                    Divider()
                }
            }
            .padding(.horizontal, 24)
        }
        .background(AppTheme.parchment).foregroundStyle(AppTheme.ink)
        .sheet(item: $detailStop) { HistoricalSignSheet(stop: $0) }
    }
}

/// Transparent decorative thumbnails. The remaining stops use symbolic artwork until
/// their own reference photographs are supplied, rather than invented reconstructions.
private struct StopListIllustration: View {
    let stopID: String

    var body: some View {
        Group {
            switch stopID {
            case "hpab-001":
                Image("mill-map-landmark").resizable().scaledToFit()
            case "hpab-002":
                Image("greystone-map-landmark").resizable().scaledToFit()
            default:
                Canvas { context, size in
                    context.scaleBy(x: size.width / 100, y: size.height / 90)
                    if stopID == "hpab-003" {
                        drawRiver(in: &context)
                    } else {
                        drawBuilding(in: &context, isChurch: stopID == "hpab-004")
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func drawRiver(in context: inout GraphicsContext) {
        var river = Path()
        river.move(to: CGPoint(x: 35, y: 13))
        river.addCurve(to: CGPoint(x: 49, y: 77), control1: CGPoint(x: 97, y: 28), control2: CGPoint(x: 4, y: 53))
        context.stroke(river, with: .color(Color(red: 0.39, green: 0.62, blue: 0.68)),
                       style: StrokeStyle(lineWidth: 23, lineCap: .round))
        for y in [28.0, 43.0, 60.0] {
            var ripple = Path()
            ripple.move(to: CGPoint(x: 37, y: y))
            ripple.addQuadCurve(to: CGPoint(x: 59, y: y + 2), control: CGPoint(x: 49, y: y - 4))
            context.stroke(ripple, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
        }
        for stone in [CGRect(x: 22, y: 59, width: 13, height: 8), CGRect(x: 66, y: 31, width: 14, height: 9), CGRect(x: 61, y: 70, width: 11, height: 7)] {
            context.fill(Path(ellipseIn: stone), with: .color(Color(red: 0.65, green: 0.61, blue: 0.51)))
        }
        for tree in [CGPoint(x: 18, y: 30), CGPoint(x: 82, y: 61)] {
            context.fill(Path(roundedRect: CGRect(x: tree.x - 1.5, y: tree.y, width: 3, height: 13), cornerRadius: 1), with: .color(.brown))
            context.fill(Path(ellipseIn: CGRect(x: tree.x - 10, y: tree.y - 14, width: 20, height: 24)), with: .color(Color(red: 0.40, green: 0.52, blue: 0.35)))
        }
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
