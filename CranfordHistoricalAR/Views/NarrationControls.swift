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
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 16) {
                    NarrationPlayButton(stop: stop, diameter: 58)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(stop.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        NarrationTimeline(stop: stop)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if player.stopID == stop.id, case .failed(let message) = player.status {
                    Text(message).font(.footnote).foregroundStyle(AppTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.ivory, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}
