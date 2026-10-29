import XCTest
@testable import TourCore

final class WalkedTrailPolicyTests: XCTestCase {
    private let origin = GeoCoordinate(latitude: 40.67, longitude: -74.32)
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testGapAndSpeedEdgesAreInclusive() {
        XCTAssertTrue(WalkedTrailPolicy.continues(elapsed: 10, meters: 40))
        XCTAssertTrue(WalkedTrailPolicy.continues(elapsed: 10, meters: 0))
        XCTAssertFalse(WalkedTrailPolicy.continues(elapsed: 10.001, meters: 0))
        XCTAssertFalse(WalkedTrailPolicy.continues(elapsed: 10, meters: 40.001))
        XCTAssertTrue(WalkedTrailPolicy.keepsDrawnPoint(metersFromLastDrawn: 2))
        XCTAssertFalse(WalkedTrailPolicy.keepsDrawnPoint(metersFromLastDrawn: 1.999))
    }

    func testShortStepUpdatesTheAnchorWithoutDrawingOrBridgingALaterGap() {
        let first = fix(0, seconds: 0)
        let hidden = fix(1.5, seconds: 2)
        let later = fix(3, seconds: 12)
        let state = record([first, hidden, later])
        XCTAssertEqual(state.segments, [[first.coordinate, later.coordinate]])
        XCTAssertEqual(state.lastFix, later)

        let replaced = record([first, fix(3, seconds: 12)])
        XCTAssertEqual(replaced.segments, [[fix(3, seconds: 12).coordinate]], "A gap replaces the undrawn point")
        XCTAssertTrue(WalkedTrailPolicy.drawableSegments(replaced.segments).isEmpty)
    }

    func testJumpAndLongGapStartANewSegmentOnlyAfterADrawnLine() {
        let line = record([fix(0, seconds: 0), fix(3, seconds: 2)])
        XCTAssertEqual(line.segments.map(\.count), [2])
        var jumped = line
        let far = fix(53, seconds: 12)
        WalkedTrailPolicy.record(far, into: &jumped, isWalking: true, isAuthorized: true, isPracticeSource: false, now: far.timestamp)
        XCTAssertEqual(jumped.segments.map(\.count), [2, 1])
        XCTAssertEqual(WalkedTrailPolicy.drawableSegments(jumped.segments).map(\.count), [2])

        var gapped = line
        let late = fix(6, seconds: 14)
        WalkedTrailPolicy.record(late, into: &gapped, isWalking: true, isAuthorized: true, isPracticeSource: false, now: late.timestamp)
        XCTAssertEqual(gapped.segments.map(\.count), [2, 1])
    }

    func testRejectedFixClearsTheAnchorSoTheNextGoodFixCannotBridgeIt() {
        let first = fix(0, seconds: 0)
        let next = fix(3, seconds: 2)
        for rejected in [
            fix(3, seconds: 2, accuracy: 25.1),
            fix(3, seconds: 2, accuracy: -0.1),
            fix(3, seconds: 2, accuracy: .nan),
            fix(3, seconds: 2, accuracy: .infinity),
            fix(3, seconds: 2, speed: .infinity),
            fix(3, seconds: 2, simulated: true),
            WalkedTrailFix(coordinate: GeoCoordinate(latitude: 91, longitude: -74.32), timestamp: now.addingTimeInterval(2), horizontalAccuracy: 3)
        ] {
            var state = record([first])
            WalkedTrailPolicy.record(rejected, into: &state, isWalking: true, isAuthorized: true, isPracticeSource: false, now: rejected.timestamp)
            WalkedTrailPolicy.record(next, into: &state, isWalking: true, isAuthorized: true, isPracticeSource: false, now: next.timestamp)
            XCTAssertEqual(state.segments, [[next.coordinate]], "\(rejected)")
        }

        var paused = record([first])
        WalkedTrailPolicy.record(next, into: &paused, isWalking: false, isAuthorized: true, isPracticeSource: false, now: next.timestamp)
        XCTAssertNil(paused.lastFix)
        XCTAssertEqual(paused.segments, [[first.coordinate]])

        var unauthorized = record([first])
        WalkedTrailPolicy.record(next, into: &unauthorized, isWalking: true, isAuthorized: false, isPracticeSource: false, now: next.timestamp)
        XCTAssertNil(unauthorized.lastFix)

        var practice = record([first])
        WalkedTrailPolicy.record(next, into: &practice, isWalking: true, isAuthorized: true, isPracticeSource: true, now: next.timestamp)
        XCTAssertNil(practice.lastFix)
    }

    func testAccuracySpeedAndFreshnessBoundaries() {
        XCTAssertEqual(record([fix(0, seconds: 0, accuracy: 0), fix(3, seconds: 2, accuracy: 25)]).segments.map(\.count), [2])
        XCTAssertEqual(record([fix(0, seconds: 0, speed: nil), fix(3, seconds: 2, speed: -1)]).segments.map(\.count), [2],
                       "A missing or negative speed is not a jump; only a non-finite speed or one above 4 m/s is")

        let fresh = fix(0, seconds: 0)
        var almostExpired = WalkedTrailState()
        WalkedTrailPolicy.record(fresh, into: &almostExpired, isWalking: true, isAuthorized: true, isPracticeSource: false,
                                 now: fresh.timestamp.addingTimeInterval(29.999))
        XCTAssertEqual(almostExpired.lastFix, fresh)
        var expired = WalkedTrailState()
        WalkedTrailPolicy.record(fresh, into: &expired, isWalking: true, isAuthorized: true, isPracticeSource: false,
                                 now: fresh.timestamp.addingTimeInterval(30))
        XCTAssertNil(expired.lastFix)

        let future = fix(0, seconds: 5)
        var allowed = WalkedTrailState()
        WalkedTrailPolicy.record(future, into: &allowed, isWalking: true, isAuthorized: true, isPracticeSource: false, now: now)
        XCTAssertEqual(allowed.lastFix, future)
        var tooFuture = WalkedTrailState()
        WalkedTrailPolicy.record(fix(0, seconds: 5.001), into: &tooFuture, isWalking: true, isAuthorized: true, isPracticeSource: false, now: now)
        XCTAssertNil(tooFuture.lastFix)
    }

    func testRepeatedTimestampDoesNotClearTheAnchor() {
        let first = fix(0, seconds: 0)
        let second = fix(3, seconds: 2)
        var state = record([first, second, second])
        XCTAssertEqual(state.segments.map(\.count), [2])
        XCTAssertEqual(state.lastFix, second)
        let earlier = fix(6, seconds: 1)
        WalkedTrailPolicy.record(earlier, into: &state, isWalking: true, isAuthorized: true, isPracticeSource: false, now: second.timestamp)
        let third = fix(6, seconds: 4)
        WalkedTrailPolicy.record(third, into: &state, isWalking: true, isAuthorized: true, isPracticeSource: false, now: third.timestamp)
        XCTAssertEqual(state.segments, [[first.coordinate, second.coordinate, third.coordinate]])
    }

    func testStoredPointCapDropsTheOldestWithoutJoiningSegments() {
        let repeated = GeoCoordinate(latitude: 40, longitude: -74)
        let last = GeoMath.destination(from: repeated, bearing: 0, distance: 10)
        var crowded = [GeoCoordinate(latitude: 41, longitude: -74)]
        crowded += Array(repeating: repeated, count: 5998)
        crowded.append(last)
        var state = WalkedTrailState(segments: [crowded], lastFix: WalkedTrailFix(coordinate: last, timestamp: now, horizontalAccuracy: 3))
        let added = WalkedTrailFix(coordinate: GeoMath.destination(from: last, bearing: 0, distance: 3),
                                   timestamp: now.addingTimeInterval(2), horizontalAccuracy: 3)
        WalkedTrailPolicy.record(added, into: &state, isWalking: true, isAuthorized: true, isPracticeSource: false, now: added.timestamp)
        XCTAssertEqual(state.segments.count, 1)
        XCTAssertEqual(state.segments[0].count, 6000)
        XCTAssertEqual(state.segments[0].first, repeated)
        XCTAssertEqual(state.segments[0].last, added.coordinate)

        let lead = [GeoCoordinate(latitude: 41, longitude: -74), GeoCoordinate(latitude: 41.001, longitude: -74)]
        var tail = Array(repeating: repeated, count: 5997)
        tail.append(last)
        var split = WalkedTrailState(segments: [lead, tail], lastFix: WalkedTrailFix(coordinate: last, timestamp: now, horizontalAccuracy: 3))
        WalkedTrailPolicy.record(added, into: &split, isWalking: true, isAuthorized: true, isPracticeSource: false, now: added.timestamp)
        XCTAssertEqual(split.segments.count, 1, "A two-point head segment is removed whole")
        XCTAssertEqual(split.segments[0].count, 5999)
        XCTAssertEqual(split.segments[0].first, repeated)
        XCTAssertFalse(split.segments[0].contains(lead[0]))
    }

    func testDrawableSegmentsHideSingletonsAndInvalidCoordinates() {
        let good = origin
        let bad = GeoCoordinate(latitude: .nan, longitude: -74)
        XCTAssertTrue(WalkedTrailPolicy.drawableSegments([[good], [good, bad], [good, good]]).count == 1)
    }

    private func fix(_ metersNorth: Double, seconds: Double, accuracy: Double = 3, speed: Double? = nil, simulated: Bool = false) -> WalkedTrailFix {
        WalkedTrailFix(coordinate: GeoMath.destination(from: origin, bearing: 0, distance: metersNorth),
                       timestamp: now.addingTimeInterval(seconds), horizontalAccuracy: accuracy,
                       speed: speed, isSimulated: simulated)
    }

    private func record(_ fixes: [WalkedTrailFix]) -> WalkedTrailState {
        var state = WalkedTrailState()
        for fix in fixes {
            WalkedTrailPolicy.record(fix, into: &state, isWalking: true, isAuthorized: true, isPracticeSource: false, now: fix.timestamp)
        }
        return state
    }
}
