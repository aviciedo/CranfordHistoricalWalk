import SwiftUI
import TourCore

/// Minimal narration transport on each historical stop detail page.
struct NarrationControls: View {
    @Environment(AppDependencies.self) private var dependencies
    let stop: HistoricalStop

    var body: some View {
        if stop.narrationSource != nil {
            let player = dependencies.narrationPlayer
            let isCurrent = player.stopID == stop.id
            HStack(spacing: 16) {
                NarrationPlayButton(stop: stop)
                Text(time(isCurrent ? player.elapsed : 0))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppTheme.secondaryInk)
                Spacer()
                Text(time(isCurrent ? player.duration : nil))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppTheme.secondaryInk)
            }
            .padding(14)
            .background(AppTheme.ivory, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .contain)
            .overlay(alignment: .bottomLeading) {
                if isCurrent, case .failed(let message) = player.status {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.warning)
                        .offset(y: 22)
                }
            }
        }
    }

    private func time(_ seconds: TimeInterval?) -> String {
        guard let seconds, seconds.isFinite else { return "—" }
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
