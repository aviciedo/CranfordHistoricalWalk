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
                    if tour.isCompleted(stop) {
                        Label("Visited", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.visited)
                    }
                }
                Text(stop.name).font(AppTheme.Fonts.title).lineLimit(2)
                StopPhoto(stop: stop, height: 140)
                NarrationControls(stop: stop)
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
                // Closing the sign at a visited stop advances the tour (spec §11).
                Button {
                    tour.closeSign()
                } label: {
                    Label(tour.nextStop == nil ? "Finish tour" : "Continue to next stop", systemImage: "arrow.right")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.heritageGreen)
                .padding(.top, 2)
            }
        }
    }
}
