import SwiftUI
import TourCore

/// Browsing, reading and playback never select a walking destination.
struct StopDetailView: View {
    @Environment(TourViewModel.self) private var tour
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.dismiss) private var dismiss
    let stop: HistoricalStop
    var onStartDiscovery: (() -> Void)? = nil
    @State private var isShowingScanner = false
    @State private var isShowingBonus = false

    // Each newly opened stop starts on Listen; switching to Read never touches playback.
    @State private var mode: AppNavigation.StoryMode = .listen
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
        } else { isShowingScanner = true }
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
            .fullScreenCover(isPresented: $isShowingScanner) { PlaqueScannerView(stopID: stop.id) }
            .sheet(isPresented: $isShowingBonus) { OnSiteBonusPreview(stop: stop) }
            .onAppear { tour.openStory(for: stop.id) }
        }
        .onChange(of: navigation.homeReturnID) { _, _ in
            isShowingScanner = false
            isShowingBonus = false
        }
        .dismissOnReturnHome()
        .holdsWalkingContext()
        .environment(\.colorScheme, .light)
    }

    private var returnControl: some View {
        ScreenReturnBar(onBack: { dismiss() })
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 4)
    }

    private func storyContent(galleryHeight: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 20) {
                    StopPhotoGallery(stop: stop, height: galleryHeight,
                                     isObscured: isShowingScanner || isShowingBonus)
                    Text(stop.name)
                        .font(.system(.largeTitle, design: .serif).weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Enjoy the story", selection: $mode) {
                        ForEach(AppNavigation.StoryMode.allCases, id: \.self) { value in
                            Text(value.rawValue).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("stop.storyMode")
                    if mode == .listen {
                        if stop.narrationSource == nil {
                            Label("Narration coming soon", systemImage: "headphones")
                                .font(.headline).padding(.vertical, 12)
                            Text("You can explore the history and photographs below.")
                                .font(.subheadline).foregroundStyle(AppTheme.secondaryInk)
                        } else {
                            NarrationControls(stop: stop)
                        }
                    } else {
                        if script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("A full reading story is not available yet. Explore the history and photographs below.")
                                .font(.body).foregroundStyle(AppTheme.secondaryInk)
                        } else {
                            Text(script).font(.body).lineSpacing(5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if tour.activities[stop.id].readAt == nil {
                                Button("I've read the narration") {
                                    tour.finishStory(for: stop.id)
                                }
                                .frame(minHeight: 44)
                                .accessibilityHint("Marks only reading complete; it does not record a visit or change your walk")
                            }
                        }
                    }
                    if tour.activities[stop.id].learningCompleted {
                        Label(learningStatus, systemImage: "checkmark.circle")
                            .font(.footnote).foregroundStyle(AppTheme.secondaryInk)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(stop.longDescription).font(.body).fixedSize(horizontal: false, vertical: true)
                    if let date = stop.displayDate {
                        Text(date).font(.subheadline).foregroundStyle(AppTheme.secondaryInk)
                    }
                    Label(stop.address, systemImage: "mappin.and.ellipse")
                        .font(.subheadline).foregroundStyle(AppTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        navigation.showOnMap(stopID: stop.id)
                        dismiss()
                    } label: {
                        Label("Show on map", systemImage: "map").frame(minHeight: 44)
                    }.buttonStyle(.plain)
                }
                if stop.hasPlaqueReference {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()
                        Button(action: openPlaqueActivity) {
                            HStack(spacing: 12) {
                                Image(systemName: "camera.viewfinder")
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tour.activities[stop.id].bonusFoundAt == nil ? "Find the plaque in AR" : "View the bonus")
                                    Text("Optional bonus · On-site only").font(.footnote).foregroundStyle(AppTheme.secondaryInk)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .frame(minHeight: 52).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if tour.activities[stop.id].bonusFoundAt != nil {
                            Label("Bonus found", systemImage: "seal.fill")
                                .font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.forest)
                                .accessibilityIdentifier("stop.bonusFound")
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
