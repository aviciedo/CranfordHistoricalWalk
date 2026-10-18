import SwiftUI
import TourCore

struct StopsView: View {
    var body: some View {
        NavigationStack {
            StopsContent()
                .navigationTitle("The stops")
                .toolbarBackground(AppTheme.parchment, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

struct StopsContent: View {
    @Environment(TourViewModel.self) private var tour
    @State private var detailStop: HistoricalStop?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(tour.stops) { stop in
                    HStack(spacing: 16) {
                        if stop.hasAnyImage {
                            StopPhoto(stop: stop, height: 76, cornerRadius: 12, width: 76)
                        }
                        Button { detailStop = stop } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Stop \(stop.order)").font(.subheadline).foregroundStyle(AppTheme.secondaryInk)
                                    Text(stop.name).font(.system(.title3, design: .serif).weight(.semibold))
                                    if tour.isCompleted(stop) {
                                        Label("Visited", systemImage: "checkmark.circle.fill")
                                            .font(.caption).foregroundStyle(AppTheme.visited)
                                    } else if stop.id == tour.currentStop?.id {
                                        Text("Next on your walk").font(.caption).foregroundStyle(AppTheme.secondaryInk)
                                    }
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right").font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Stop \(stop.order), \(stop.name), details and narration")
                    }
                    .padding(.vertical, 20)
                    Divider()
                }
            }
            .padding(.horizontal, 24)
        }
        .background(AppTheme.parchment).foregroundStyle(AppTheme.ink)
        .sheet(item: $detailStop) { HistoricalSignSheet(stop: $0) }
    }
}
