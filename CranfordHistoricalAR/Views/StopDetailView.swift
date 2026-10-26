import SwiftUI
import TourCore

/// Browsing, reading and playback never select a walking destination.
struct StopDetailView: View {
    @Environment(TourViewModel.self) private var tour
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.dismiss) private var dismiss
    let initialStop: HistoricalStop
    init(stop: HistoricalStop, onStartDiscovery: (() -> Void)? = nil) {
        initialStop = stop
        self.onStartDiscovery = onStartDiscovery
    }
    // A scanner can identify another supported plaque. Return to that site's actual story.
    @State private var discoveredStop: HistoricalStop?
    private var stop: HistoricalStop { discoveredStop ?? initialStop }
    @State private var passportPresentation: PassportPresentation?
    var onStartDiscovery: (() -> Void)? = nil
    @State private var isShowingScanner = false
    @State private var scannerHasPresented = false
    @State private var isShowingBonus = false
    @State private var isStopDetailsExpanded = true

    @State private var isShowingStory = false
    private var script: String { stop.narrationText ?? "" }
    private func openPlaqueActivity() {
        if tour.activities[stop.id].bonusFoundAt != nil {
            isShowingBonus = true
            return
        }
        guard tour.preparePlaqueScanner(stopID: stop.id) else { return }
        if let onStartDiscovery, stop.hasPlaqueReference {
            onStartDiscovery()
            dismiss()
        } else { scannerHasPresented = true; isShowingScanner = true }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { viewport in
                VStack(spacing: 0) {
                    returnControl
                    // Size from the full-width host, not the height left after playback opens.
                    storyContent(galleryHeight: min(340, max(220, (viewport.size.width - 40) * 0.75)))
                    SharedNarrationBar(availableHeight: viewport.size.height)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .background(AppTheme.ivory.ignoresSafeArea()).foregroundStyle(AppTheme.forest)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $isShowingStory) { StopStoryReader(stop: stop) }
            .fullScreenCover(isPresented: $isShowingScanner, onDismiss: { scannerHasPresented = false; revealNewStamp() }) { PlaqueScannerView(stopID: stop.id) }
            .fullScreenCover(item: $passportPresentation) { presentation in
                PassportView(initialStopID: presentation.stopID, animatedStampStopID: presentation.animated ? presentation.stopID : nil)
            }
            .sheet(isPresented: $isShowingBonus) { OnSiteBonusPreview(stop: stop) }
            .onAppear { tour.openStory(for: stop.id); if !scannerHasPresented { revealNewStamp() } }
        }
        .onChange(of: navigation.homeReturnID) { _, _ in
            tour.pendingPassportStampStopID = nil
            isShowingScanner = false
            isShowingBonus = false
            isShowingStory = false
            passportPresentation = nil
        }
        .onChange(of: stop.id) { _, _ in
            isStopDetailsExpanded = true
            isShowingStory = false
        }
        .dismissOnReturnHome()
        .holdsWalkingContext()
        .environment(\.colorScheme, .light)
    }

    private func revealNewStamp() {
        guard !isShowingScanner, passportPresentation == nil,
              let id = tour.takePassportStamp(), let found = tour.stop(withID: id) else { return }
        discoveredStop = found
        passportPresentation = PassportPresentation(stopID: id, animated: true)
    }

    private var returnControl: some View {
        ScreenReturnBar(onBack: { dismiss() })
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 4)
    }

    private func storyContent(galleryHeight: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    StopPhotoGallery(stop: stop, height: galleryHeight,
                                     isObscured: isShowingScanner || isShowingBonus || passportPresentation != nil)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(stop.name)
                            .font(.system(.largeTitle, design: .serif).weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        if let date = stop.displayDate {
                            Text(date).font(.subheadline).foregroundStyle(AppTheme.secondaryInk)
                        }
                        Label(stop.address, systemImage: "mappin.and.ellipse")
                            .font(.subheadline).foregroundStyle(AppTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if stop.narrationSource != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        NarrationControls(stop: stop)
                        if tour.activities[stop.id].learningCompleted {
                            Label(learningStatus, systemImage: "checkmark.circle")
                                .font(.footnote).foregroundStyle(AppTheme.secondaryInk)
                        }
                    }
                }
                if stop.hasPlaqueReference {
                    VStack(alignment: .leading, spacing: 12) {
                        Button(action: openPlaqueActivity) {
                            HStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    Image(systemName: "camera")
                                        .font(.title2)
                                    Text(tour.activities[stop.id].bonusFoundAt == nil ? "Find on-site plaque with AR" : "View the bonus")
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
                        if tour.activities[stop.id].bonusFoundAt != nil {
                            PassportStampRow(stop: stop, collectedCount: tour.passportCollectedCount,
                                             totalCount: tour.passportStops.count) {
                                passportPresentation = PassportPresentation(stopID: stop.id, animated: false)
                            }
                        }
                    }
                }
                if !stop.longDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Divider()
                    DisclosureGroup(isExpanded: $isStopDetailsExpanded) {
                        Text(stop.longDescription)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    } label: {
                        Label("Stop details", systemImage: "doc.text")
                            .font(.system(.title2, design: .serif).weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .tint(AppTheme.forest)
                    .accessibilityHint("Expands or collapses the stop history")
                    .accessibilityIdentifier("stop.detailsDisclosure")
                }
                if !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Divider()
                    Button { isShowingStory = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "book").font(.title2)
                            Text("Read the story").font(.headline)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right").font(.subheadline.weight(.medium))
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.vertical, 6).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the full narration text without starting audio or changing your walk")
                    .accessibilityIdentifier("stop.readStory")
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
