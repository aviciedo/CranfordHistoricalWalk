import SwiftUI
import TourCore

/// Browsing never retargets the tour. AR entry guides to the first/current destination.
struct StopDetailView: View {
    @Environment(TourViewModel.self) private var tour
    @Environment(AppNavigation.self) private var navigation
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    let stop: HistoricalStop
    var onContinue: (() -> Void)? = nil
    var onStartDiscovery: (() -> Void)? = nil
    var onEnterAR: (() -> Void)? = nil
    @State private var isShowingAR = false
    @State private var isNarrationExpanded = true
    @State private var isDescriptionExpanded = false

    private var isCurrent: Bool { tour.phase == .inProgress && tour.currentStop?.id == stop.id }

    private var stopDescription: String { stop.screenDescription }

    private func enterAR() {
        guard tour.prepareForARFromDetails() else { return }
        if dependencies.narrationPlayer.isPlaying { dependencies.narrationPlayer.pause() }
        let shouldDiscover = tour.currentStop?.id == stop.id && stop.hasPlaqueReference
            && tour.discovery.hasFinishedStory
        if shouldDiscover, let onStartDiscovery {
            onStartDiscovery()
            dismiss()
        } else if let onEnterAR {
            // The detail sheet is already over the camera: return to that session.
            onEnterAR()
            dismiss()
        } else {
            if shouldDiscover { _ = tour.beginPlaqueDiscovery() }
            isShowingAR = true
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    StopPhotoGallery(stop: stop, isObscured: isShowingAR)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Stop \(stop.order) of \(tour.stops.count)")
                            .font(.subheadline).foregroundStyle(AppTheme.secondaryInk)
                        Text(stop.name).font(.system(.largeTitle, design: .serif).weight(.semibold))
                        if let date = stop.displayDate {
                            Text(date).font(.title3).foregroundStyle(AppTheme.secondaryInk)
                        }
                        Label(stop.address, systemImage: "mappin.and.ellipse")
                            .font(.subheadline).foregroundStyle(AppTheme.secondaryInk)
                    }
                    HStack(spacing: 12) {
                        Button {
                            navigation.showOnMap(stopID: stop.id)
                            dismiss()
                        } label: {
                            Label("Show on map", systemImage: "map")
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(.plain)
                        .background(AppTheme.playerSurface, in: RoundedRectangle(cornerRadius: 12))
                        Button(action: enterAR) {
                            Label(tour.phase == .complete ? "Start new walk in AR" : "Start AR", systemImage: "camera.viewfinder")
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(.plain).foregroundStyle(AppTheme.ivory)
                        .background(AppTheme.forest, in: RoundedRectangle(cornerRadius: 12))
                        .disabled(tour.loadState != .loaded)
                        .accessibilityHint("Opens the camera with walking directions. On-site plaque discovery is available after listening or reading.")
                    }
                    .font(.subheadline.weight(.semibold))
                    if stop.narrationSource != nil {
                        DisclosureGroup("Narration player", isExpanded: $isNarrationExpanded) {
                            NarrationControls(stop: stop).padding(.top, 12)
                        }
                        .font(.subheadline.weight(.medium))
                    }
                    if isCurrent && stop.hasPlaqueReference && tour.discovery.hasArrived {
                        Text("Pause in a permitted viewing area before listening. The arrival location is approximate until it is confirmed on site.")
                            .font(.footnote).foregroundStyle(AppTheme.secondaryInk)
                    }
                    if isCurrent && stop.hasPlaqueReference {
                        if tour.discovery.hasFinishedStory {
                            if !tour.discovery.hasVerifiedPlaque {
                                Text("Tap Start AR to find the plaque and unlock an optional on-site extra. Stay outside and keep the entrance clear.")
                                    .font(.footnote).foregroundStyle(AppTheme.secondaryInk)
                            }
                        } else {
                            Text("Start the narration, or read the story below. Afterwards, discover an optional on-site AR bonus.")
                                .font(.subheadline).foregroundStyle(AppTheme.secondaryInk)
                        }
                    }
                    if !stopDescription.isEmpty {
                        DisclosureGroup("Stop description", isExpanded: $isDescriptionExpanded) {
                            Text(stopDescription).font(.body).lineSpacing(5)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 12)
                        }
                        .font(.subheadline.weight(.medium))
                    }
                    if let script = stop.narrationText, !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        DisclosureGroup("Read narration") {
                            Text(script).font(.body).lineSpacing(5)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 12)
                        }
                        .font(.subheadline.weight(.medium))
                    }
                    if let visit = tour.lastRecordedVisit(for: stop) {
                        Label {
                            Text("\(visit.evidence == .recognizedPlaque ? "Plaque verified" : "Visited") \(visit.activatedAt.formatted(date: .abbreviated, time: .omitted))")
                        } icon: { Image(systemName: "checkmark.circle.fill") }
                        .font(.subheadline).foregroundStyle(AppTheme.visited)
                    }
                    if isCurrent && stop.hasPlaqueReference && !tour.discovery.hasFinishedStory {
                        Button("I've read the story") { tour.finishStory(for: stop.id) }
                            .font(.body.weight(.medium)).frame(minHeight: 44)
                    }
                    if isCurrent && tour.canContinueCurrentStop {
                        Button {
                            tour.completeCurrentStopAndAdvance()
                            navigation.selectedTab = .map
                            dismiss()
                            onContinue?()
                        } label: {
                            Label(tour.nextStop == nil ? "Finish tour" : "Continue to next stop", systemImage: "arrow.right")
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.plain).font(.body.weight(.medium))
                        Divider()
                    }
                    DisclosureGroup("About this stop") {
                        VStack(alignment: .leading, spacing: 10) {
                            if let plaque = stop.plaque, plaque.isUsable {
                                Text("\(plaque.quoteLabel): “\(plaque.transcription)”")
                                Text("The plaque inscription is separate from the building’s construction history above.")
                            }
                            if stop.coordinatesUnverified {
                                Text("The map position is approximate. GPS accuracy can vary at the site.")
                            }
                            if stop.isSample { Text("Sample content — not verified history.") }
                            if let status = tour.dataStatus { Text(status) }
                        }
                        .font(.footnote).foregroundStyle(AppTheme.secondaryInk).padding(.top, 8)
                    }
                    .font(.subheadline)
                }
                .padding(24)
            }
            .background(AppTheme.parchment).foregroundStyle(AppTheme.ink)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 19, weight: .medium))
                            .foregroundStyle(AppTheme.forest)
                            .frame(width: 46, height: 46)
                            .background(.white, in: Circle())
                            .contentShape(Circle())
                            .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close stop details")
                    Spacer()
                }
                .padding(.horizontal, 24).padding(.vertical, 8)
                .background(AppTheme.parchment)
            }
            .fullScreenCover(isPresented: $isShowingAR, onDismiss: { dismiss() }) { ARTourView() }
            .onAppear { if isCurrent { tour.openStory(for: stop.id) } }
            .onChange(of: dependencies.narrationPlayer.status) { _, status in
                if dependencies.narrationPlayer.stopID == stop.id && status == .finished {
                    tour.finishStory(for: stop.id)
                }
            }
        }
    }
}
