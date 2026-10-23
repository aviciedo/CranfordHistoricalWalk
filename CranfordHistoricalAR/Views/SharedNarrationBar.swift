import SwiftUI
import TourCore

/// Transport is always bound to the playing story, never the walking destination.
struct SharedNarrationBar: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(TourViewModel.self) private var tour

    var body: some View {
        let player = dependencies.narrationPlayer
        if player.isPersistentPlayerVisible, let id = player.stopID,
           let stop = tour.stop(withID: id) {
            HStack(alignment: .center, spacing: 12) {
                NarrationPlayButton(stop: stop, diameter: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(stop.name)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    // Keep seeking in the sole player; no expanded sheet is needed.
                    NarrationTimeline(stop: stop)
                    if case .failed(let message) = player.status {
                        Text(message).font(.footnote).foregroundStyle(AppTheme.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button { player.dismissPersistentPlayer() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close player")
                .accessibilityHint("Pauses narration and saves your position")
                .accessibilityIdentifier("narration.closePlayer")
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .accessibilityIdentifier("narration.persistentPlayer")
            .foregroundStyle(AppTheme.forest).background(AppTheme.ivory)
            .overlay(alignment: .top) { Divider() }
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
    @State private var scrubProgress: Double?

    var body: some View {
        let player = dependencies.narrationPlayer
        let isCurrent = player.stopID == stop.id
        let canSeek = isCurrent && player.canSeek
        VStack(spacing: 0) {
            if stop.hasRecordedNarration {
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
                    .tint(AppTheme.forest).padding(.vertical, 6)
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
