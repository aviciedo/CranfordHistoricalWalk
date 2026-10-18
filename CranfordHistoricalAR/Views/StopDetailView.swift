import SwiftUI
import TourCore

/// Browsing a stop never retargets the tour. AR is offered only for its current destination.
struct StopDetailView: View {
    @Environment(TourViewModel.self) private var tour
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.dismiss) private var dismiss
    let stop: HistoricalStop
    var onContinue: (() -> Void)? = nil
    @State private var isShowingAR = false

    private var isCurrent: Bool { tour.phase == .inProgress && tour.currentStop?.id == stop.id }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    StopPhoto(stop: stop, height: 240, cornerRadius: 16)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Stop \(stop.order) of \(tour.stops.count)")
                            .font(.subheadline).foregroundStyle(AppTheme.secondaryInk)
                        Text(stop.name).font(.system(.largeTitle, design: .serif).weight(.semibold))
                        if let date = stop.displayDate {
                            Text(date).font(.title3).foregroundStyle(AppTheme.secondaryInk)
                        }
                        Label(stop.address, systemImage: "mappin.and.ellipse")
                            .font(.subheadline).foregroundStyle(AppTheme.secondaryInk)
                    }
                    HStack(spacing: 12) {
                        Button {
                            navigation.showOnMap(stopID: stop.id)
                            dismiss()
                        } label: {
                            Label("Show on map", systemImage: "map")
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(.plain)
                        .background(AppTheme.playerSurface, in: RoundedRectangle(cornerRadius: 12))
                        if isCurrent {
                            Button { isShowingAR = true } label: {
                                Label("View in AR", systemImage: "camera.viewfinder")
                                    .frame(maxWidth: .infinity, minHeight: 52)
                            }
                            .buttonStyle(.plain).foregroundStyle(AppTheme.ivory)
                            .background(AppTheme.forest, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    NarrationControls(stop: stop)
                    if !stop.longDescription.isEmpty {
                        Text(stop.longDescription).font(.body).lineSpacing(5)
                    } else if !stop.shortDescription.hasPrefix("HPAB audio-tour stop.") {
                        Text(stop.shortDescription).font(.body).lineSpacing(5)
                    }
                    if let script = stop.narrationText, !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        DisclosureGroup("Read narration") {
                            Text(script).font(.body).lineSpacing(5)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 12)
                        }
                        .font(.subheadline.weight(.medium))
                    }
                    if let visit = tour.lastRecordedVisit(for: stop) {
                        Label {
                            Text("Visited \(visit.activatedAt.formatted(date: .abbreviated, time: .omitted))")
                        } icon: { Image(systemName: "checkmark.circle.fill") }
                        .font(.subheadline).foregroundStyle(AppTheme.visited)
                    }
                    if isCurrent && tour.isCurrentStopVisited {
                        Button {
                            tour.completeCurrentStopAndAdvance()
                            dismiss()
                            onContinue?()
                        } label: {
                            Label(tour.nextStop == nil ? "Finish tour" : "Continue to next stop", systemImage: "arrow.right")
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.plain).font(.body.weight(.medium))
                        Divider()
                    }
                    DisclosureGroup("About this stop") {
                        VStack(alignment: .leading, spacing: 10) {
                            if let plaque = stop.plaque, plaque.isUsable {
                                Text("\(plaque.quoteLabel): “\(plaque.transcription)”")
                                Text("The plaque inscription is separate from the building’s construction history above.")
                            }
                            if stop.coordinatesUnverified {
                                Text("The map position is approximate and has not been checked on site.")
                            }
                            if stop.isSample { Text("Sample content — not verified history.") }
                            if let status = tour.dataStatus { Text(status) }
                        }
                        .font(.footnote).foregroundStyle(AppTheme.secondaryInk).padding(.top, 8)
                    }
                    .font(.subheadline)
                }
                .padding(24)
            }
            .background(AppTheme.parchment).foregroundStyle(AppTheme.ink)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.parchment, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Close stop details")
                }
            }
            .fullScreenCover(isPresented: $isShowingAR, onDismiss: { dismiss() }) { ARTourView() }
        }
    }
}
