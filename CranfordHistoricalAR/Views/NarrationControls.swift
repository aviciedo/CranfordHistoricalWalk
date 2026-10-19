import SwiftUI
import TourCore

/// Expanded transport in stop details and AR. Shares playback with the compact tab player.
struct NarrationControls: View {
    @Environment(AppDependencies.self) private var dependencies
    let stop: HistoricalStop

    var body: some View {
        if stop.narrationSource != nil {
            let player = dependencies.narrationPlayer
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    NarrationPlayButton(stop: stop)
                    Text("Listen to the story").font(.body.weight(.medium))
                    Spacer()
                    if stop.hasRecordedNarration {
                        skip(-15, symbol: "gobackward.15", label: "Skip back 15 seconds")
                        skip(15, symbol: "goforward.15", label: "Skip forward 15 seconds")
                    }
                }
                NarrationTimeline(stop: stop)
                if let recording = ProducedNarrationRelease.recording(for: stop.id) {
                    Text("AI-generated narration · OpenAI cedar · \(Int(recording.duration.rounded()) / 60):\(String(format: "%02d", Int(recording.duration.rounded()) % 60))")
                        .font(.caption).foregroundStyle(AppTheme.secondaryInk)
                }
                if player.stopID == stop.id, case .failed(let message) = player.status {
                    Text(message).font(.footnote).foregroundStyle(AppTheme.warning)
                }
            }
            .foregroundStyle(AppTheme.ink)
            .padding(16).background(AppTheme.playerSurface, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func skip(_ seconds: TimeInterval, symbol: String, label: String) -> some View {
        Button { dependencies.narrationPlayer.skip(by: seconds) } label: {
            Image(systemName: symbol).font(.title3).frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .disabled(dependencies.narrationPlayer.stopID != stop.id || !dependencies.narrationPlayer.canSeek)
        .accessibilityLabel(label)
    }
}
