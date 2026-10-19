import SwiftUI
import TourCore

/// Uses the existing single player. Switching tabs never prepares or restarts a recording.
struct SharedNarrationBar: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(TourViewModel.self) private var tour
    @Environment(AppNavigation.self) private var navigation
    @State private var detailStop: HistoricalStop?

    private var stop: HistoricalStop? {
        if let id = dependencies.narrationPlayer.stopID, let playing = tour.stop(withID: id) { return playing }
        return tour.currentStop
    }

    var body: some View {
        if let stop, stop.narrationSource != nil {
            VStack(spacing: 0) {
                Button { navigation.isNarrationMinimized.toggle() } label: {
                    Capsule()
                        .fill(AppTheme.secondaryInk.opacity(0.6))
                        .frame(width: 36, height: 4)
                        .frame(maxWidth: .infinity, minHeight: navigation.isNarrationMinimized ? 12 : 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(navigation.isNarrationMinimized ? "Expand player" : "Minimize player")
                .accessibilityHint("Tap to toggle the player size, or drag down to minimize and up to expand")
                HStack(spacing: 14) {
                    NarrationPlayButton(stop: stop, diameter: navigation.isNarrationMinimized ? 44 : 46)
                    Button {
                        if navigation.isNarrationMinimized { navigation.isNarrationMinimized = false }
                        else { detailStop = stop }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(stop.name).font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(1)
                            if !navigation.isNarrationMinimized {
                                NarrationTimeline(stop: stop, compact: true)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(navigation.isNarrationMinimized
                        ? "Expand player for \(stop.name)" : "Open details and narration controls for \(stop.name)")
                    .accessibilityValue(playbackValue(for: stop))
                    .accessibilityHint(navigation.isNarrationMinimized
                        ? "Shows playback progress and times" : "Opens the full player and stop information")
                    if navigation.isNarrationMinimized {
                        Image(systemName: "chevron.up").font(.caption.weight(.semibold))
                            .accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, navigation.isNarrationMinimized ? 0 : 10)
            }
            .background(AppTheme.playerSurface)
            .foregroundStyle(AppTheme.ink)
            .simultaneousGesture(
                DragGesture(minimumDistance: 16).onEnded { value in
                    guard abs(value.translation.height) > abs(value.translation.width) else { return }
                    if value.translation.height > 20 { navigation.isNarrationMinimized = true }
                    else if value.translation.height < -20 { navigation.isNarrationMinimized = false }
                }
            )
            .sheet(item: $detailStop) { HistoricalSignSheet(stop: $0) }
        }
    }

    private func playbackValue(for stop: HistoricalStop) -> String {
        let player = dependencies.narrationPlayer
        guard player.stopID == stop.id else { return "Not started" }
        if case .failed = player.status { return "Unable to play" }
        if player.status == .loading { return "Loading" }
        let progress = player.progress.isFinite ? min(1, max(0, player.progress)) : 0
        return "\(Int(progress * 100)) percent played"
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
                        .font(.title3.weight(.semibold))
                }
            }
            .frame(width: diameter, height: diameter)
            .foregroundStyle(AppTheme.ivory)
            .background(AppTheme.terracotta, in: Circle())
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
                .tint(AppTheme.terracotta)
                .disabled(!canSeek)
                .accessibilityLabel("Narration position for \(stop.name)")
            } else {
                ProgressView(value: isCurrent ? player.progress : 0)
                    .tint(AppTheme.terracotta).padding(.vertical, compact ? 4 : 6)
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
