import XCTest
@testable import TourCore

final class StopListStatusTests: XCTestCase {
    func testASavedVisitOutranksCompletionAndTheCurrentDestination() {
        XCTAssertEqual(
            StopListStatus.resolve(recordedVisitEvidence: .recognizedPlaque, isCompleted: true, hasPlaqueReference: true, isCurrentDestination: true),
            .recordedVisit(plaqueVerified: true)
        )
        XCTAssertEqual(
            StopListStatus.resolve(recordedVisitEvidence: .onSiteARMarker, isCompleted: true, hasPlaqueReference: false, isCurrentDestination: true),
            .recordedVisit(plaqueVerified: false)
        )
        XCTAssertEqual(
            StopListStatus.resolve(recordedVisitEvidence: .simulation, isCompleted: false, hasPlaqueReference: true, isCurrentDestination: false),
            .recordedVisit(plaqueVerified: false)
        )
    }

    func testCompletedPlaqueStopsSayVerificationIsMissingAndOtherCompletionsArePractice() {
        XCTAssertEqual(
            StopListStatus.resolve(recordedVisitEvidence: nil, isCompleted: true, hasPlaqueReference: true, isCurrentDestination: true),
            .completed(savedPlaqueMissing: true)
        )
        XCTAssertEqual(
            StopListStatus.resolve(recordedVisitEvidence: nil, isCompleted: true, hasPlaqueReference: false, isCurrentDestination: true),
            .completed(savedPlaqueMissing: false)
        )
    }

    func testOnlyTheUnguidedCurrentStopIsNext() {
        XCTAssertEqual(
            StopListStatus.resolve(recordedVisitEvidence: nil, isCompleted: false, hasPlaqueReference: true, isCurrentDestination: true),
            .nextOnWalk
        )
        XCTAssertEqual(
            StopListStatus.resolve(recordedVisitEvidence: nil, isCompleted: false, hasPlaqueReference: false, isCurrentDestination: false),
            .none
        )
    }

    func testStopsListUsesSuppliedArtForTheFirstThreeStopsAndAChurchOnlyForTheFourth() {
        XCTAssertEqual(StopListArtwork.selection(for: "hpab-001"), .bundled(name: "mill-map-landmark"))
        XCTAssertEqual(StopListArtwork.selection(for: "hpab-002"), .bundled(name: "greystone-map-landmark"))
        XCTAssertEqual(StopListArtwork.selection(for: "hpab-003"), .bundled(name: "rahway-river-illustration"))
        XCTAssertEqual(StopListArtwork.selection(for: "hpab-004"), .symbolic(isChurch: true))
        XCTAssertEqual(StopListArtwork.selection(for: "hpab-005"), .symbolic(isChurch: false))
        XCTAssertEqual(StopListArtwork.selection(for: ""), .symbolic(isChurch: false))
        XCTAssertEqual(StopListArtwork.selection(for: "hpab-003 ").selectionName, nil)
    }

    func testScreenDescriptionHidesTheHPABPlaceholderAndKeepsRealCopy() throws {
        let stops = try HistoricalStopDecoder.decode(Fixtures.data("historical_stops")).stops
        XCTAssertFalse(stops[0].screenDescription.isEmpty)
        XCTAssertTrue(stops[0].screenDescription.contains("Severin Droescher"))
        XCTAssertFalse(stops[1].screenDescription.isEmpty)
        for stop in stops.dropFirst(2) {
            XCTAssertEqual(stop.screenDescription, "", "\(stop.id) must not present the HPAB placeholder as its description")
            XCTAssertTrue(stop.shortDescription.hasPrefix(HistoricalStop.placeholderShortDescriptionPrefix))
        }

        var stop = makeStop()
        stop.longDescription = " The long story. "
        stop.shortDescription = "HPAB audio-tour stop. ignored"
        XCTAssertEqual(stop.screenDescription, " The long story. ")
        stop.longDescription = " "
        XCTAssertEqual(stop.screenDescription, " ", "Whitespace in the long description is still the screen copy")
        stop.longDescription = ""
        XCTAssertEqual(stop.screenDescription, "")
        stop.shortDescription = "hpab audio-tour stop."
        XCTAssertEqual(stop.screenDescription, "hpab audio-tour stop.")
        stop.shortDescription = " HPAB audio-tour stop."
        XCTAssertEqual(stop.screenDescription, " HPAB audio-tour stop.")
        stop.shortDescription = "A real short description."
        XCTAssertEqual(stop.screenDescription, "A real short description.")
    }
}

private extension StopListArtwork {
    var selectionName: String? {
        if case .bundled(let name) = self { return name }
        return nil
    }
}
