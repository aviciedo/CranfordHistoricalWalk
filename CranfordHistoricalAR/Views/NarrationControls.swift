import SwiftUI
import TourCore

/// Spotify-like transport for a stop's HPAB recording. One `NarrationPlayer` is owned by
/// `AppDependencies`, so home, the stop list, the map sheet, and AR cannot talk over each other.
/// Playback is not gated on GPS — any stop can be started from anywhere.
struct NarrationControls: View {
    @Environment(AppDependencies.self) private var dependencies
    let stop: HistoricalStop
    @State private var isScrubbing = false
    @State private var scrubProgress: Double = 0

    var body: some View {
        let player = dependencies.narrationPlayer
        Group {
            if stop.narrationSource != nil {
                VStack(alignment: .leading, spacing: 10) {
                    header(player)
                    scrubber(player)
                    transport(player)
                    if isThisStop(player), case .failed(let message) = player.status {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(AppTheme.warning)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(AppTheme.brass.opacity(0.22), lineWidth: 1)
                )
                .accessibilityElement(children: .contain)
            }
        }
    }

    private func header(_ player: NarrationPlayer) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            EyebrowText(eyebrow(player), color: AppTheme.brass)
            Text(stop.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func scrubber(_ player: NarrationPlayer) -> some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { displayedProgress(player) },
                    set: { scrubProgress = $0 }
                ),
                in: 0...1,
                onEditingChanged: { editing in
                    handleScrub(editing, player: player)
                }
            )
            .tint(AppTheme.brass)
            .disabled(!isThisStop(player) || !player.canSeek)
            .accessibilityLabel("Narration position")

            HStack {
                Text(elapsedLabel(player))
                Spacer()
                Text(remainingLabel(player))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private func transport(_ player: NarrationPlayer) -> some View {
        HStack(spacing: 28) {
            Spacer(minLength: 0)
            skipButton(player, delta: -NarrationPlayer.skipInterval, systemImage: "gobackward.15", label: "Skip back 15 seconds")
            playButton(player)
            skipButton(player, delta: NarrationPlayer.skipInterval, systemImage: "goforward.15", label: "Skip forward 15 seconds")
            Spacer(minLength: 0)
        }
    }

    private func playButton(_ player: NarrationPlayer) -> some View {
        Button {
            activate(player)
            player.togglePlayPause()
        } label: {
            ZStack {
                if isThisStop(player), player.status == .loading {
                    ProgressView()
                        .controlSize(.regular)
                } else {
                    Image(systemName: isThisStop(player) && player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 48))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AppTheme.heritageGreen)
                }
            }
            .frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isThisStop(player) && player.isPlaying ? "Pause narration" : "Play narration")
    }

    private func skipButton(_ player: NarrationPlayer, delta: TimeInterval, systemImage: String, label: String) -> some View {
        Button {
            player.skip(by: delta)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .disabled(!isThisStop(player) || !player.canSeek)
        .opacity(isThisStop(player) && player.canSeek ? 1 : 0.35)
        .accessibilityLabel(label)
    }

    private func activate(_ player: NarrationPlayer) {
        if player.stopID != stop.id {
            _ = player.prepare(stop)
        }
    }

    private func handleScrub(_ editing: Bool, player: NarrationPlayer) {
        if editing {
            isScrubbing = true
            scrubProgress = displayedProgress(player)
        } else {
            isScrubbing = false
            if let duration = player.duration, duration > 0 {
                player.seek(to: scrubProgress * duration)
            }
        }
    }

    private func isThisStop(_ player: NarrationPlayer) -> Bool {
        player.stopID == stop.id
    }

    private func displayedProgress(_ player: NarrationPlayer) -> Double {
        guard isThisStop(player) else { return 0 }
        return max(0, min(isScrubbing ? scrubProgress : player.progress, 1))
    }

    private func eyebrow(_ player: NarrationPlayer) -> String {
        if isThisStop(player) {
            switch player.status {
            case .loading: return "Loading"
            case .playing: return "Now playing"
            case .paused: return "Paused"
            case .finished: return "Finished"
            case .failed: return "Could not play"
            case .idle: break
            }
        }
        switch stop.narrationSource {
        case .remoteAudio, .bundledAudio:
            return "Narration"
        case .synthesizedSpeech:
            return "Read aloud"
        case nil:
            return "Narration"
        }
    }

    private func elapsedLabel(_ player: NarrationPlayer) -> String {
        guard isThisStop(player) else { return "0:00" }
        return format(player.elapsed)
    }

    private func remainingLabel(_ player: NarrationPlayer) -> String {
        guard isThisStop(player), let duration = player.duration, duration > 0 else {
            return isThisStop(player) && player.status == .loading ? "…" : "–:––"
        }
        let remaining = max(0, duration - (isScrubbing ? scrubProgress * duration : player.elapsed))
        return "-\(format(remaining))"
    }

    private func format(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
