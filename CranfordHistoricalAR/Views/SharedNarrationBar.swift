import SwiftUI
import TourCore

/// Uses the existing single player. Switching tabs never prepares or restarts a recording.
struct SharedNarrationBar: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(TourViewModel.self) private var tour
    @State private var detailStop: HistoricalStop?

    private var stop: HistoricalStop? {
        if let id = dependencies.narrationPlayer.stopID, let playing = tour.stop(withID: id) { return playing }
        return tour.currentStop
    }

    var body: some View {
        if let stop, stop.narrationSource != nil {
            HStack(spacing: 14) {
                NarrationPlayButton(stop: stop)
                VStack(alignment: .leading, spacing: 2) {
                    Button { detailStop = stop } label: {
                        Text(stop.name).font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open details for \(stop.name)")
                    NarrationTimeline(stop: stop)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
            .background(AppTheme.playerSurface)
            .foregroundStyle(AppTheme.ink)
            .sheet(item: $detailStop) { HistoricalSignSheet(stop: $0) }
        }
    }
}

struct NarrationPlayButton: View {
    @Environment(AppDependencies.self) private var dependencies
    let stop: HistoricalStop

    var body: some View {
        let player = dependencies.narrationPlayer
        let isCurrent = player.stopID == stop.id
        Button {
            if player.stopID == stop.id, case .failed = player.status { player.stop() }
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
            .frame(width: 50, height: 50)
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
    @State private var scrubProgress: Double?

    var body: some View {
        let player = dependencies.narrationPlayer
        let isCurrent = player.stopID == stop.id
        let canSeek = isCurrent && player.canSeek
        VStack(spacing: 0) {
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
