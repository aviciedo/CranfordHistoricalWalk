import SwiftUI
import TourCore

/// Transport is always bound to the playing story, never the walking destination.
struct SharedNarrationBar: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(TourViewModel.self) private var tour
    @State private var isExpanded = false

    var body: some View {
        let player = dependencies.narrationPlayer
        if player.hasStartedPlayback, let id = player.stopID,
           let stop = tour.stop(withID: id) {
            HStack(spacing: 12) {
                NarrationPlayButton(stop: stop, diameter: 44)
                Button { isExpanded = true } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(stop.name).font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                        NarrationTimeline(stop: stop, compact: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Expand player for \(stop.name)")
                Button { isExpanded = true } label: {
                    Image(systemName: "chevron.up").frame(width: 44, height: 44)
                }
                .buttonStyle(.plain).accessibilityLabel("Expand audio player")
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .accessibilityIdentifier("narration.compactPlayer")
            .foregroundStyle(AppTheme.forest).background(AppTheme.ivory)
            .overlay(alignment: .top) { Divider() }
            .sheet(isPresented: $isExpanded) {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            Text(stop.name).font(.system(.title, design: .serif).weight(.semibold))
                            NarrationControls(stop: stop)
                            HStack {
                                Button { player.skip(by: -15) } label: {
                                    Label("Back 15 seconds", systemImage: "gobackward.15").frame(minHeight: 44)
                                }
                                Spacer()
                                Button { player.skip(by: 15) } label: {
                                    Label("Forward 15 seconds", systemImage: "goforward.15").frame(minHeight: 44)
                                }
                            }
                            .disabled(!player.canSeek)
                        }
                        .padding(24)
                    }
                    .background(AppTheme.ivory)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Back") { isExpanded = false }
                        }
                    }
                }
                .environment(\.colorScheme, .light)
                .presentationDetents([.medium, .large])
            }
        }
    }
}

struct NarrationPlayButton: View {
    @Environment(AppDependencies.self) private var dependencies
    let stop: HistoricalStop
    var diameter: CGFloat = 50

    var body: some View {
        let player = dependencies.narrationPlayer
        let isCurrent = player.stopID == stop.id
        Button {
            guard player.prepare(stop) else { return }
            player.togglePlayPause()
        } label: {
            Group {
                if isCurrent && player.status == .loading {
                    ProgressView().tint(AppTheme.ivory)
                } else {
                    Image(systemName: isCurrent && player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: diameter * 0.43, weight: .bold))
                }
            }
            .frame(width: diameter, height: diameter)
            .foregroundStyle(AppTheme.ivory)
            .background(AppTheme.forest, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCurrent && player.isPlaying ? "Pause narration" : "Play narration for \(stop.name)")
        .accessibilityValue(isCurrent && player.status == .loading ? "Loading" : "")
    }
}

struct NarrationTimeline: View {
    @Environment(AppDependencies.self) private var dependencies
    let stop: HistoricalStop
    /// The persistent strip uses a thin progress rail; expanded recorded-audio controls retain seeking.
    var compact = false
    @State private var scrubProgress: Double?

    var body: some View {
        let player = dependencies.narrationPlayer
        let isCurrent = player.stopID == stop.id
        let canSeek = isCurrent && player.canSeek
        VStack(spacing: 0) {
            if stop.hasRecordedNarration && !compact {
                Slider(value: Binding(
                    get: { scrubProgress ?? (isCurrent ? player.progress : 0) },
                    set: { scrubProgress = $0 }
                ), in: 0...1, onEditingChanged: { editing in
                    if !editing {
                        if let progress = scrubProgress, let duration = player.duration, canSeek {
                            player.seek(to: progress * duration)
                        }
                        scrubProgress = nil
                    }
                })
                .tint(AppTheme.forest)
                .disabled(!canSeek)
                .accessibilityLabel("Narration position for \(stop.name)")
            } else {
                ProgressView(value: isCurrent ? player.progress : 0)
                    .tint(AppTheme.forest).padding(.vertical, compact ? 4 : 6)
                    .accessibilityLabel("Narration progress for \(stop.name)")
            }
            HStack {
                Text(time(isCurrent ? (scrubProgress.map { $0 * (player.duration ?? 0) } ?? player.elapsed) : 0))
                Spacer()
                if isCurrent, case .failed = player.status {
                    Text("Unable to play").foregroundStyle(AppTheme.warning)
                } else if isCurrent && player.status == .loading {
                    Text("Loading…")
                } else {
                    Text(isCurrent ? player.duration.map(time) ?? "—" : "—")
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(AppTheme.secondaryInk)
        }
        .onChange(of: player.stopID) { _, _ in scrubProgress = nil }
    }

    private func time(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "—" }
        let value = max(0, Int(seconds))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}
