import XCTest
@testable import TourCore

final class MapLocationRecoveryTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testHealthyFixAndRetryIntervalAreExclusiveAtTheLowEnd() {
        let subscribed = true
        XCTAssertFalse(MapLocationRecovery.shouldRequestFreshFix(isSubscribed: false, isAuthorized: true,
            latestFix: nil, lastRequest: nil, now: now))
        XCTAssertFalse(MapLocationRecovery.shouldRequestFreshFix(isSubscribed: subscribed, isAuthorized: false,
            latestFix: nil, lastRequest: nil, now: now))
        XCTAssertTrue(MapLocationRecovery.shouldRequestFreshFix(isSubscribed: subscribed, isAuthorized: true,
            latestFix: nil, lastRequest: nil, now: now))

        let fresh = now.addingTimeInterval(-9.999)
        XCTAssertFalse(MapLocationRecovery.shouldRequestFreshFix(isSubscribed: subscribed, isAuthorized: true,
            latestFix: fresh, lastRequest: now.addingTimeInterval(-30), now: now))
        XCTAssertFalse(MapLocationRecovery.shouldRequestFreshFix(isSubscribed: subscribed, isAuthorized: true,
            latestFix: now.addingTimeInterval(1), lastRequest: now.addingTimeInterval(-30), now: now),
                       "A fix dated slightly ahead is still the live stream")
        XCTAssertTrue(MapLocationRecovery.shouldRequestFreshFix(isSubscribed: subscribed, isAuthorized: true,
            latestFix: now.addingTimeInterval(-10), lastRequest: now.addingTimeInterval(-30), now: now))

        XCTAssertFalse(MapLocationRecovery.shouldRequestFreshFix(isSubscribed: subscribed, isAuthorized: true,
            latestFix: nil, lastRequest: now.addingTimeInterval(-14.999), now: now))
        XCTAssertTrue(MapLocationRecovery.shouldRequestFreshFix(isSubscribed: subscribed, isAuthorized: true,
            latestFix: nil, lastRequest: now.addingTimeInterval(-15), now: now))
    }
}

final class PassportCelebrationPolicyTests: XCTestCase {
    func testAutoDismissWaitsLongerForVoiceOverAndOnlyForTheSavedStamp() {
        XCTAssertEqual(PassportCelebrationPolicy.autoDismissMilliseconds(voiceOverRunning: false), 2400)
        XCTAssertEqual(PassportCelebrationPolicy.autoDismissMilliseconds(voiceOverRunning: true), 4500)
        XCTAssertNil(PassportCelebrationPolicy.scheduledStopID(sceneIsActive: false, pendingStopID: "mill", stampIsSaved: true))
        XCTAssertNil(PassportCelebrationPolicy.scheduledStopID(sceneIsActive: true, pendingStopID: "mill", stampIsSaved: false))
        XCTAssertNil(PassportCelebrationPolicy.scheduledStopID(sceneIsActive: true, pendingStopID: nil, stampIsSaved: true))
        XCTAssertEqual(PassportCelebrationPolicy.scheduledStopID(sceneIsActive: true, pendingStopID: "mill", stampIsSaved: true), "mill")
    }

    func testAutoDismissFinishesOnlyForTheSameActiveStop() {
        XCTAssertTrue(PassportCelebrationPolicy.shouldFinishAutoDismiss(sceneIsActive: true, pendingStopID: "mill", scheduledStopID: "mill"))
        XCTAssertFalse(PassportCelebrationPolicy.shouldFinishAutoDismiss(sceneIsActive: false, pendingStopID: "mill", scheduledStopID: "mill"))
        XCTAssertFalse(PassportCelebrationPolicy.shouldFinishAutoDismiss(sceneIsActive: true, pendingStopID: "park", scheduledStopID: "mill"))
        XCTAssertFalse(PassportCelebrationPolicy.shouldFinishAutoDismiss(sceneIsActive: true, pendingStopID: nil, scheduledStopID: "mill"))
    }
}

final class StopListStatusTests: XCTestCase {
    func testOnlyAVisitOrCompletedStopIsLabeled() {
        let date = Date(timeIntervalSince1970: 10)
        XCTAssertEqual(StopListStatus.labels(visitedAt: nil, plaqueUnlockedAt: nil, listenedAt: nil, readAt: nil, isItineraryComplete: false), [])
        XCTAssertEqual(StopListStatus.labels(visitedAt: nil, plaqueUnlockedAt: date, listenedAt: date, readAt: date, isItineraryComplete: false), [],
                       "A stamp or a story is not a stops-list status")
        XCTAssertEqual(StopListStatus.labels(visitedAt: date, plaqueUnlockedAt: date, listenedAt: date, readAt: date, isItineraryComplete: false), ["Visited"])
        XCTAssertEqual(StopListStatus.labels(visitedAt: nil, plaqueUnlockedAt: date, listenedAt: nil, readAt: nil, isItineraryComplete: true), ["Visited"])
        XCTAssertEqual(StopListStatus.labels(visitedAt: date, plaqueUnlockedAt: nil, listenedAt: nil, readAt: nil, isItineraryComplete: true), ["Visited"])
    }
}

final class RemainingWalkingRouteTests: XCTestCase {
    func testLateralBoundaryAndShortVertices() {
        let start = GeoCoordinate(latitude: 40.65, longitude: -74.30)
        let skipped = GeoMath.destination(from: start, bearing: 90, distance: 0.05)
        // Destination rounding can land a requested 0.1 m just under the cutoff. Step until measured distance reaches it.
        var requested = 0.1
        var kept = GeoMath.destination(from: start, bearing: 90, distance: requested)
        while GeoMath.distance(from: start, to: kept) < RemainingWalkingRoute.minimumVertexSeparationMeters {
            requested += 0.0001
            kept = GeoMath.destination(from: start, bearing: 90, distance: requested)
        }
        let end = GeoMath.destination(from: start, bearing: 90, distance: 20)
        XCTAssertLessThan(GeoMath.distance(from: start, to: skipped), 0.1)
        XCTAssertGreaterThanOrEqual(GeoMath.distance(from: start, to: kept), 0.1)
        XCTAssertLessThan(GeoMath.distance(from: start, to: kept), 0.1002)

        let trimmed = RemainingWalkingRoute.trimmed(coordinates: [start, skipped, kept, end], snapped: start, lateralMeters: 35, segmentIndex: 0)
        XCTAssertEqual(trimmed, [start, kept, end])
        XCTAssertNil(RemainingWalkingRoute.trimmed(coordinates: [start, end], snapped: start, lateralMeters: 35.0001, segmentIndex: 0))
        XCTAssertNil(RemainingWalkingRoute.trimmed(coordinates: [start, end], snapped: start, lateralMeters: -0.001, segmentIndex: 0))
        XCTAssertNil(RemainingWalkingRoute.trimmed(coordinates: [start, end], snapped: start, lateralMeters: .nan, segmentIndex: 0))
        XCTAssertNil(RemainingWalkingRoute.trimmed(coordinates: [start, end], snapped: start, lateralMeters: .infinity, segmentIndex: 0))
        XCTAssertNil(RemainingWalkingRoute.trimmed(coordinates: [start, end], snapped: GeoCoordinate(latitude: 91, longitude: -74), lateralMeters: 0, segmentIndex: 0))
        XCTAssertNil(RemainingWalkingRoute.trimmed(coordinates: [start, end], snapped: start, lateralMeters: 0, segmentIndex: 1))
        XCTAssertNil(RemainingWalkingRoute.trimmed(coordinates: [start, end], snapped: start, lateralMeters: 0, segmentIndex: -1))
    }

    func testProjectionAtTheDestinationDrawsNothing() {
        let start = GeoCoordinate(latitude: 40.65, longitude: -74.30)
        let end = GeoMath.destination(from: start, bearing: 90, distance: 20)
        XCTAssertEqual(RemainingWalkingRoute.trimmed(coordinates: [start, end], snapped: end, lateralMeters: 0, segmentIndex: 0), [])
        let ahead = RemainingWalkingRoute.trimmed(coordinates: [start, end], snapped: start, lateralMeters: 0, segmentIndex: 0)
        XCTAssertEqual(ahead, [start, end])
    }
}
