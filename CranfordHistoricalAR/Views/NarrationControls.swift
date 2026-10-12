import SwiftUI
import TourCore

/// Shared play/pause strip for a stop's narration. One `NarrationPlayer` is owned by
/// `AppDependencies`, so the map sheet and the AR screen cannot talk over each other.
struct NarrationControls: View {
    @Environment(AppDependencies.self) private var dependencies
    let stop: HistoricalStop

    var body: some View {
        let player = dependencies.narrationPlayer
        Group {
            if stop.narrationSource != nil {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Button {
                            if player.stopID != stop.id { _ = player.prepare(stop) }
                            player.togglePlayPause()
                        } label: {
                            Image(systemName: player.stopID == stop.id && player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(AppTheme.heritageGreen)
                        }
                        .accessibilityLabel(player.isPlaying && player.stopID == stop.id ? "Pause narration" : "Play narration")

                        VStack(alignment: .leading, spacing: 2) {
                            Text(title(player))
                                .font(.subheadline.weight(.semibold))
                            Text(subtitle(player))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        if player.stopID == stop.id, player.canSeek {
                            Button { player.skip(by: -NarrationPlayer.skipInterval) } label: {
                                Image(systemName: "gobackward.15")
                            }
                            .accessibilityLabel("Skip back 15 seconds")
                            Button { player.skip(by: NarrationPlayer.skipInterval) } label: {
                                Image(systemName: "goforward.15")
                            }
                            .accessibilityLabel("Skip forward 15 seconds")
                        }
                    }
                    if player.stopID == stop.id {
                        ProgressView(value: max(0, min(player.progress, 1)))
                            .tint(AppTheme.brass)
                        if case .failed(let message) = player.status {
                            Text(message).font(.caption).foregroundStyle(AppTheme.warning)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onAppear { _ = player.prepare(stop) }
            }
        }
    }

    private func title(_ player: NarrationPlayer) -> String {
        switch stop.narrationSource {
        case .remoteAudio, .bundledAudio:
            return "Listen"
        case .synthesizedSpeech:
            return "Listen (spoken description)"
        case nil:
            return "Listen"
        }
    }

    private func subtitle(_ player: NarrationPlayer) -> String {
        guard player.stopID == stop.id else {
            switch stop.narrationSource {
            case .remoteAudio, .bundledAudio: return "HPAB recording"
            case .synthesizedSpeech: return "Read aloud from the stop description"
            case nil: return ""
            }
        }
        switch player.status {
        case .loading: return "Loading…"
        case .playing: return player.canSeek ? timeLabel(player) : "Playing"
        case .paused: return player.canSeek ? timeLabel(player) : "Paused"
        case .finished: return "Finished"
        case .failed: return "Could not play"
        case .idle: return player.kind == .synthesizedSpeech ? "Spoken description" : "Ready"
        }
    }

    private func timeLabel(_ player: NarrationPlayer) -> String {
        let elapsed = format(player.elapsed)
        if let duration = player.duration { return "\(elapsed) / \(format(duration))" }
        return elapsed
    }

    private func format(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
