import SwiftUI
import TourCore

/// Browsing, reading and playback never select a walking destination.
struct StopDetailView: View {
    @Environment(TourViewModel.self) private var tour
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.dismiss) private var dismiss
    let initialStop: HistoricalStop
    private let allowsPlaqueActions: Bool
    init(stop: HistoricalStop, allowsPlaqueActions: Bool = true) {
        initialStop = stop
        self.allowsPlaqueActions = allowsPlaqueActions
    }
    // A scanner can identify another supported plaque. Return to that site's actual story.
    @State private var discoveredStop: HistoricalStop?
    private var stop: HistoricalStop { discoveredStop ?? initialStop }
    @State private var sketchbookPresentation: SketchbookPresentation?
    @State private var isShowingScanner = false
    @State private var scannerHasPresented = false
    @State private var isStopDetailsExpanded = true

    @State private var isShowingStory = false
    private var script: String { stop.narrationText ?? "" }
    private var hasStopDetails: Bool { !stop.longDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var hasStoryScript: Bool { !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private func openPlaqueActivity() {
        guard allowsPlaqueActions else { return }
        if tour.activities[stop.id].plaqueUnlockedAt != nil {
            sketchbookPresentation = SketchbookPresentation(stopID: stop.id, animated: false)
            return
        }
        openPlaqueScanner()
    }

    private func openPlaqueScanner() {
        guard allowsPlaqueActions, tour.preparePlaqueScanner(stopID: stop.id) else { return }
        scannerHasPresented = true
        isShowingScanner = true
    }

    var body: some View {
        NavigationStack {
            GeometryReader { viewport in
                VStack(spacing: 0) {
                    returnControl
                    // Size from the full-width host, not the height left after playback opens.
                    storyContent(galleryHeight: min(280, max(180, (viewport.size.width - 40) * 0.52)))
                    SharedNarrationBar(availableHeight: viewport.size.height)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .background(AppTheme.ivory.ignoresSafeArea()).foregroundStyle(AppTheme.forest)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $isShowingStory) { StopStoryReader(stop: stop) }
            .fullScreenCover(isPresented: $isShowingScanner, onDismiss: { scannerHasPresented = false; revealNewSketch() }) { PlaqueScannerView(stopID: stop.id) }
            .fullScreenCover(item: $sketchbookPresentation) { presentation in
                SketchbookView(initialStopID: presentation.stopID, animatedSketchStopID: presentation.animated ? presentation.stopID : nil)
                    // Each opening starts at the requested stop, not a previously browsed page.
                    .id(presentation.id)
            }
            .onAppear { tour.openStory(for: stop.id); if !scannerHasPresented { revealNewSketch() } }
        }
        .onChange(of: navigation.homeReturnID) { _, _ in
            tour.pendingSketchStopID = nil
            isShowingScanner = false
            isShowingStory = false
            sketchbookPresentation = nil
        }
        .onChange(of: stop.id) { _, _ in
            isStopDetailsExpanded = true
            isShowingStory = false
        }
        .dismissOnReturnHome()
        .holdsWalkingContext()
        .environment(\.colorScheme, .light)
    }

    private func revealNewSketch() {
        guard !isShowingScanner, sketchbookPresentation == nil,
              let id = tour.takeUnlockedSketch(), let found = tour.stop(withID: id) else { return }
        discoveredStop = found
        sketchbookPresentation = SketchbookPresentation(stopID: id, animated: true)
    }

    private var returnControl: some View {
        ScreenReturnBar(onBack: { dismiss() })
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 4)
    }

    private func storyContent(galleryHeight: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(stop.name)
                        .font(.system(.largeTitle, design: .serif).weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    StopPhotoGallery(stop: stop, height: galleryHeight,
                                     isObscured: isShowingScanner || sketchbookPresentation != nil)
                    VStack(alignment: .leading, spacing: 8) {
                        if let date = stop.displayDate {
                            Text(date).font(.subheadline).foregroundStyle(AppTheme.secondaryInk)
                        }
                        Label(stop.address, systemImage: "mappin.and.ellipse")
                            .font(.subheadline).foregroundStyle(AppTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                // Keep the primary and secondary actions stacked with a closer shared gap.
                if stop.narrationSource != nil || (stop.hasPlaqueReference && allowsPlaqueActions) {
                    VStack(alignment: .leading, spacing: 12) {
                        if stop.narrationSource != nil {
                            VStack(alignment: .leading, spacing: 8) {
                                NarrationControls(stop: stop)
                                if tour.activities[stop.id].learningCompleted {
                                    Label(learningStatus, systemImage: "checkmark.circle")
                                        .font(.footnote).foregroundStyle(AppTheme.secondaryInk)
                                }
                            }
                        }
                        if stop.hasPlaqueReference && allowsPlaqueActions {
                            VStack(alignment: .leading, spacing: 12) {
                                Button(action: openPlaqueActivity) {
                                    HStack(spacing: 12) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "camera")
                                                .font(.title2)
                                            Text(tour.activities[stop.id].plaqueUnlockedAt == nil ? "Find on-site plaque" : "View sketch")
                                                .font(.headline)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .frame(maxWidth: .infinity)
                                        Image(systemName: "chevron.right")
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 14)
                                    .frame(maxWidth: .infinity, minHeight: 56)
                                    .foregroundStyle(AppTheme.forest)
                                    .background(AppTheme.ivory, in: RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(AppTheme.forest.opacity(0.35), lineWidth: 1))
                                    .contentShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("stop.findPlaque")
                                if allowsPlaqueActions && tour.activities[stop.id].plaqueUnlockedAt != nil {
                                    Button(action: openPlaqueScanner) {
                                        Label("View plaque in AR", systemImage: "viewfinder")
                                            .font(.subheadline.weight(.semibold))
                                            .frame(maxWidth: .infinity, minHeight: 44)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(AppTheme.forest)
                                    .accessibilityIdentifier("stop.viewPlaqueAR")
                                    .accessibilityHint("Scan this plaque again to view its anchored historical card")
                                }
                            }
                        }
                    }
                }
                if hasStopDetails || hasStoryScript || (stop.hasPlaqueReference && allowsPlaqueActions) {
                    // Related detail, story and sketch rows share dividers without
                    // inheriting the larger gap between major page sections.
                    VStack(alignment: .leading, spacing: 0) {
                        if hasStopDetails {
                            Divider()
                            DisclosureGroup(isExpanded: $isStopDetailsExpanded) {
                                Text(stop.longDescription)
                                    .font(.body).lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } label: {
                                Text("Stop details")
                            }
                            .disclosureGroupStyle(StopDetailsDisclosureStyle(title: "Stop details"))
                            .tint(AppTheme.forest)
                        }
                        if hasStoryScript {
                            Divider()
                            Button { isShowingStory = true } label: {
                                AppMenuRowLabel(title: "Read the story", symbol: "book",
                                                titleFont: .system(.headline, design: .serif))
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens the full narration text without starting audio or changing your walk")
                            .accessibilityIdentifier("stop.readStory")
                        }
                        if stop.hasPlaqueReference && allowsPlaqueActions {
                            SketchCollectionRow(stop: stop,
                                             isCollected: tour.activities[stop.id].plaqueUnlockedAt != nil) {
                                sketchbookPresentation = SketchbookPresentation(stopID: stop.id, animated: false)
                            }
                        } else {
                            Divider()
                        }
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 24)
        }
    }

    private var learningStatus: String {
        let activity = tour.activities[stop.id]
        if activity.listenedAt != nil && activity.readAt != nil { return "Listened and read" }
        return activity.listenedAt != nil ? "Listened" : "Read"
    }
}


/// A focused reading destination. Opening it never starts narration or records a visit.
private struct StopStoryReader: View {
    @Environment(TourViewModel.self) private var tour
    @Environment(\.dismiss) private var dismiss
    let stop: HistoricalStop

    var body: some View {
        GeometryReader { viewport in
            VStack(spacing: 0) {
                ScreenReturnBar(onBack: { dismiss() })
                    .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 8)
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Read the story")
                            .font(.system(.largeTitle, design: .serif).weight(.semibold))
                            .accessibilityAddTraits(.isHeader)
                        Text(stop.name).font(AppTheme.Fonts.title)
                        Text(stop.narrationText ?? "")
                            .font(.body).lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                        if tour.activities[stop.id].readAt == nil {
                            Button("I've read the narration") { tour.finishStory(for: stop.id) }
                                .font(.headline).frame(minHeight: 44)
                                .accessibilityHint("Marks only reading complete; it does not record a visit or change your walk")
                                .accessibilityIdentifier("story.markRead")
                        } else {
                            Label("Read", systemImage: "checkmark.circle").font(.subheadline)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20).padding(.bottom, 24)
                }
                SharedNarrationBar(availableHeight: viewport.size.height)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .background(AppTheme.ivory.ignoresSafeArea()).foregroundStyle(AppTheme.forest)
        .toolbar(.hidden, for: .navigationBar)
        .dismissOnReturnHome()
        .holdsWalkingContext()
        .accessibilityIdentifier("stop.storyReader")
    }
}
