import SwiftUI
import TourCore

/// Stop pages launch the single bottom player without adding a second set of transport controls.
struct NarrationControls: View {
    @Environment(AppDependencies.self) private var dependencies
    let stop: HistoricalStop

    var body: some View {
        let player = dependencies.narrationPlayer
        if stop.narrationSource != nil {
            if player.isPersistentPlayerVisible && player.stopID == stop.id {
                Text("Use the player below to listen or pause.")
                    .font(.subheadline).foregroundStyle(AppTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Button {
                    guard player.prepare(stop) else { return }
                    player.play()
                } label: {
                    Label(player.hasSavedResume(for: stop) ? "Resume narration" : "Play narration", systemImage: "play.fill")
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .foregroundStyle(.white)
                        .background(AppTheme.forest, in: RoundedRectangle(cornerRadius: 14))
                        .contentShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.forest)
                .accessibilityHint("Opens the bottom player without changing your walking destination")
                .accessibilityIdentifier("narration.openPlayer")
                if player.stopID == stop.id, case .failed(let message) = player.status {
                    Text(message).font(.footnote).foregroundStyle(AppTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
