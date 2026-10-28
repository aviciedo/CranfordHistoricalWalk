import XCTest
@testable import TourCore

final class RouteRecoveryPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let coordinate = GeoCoordinate(latitude: 40.650249, longitude: -74.301047)

    private func fix(accuracy: Double, age: TimeInterval) -> RouteRecoveryPolicy.Fix {
        .init(coordinate: coordinate, horizontalAccuracy: accuracy, timestamp: now.addingTimeInterval(-age))
    }

    func testBudgetStopsAfterFiveScheduledRecoveries() {
        for attempts in 0..<5 {
            XCTAssertTrue(RouteRecoveryPolicy.canSchedule(attempts: attempts))
        }
        XCTAssertFalse(RouteRecoveryPolicy.canSchedule(attempts: 5))
        XCTAssertFalse(RouteRecoveryPolicy.canSchedule(attempts: 20))
    }

    func testScheduledWakeRoutesOnlyFromAFreshAccurateFix() {
        let good = fix(accuracy: StopActivationPolicy.maximumAccuracyMeters, age: 29)
        XCTAssertEqual(
            RouteRecoveryPolicy.onScheduledWake(walking: true, routingIdle: true, generationCurrent: true,
                                                fix: good, hasDestination: true, now: now),
            .request(coordinate))

        let refused: [RouteRecoveryPolicy.Fix?] = [
            fix(accuracy: 25, age: 30),
            fix(accuracy: 25, age: -6),
            fix(accuracy: 25.1, age: 0),
            fix(accuracy: -1, age: 0),
            fix(accuracy: .nan, age: 0),
            nil,
        ]
        for sample in refused {
            XCTAssertEqual(
                RouteRecoveryPolicy.onScheduledWake(walking: true, routingIdle: true, generationCurrent: true,
                                                    fix: sample, hasDestination: true, now: now),
                .deferUntilFreshFix)
        }
        XCTAssertEqual(
            RouteRecoveryPolicy.onScheduledWake(walking: true, routingIdle: true, generationCurrent: true,
                                                fix: good, hasDestination: false, now: now),
            .deferUntilFreshFix)
    }

    func testPausedSupersededOrInFlightWakeDoesNotArmARetry() {
        let good = fix(accuracy: 5, age: 1)
        let stale = fix(accuracy: 80, age: 120)
        for sample in [good, stale] {
            XCTAssertEqual(
                RouteRecoveryPolicy.onScheduledWake(walking: false, routingIdle: true, generationCurrent: true,
                                                    fix: sample, hasDestination: true, now: now),
                .ignore)
            XCTAssertEqual(
                RouteRecoveryPolicy.onScheduledWake(walking: true, routingIdle: false, generationCurrent: true,
                                                    fix: sample, hasDestination: true, now: now),
                .ignore)
            XCTAssertEqual(
                RouteRecoveryPolicy.onScheduledWake(walking: true, routingIdle: true, generationCurrent: false,
                                                    fix: sample, hasDestination: true, now: now),
                .ignore)
        }
    }

    func testDeferredRetryConsumesOnlyAnAcceptableSample() {
        let good = fix(accuracy: 0, age: -5)
        XCTAssertEqual(
            RouteRecoveryPolicy.onLocationSample(deferred: true, walking: true, hasDestination: true, fix: good, now: now),
            .request(coordinate))
        XCTAssertEqual(
            RouteRecoveryPolicy.onLocationSample(deferred: false, walking: true, hasDestination: true, fix: good, now: now),
            .ignore, "An ordinary location sample must not be treated as a recovery request")

        for sample in [fix(accuracy: 40, age: 0), fix(accuracy: 5, age: 30)] {
            XCTAssertEqual(
                RouteRecoveryPolicy.onLocationSample(deferred: true, walking: true, hasDestination: true, fix: sample, now: now),
                .ignore)
        }
        XCTAssertEqual(
            RouteRecoveryPolicy.onLocationSample(deferred: true, walking: false, hasDestination: true, fix: good, now: now),
            .ignore)
        XCTAssertEqual(
            RouteRecoveryPolicy.onLocationSample(deferred: true, walking: true, hasDestination: false, fix: good, now: now),
            .ignore)
    }

    func testManualRetryDoesNothingUntilTheWalkIsActive() {
        let good = fix(accuracy: 8, age: 2)
        XCTAssertEqual(
            RouteRecoveryPolicy.onManualRetry(walking: false, fix: good, hasDestination: true, now: now),
            .ignore)
        XCTAssertEqual(
            RouteRecoveryPolicy.onManualRetry(walking: true, fix: good, hasDestination: true, now: now),
            .request(coordinate))
        XCTAssertEqual(
            RouteRecoveryPolicy.onManualRetry(walking: true, fix: fix(accuracy: 5, age: 31), hasDestination: true, now: now),
            .deferUntilFreshFix)
        XCTAssertEqual(
            RouteRecoveryPolicy.onManualRetry(walking: true, fix: nil, hasDestination: true, now: now),
            .deferUntilFreshFix)
        XCTAssertEqual(
            RouteRecoveryPolicy.onManualRetry(walking: true, fix: good, hasDestination: false, now: now),
            .deferUntilFreshFix)
    }
}
