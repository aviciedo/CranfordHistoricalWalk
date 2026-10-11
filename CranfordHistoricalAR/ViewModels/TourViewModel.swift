import Foundation
import Observation
import TourCore

/// Single source of truth for the tour (spec §17). Stage 1: stops + tour phase + navigation.
@MainActor
@Observable
final class TourViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    // MARK: Tour data
    private(set) var tourName: String = "Cranford Historical Walk"
    private(set) var dataStatus: String?
    private(set) var stops: [HistoricalStop] = []
    private(set) var loadState: LoadState = .idle
    private(set) var progress = TourProgress(stopIDs: [])

    // MARK: Navigation
    private(set) var isShowingTour = false

    private let stopService: any HistoricalStopService

    init(stopService: any HistoricalStopService) {
        self.stopService = stopService
    }

    // MARK: Derived state

    var phase: TourPhase { progress.phase }

    var currentStop: HistoricalStop? {
        progress.currentStopID.flatMap(stop(withID:))
    }

    var nextStop: HistoricalStop? {
        progress.nextStopID.flatMap(stop(withID:))
    }

    var lastCompletedStop: HistoricalStop? {
        progress.previousCompletedStopID.flatMap(stop(withID:))
    }

    func stop(withID id: String) -> HistoricalStop? {
        stops.first { $0.id == id }
    }

    func isCompleted(_ stop: HistoricalStop) -> Bool {
        progress.isCompleted(stop.id)
    }

    // MARK: Loading

    func loadStopsIfNeeded() async {
        guard loadState == .idle || loadState.isFailure else { return }
        loadState = .loading
        do {
            let document = try await stopService.loadTour()
            tourName = document.tourName
            dataStatus = document.dataStatus
            stops = document.stops
            progress = TourProgress(stopIDs: document.stops.map(\.id))
            loadState = .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    // MARK: Tour lifecycle

    func startTour() {
        guard loadState == .loaded, !stops.isEmpty else { return }
        if progress.phase == .notStarted {
            progress.start()
        }
        isShowingTour = true
    }

    func leaveTour() {
        isShowingTour = false
    }

    func resetTour() {
        progress.reset()
    }
}

extension TourViewModel.LoadState {
    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}
