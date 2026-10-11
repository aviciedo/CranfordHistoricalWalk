import SwiftUI
import TourCore

/// Shown on the map screen when the user is inside a stop's arrival radius but not in AR,
/// so the "look through the camera now" moment is never missed (spec §24).
struct ArrivalCard: View {
    @Environment(TourViewModel.self) private var tour
    let stop: HistoricalStop
    var onEnterAR: () -> Void
    var onRead: () -> Void

    var body: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").foregroundStyle(AppTheme.brass)
                    EyebrowText("You've arrived", color: AppTheme.brass)
                    Spacer()
                    Button {
                        tour.closeSign()
                    } label: {
                        Image(systemName: "xmark").font(.footnote.weight(.semibold)).frame(width: 28, height: 28)
                    }
                    .accessibilityLabel("Dismiss")
                }
                Text(stop.name).font(AppTheme.Fonts.title).lineLimit(2)
                Text("Open the camera to see the historical sign placed in front of you.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Button(action: onEnterAR) {
                        Label("View in AR", systemImage: "arkit")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.heritageGreen)
                    Button(action: onRead) {
                        Label("Read", systemImage: "text.book.closed")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}
