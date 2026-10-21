import SwiftUI
import TourCore

/// Compact stop-detail player based on the selected walking-screen reference.
/// The stop title sits above a seekable timeline, with elapsed and total time below.
struct NarrationControls: View {
    @Environment(AppDependencies.self) private var dependencies
    let stop: HistoricalStop

    var body: some View {
        if stop.narrationSource != nil {
            let player = dependencies.narrationPlayer
            HStack(alignment: .center, spacing: 16) {
                NarrationPlayButton(stop: stop, diameter: 58)

                VStack(alignment: .leading, spacing: 3) {
                    Text(stop.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                    NarrationTimeline(stop: stop)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.ivory, in: RoundedRectangle(cornerRadius: 14))
            .overlay(alignment: .bottomLeading) {
                if player.stopID == stop.id, case .failed(let message) = player.status {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.warning)
                        .offset(y: 22)
                }
            }
        }
    }
}
