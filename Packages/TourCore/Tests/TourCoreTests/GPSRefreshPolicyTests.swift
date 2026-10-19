import XCTest
@testable import TourCore

final class GPSRefreshPolicyTests: XCTestCase {
    private let requestedAt = Date(timeIntervalSince1970: 1_800_000_000)

    private func fix(age: TimeInterval = 0, simulated: Bool = false, accuracy: Double = 5) -> GPSRefreshPolicy.Fix {
        GPSRefreshPolicy.Fix(timestamp: requestedAt.addingTimeInterval(age), isSimulated: simulated, horizontalAccuracy: accuracy)
    }

    func testDeviceFixAtOrAfterTheRequestIsAccepted() {
        XCTAssertTrue(GPSRefreshPolicy.isFreshDeviceFix(fix(age: 0), requestedAt: requestedAt))
        XCTAssertTrue(GPSRefreshPolicy.isFreshDeviceFix(fix(age: 0.01, accuracy: 0), requestedAt: requestedAt))
    }

    func testMissingStaleAndSimulatedFixesKeepWaiting() {
        XCTAssertFalse(GPSRefreshPolicy.isFreshDeviceFix(nil, requestedAt: requestedAt))
        XCTAssertFalse(GPSRefreshPolicy.isFreshDeviceFix(fix(age: -0.001), requestedAt: requestedAt))
        XCTAssertFalse(GPSRefreshPolicy.isFreshDeviceFix(fix(simulated: true), requestedAt: requestedAt))
    }

    func testInvalidAccuracyDoesNotCountAsAFreshFix() {
        for accuracy in [Double(-1), -.leastNonzeroMagnitude, .nan, .infinity, -.infinity] {
            XCTAssertFalse(GPSRefreshPolicy.isFreshDeviceFix(fix(accuracy: accuracy), requestedAt: requestedAt))
        }
    }

    func testSimulationAbortsEvenWhenTheSampleWouldOtherwiseCount() {
        XCTAssertEqual(
            GPSRefreshPolicy.tick(isSimulating: true, fix: fix(), requestedAt: requestedAt),
            .stoppedBecauseSimulating
        )
        XCTAssertEqual(
            GPSRefreshPolicy.tick(isSimulating: false, fix: fix(), requestedAt: requestedAt),
            .receivedFreshFix
        )
        XCTAssertEqual(
            GPSRefreshPolicy.tick(isSimulating: false, fix: fix(age: -1), requestedAt: requestedAt),
            .keepWaiting
        )
        XCTAssertEqual(
            GPSRefreshPolicy.tick(isSimulating: false, fix: nil, requestedAt: requestedAt),
            .keepWaiting
        )
    }
}

final class OneShotLocationRefreshTests: XCTestCase {
    func testAuthorizedRefreshPausesUpdatesAndFailureOrLocationResumesThem() {
        var session = OneShotLocationRefresh()
        XCTAssertTrue(session.startUpdating())
        XCTAssertFalse(session.startUpdating(), "A second start must not restart an active manager")

        XCTAssertEqual(session.requestFreshLocation(isAuthorized: true), .beginOneShot)
        XCTAssertFalse(session.isRequestingFreshLocation, "Stopping updates must happen before the one-shot is armed")
        session.armOneShot()
        XCTAssertTrue(session.isRequestingFreshLocation)
        XCTAssertEqual(session.finishOneShot(), .resumeContinuousUpdates)
        XCTAssertFalse(session.isRequestingFreshLocation)
        XCTAssertEqual(session.finishOneShot(), .ignored)
    }

    func testUnauthorizedRequestDoesNotArmARefresh() {
        var session = OneShotLocationRefresh()
        XCTAssertTrue(session.startUpdating())
        XCTAssertEqual(session.requestFreshLocation(isAuthorized: false), .needsAuthorization)
        XCTAssertFalse(session.isRequestingFreshLocation)
        XCTAssertEqual(session.finishOneShot(), .ignored)
        XCTAssertTrue(session.isRunning)
    }

    func testCallbackBeforeTheOneShotIsArmedDoesNotResumeUpdates() {
        var session = OneShotLocationRefresh()
        XCTAssertTrue(session.startUpdating())
        XCTAssertEqual(session.requestFreshLocation(isAuthorized: true), .beginOneShot)
        XCTAssertEqual(session.finishOneShot(), .ignored)
        XCTAssertTrue(session.isRunning)
        session.armOneShot()
        XCTAssertEqual(session.finishOneShot(), .resumeContinuousUpdates)
    }

    func testOneShotWhileIdleDoesNotStartContinuousUpdates() {
        var session = OneShotLocationRefresh()
        XCTAssertEqual(session.requestFreshLocation(isAuthorized: true), .beginOneShot)
        session.armOneShot()
        XCTAssertEqual(session.finishOneShot(), .finishedIdle)
        XCTAssertFalse(session.isRunning)
    }

    func testStopDuringRefreshKeepsTheLaterCallbackFromRestartingUpdates() {
        var session = OneShotLocationRefresh()
        XCTAssertTrue(session.startUpdating())
        XCTAssertEqual(session.requestFreshLocation(isAuthorized: true), .beginOneShot)
        session.armOneShot()
        XCTAssertTrue(session.stopUpdating())
        XCTAssertFalse(session.isRunning)
        XCTAssertFalse(session.isRequestingFreshLocation)
        XCTAssertEqual(session.finishOneShot(), .ignored)
        XCTAssertFalse(session.stopUpdating())
    }

    func testRepeatedOneShotStillRequestsWhileTheFirstIsInFlight() {
        var session = OneShotLocationRefresh()
        XCTAssertTrue(session.startUpdating())
        XCTAssertEqual(session.requestFreshLocation(isAuthorized: true), .beginOneShot)
        session.armOneShot()
        XCTAssertEqual(session.requestFreshLocation(isAuthorized: true), .beginOneShot)
        session.armOneShot()
        XCTAssertEqual(session.finishOneShot(), .resumeContinuousUpdates)
        XCTAssertEqual(session.finishOneShot(), .ignored)
    }
}
