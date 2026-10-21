import XCTest
@testable import TourCore

final class LocationGuidanceTests: XCTestCase {
    private let weakGPS = 40.0

    func testPermissionStateHidesEveryOtherLocationProblem() {
        let accurate = issue(.notDetermined, precise: true, hasLocation: true, accuracy: 5, failure: .network)
        XCTAssertEqual(accurate, .permissionNotDetermined)
        XCTAssertEqual(issue(.denied, precise: false, hasLocation: false, accuracy: nil, failure: nil), .permissionDenied)
        XCTAssertEqual(issue(.restricted, precise: true, hasLocation: true, accuracy: 80, failure: .denied), .permissionRestricted)
    }

    func testAFailureBeforeAnyFixBeatsPrecisionAndDoesNotOutliveALaterFix() {
        XCTAssertEqual(issue(.authorized, precise: true, hasLocation: false, accuracy: nil, failure: .denied), .permissionDenied)
        XCTAssertEqual(issue(.authorized, precise: true, hasLocation: false, accuracy: nil, failure: .locationUnknown), .waitingForSignal)
        XCTAssertEqual(
            issue(.authorized, precise: false, hasLocation: false, accuracy: nil, failure: .network),
            .failure(LocationGuidance.networkFailureMessage)
        )
        XCTAssertEqual(issue(.authorized, precise: true, hasLocation: false, accuracy: nil, failure: .other("GPS hardware fault")), .failure("GPS hardware fault"))

        XCTAssertNil(issue(.authorized, precise: true, hasLocation: true, accuracy: 8, failure: .network))
        XCTAssertEqual(issue(.authorized, precise: true, hasLocation: true, accuracy: 55, failure: .denied), .poorAccuracy(meters: 55))
    }

    func testApproximateLocationWinsOverAWeakFixAndAMissingFix() {
        XCTAssertEqual(issue(.authorized, precise: false, hasLocation: true, accuracy: 80, failure: nil), .reducedAccuracy)
        XCTAssertEqual(issue(.authorized, precise: false, hasLocation: false, accuracy: nil, failure: nil), .reducedAccuracy)
        XCTAssertEqual(issue(.authorized, precise: false, hasLocation: true, accuracy: 5, failure: .network), .reducedAccuracy)
    }

    func testWeakPreciseFixesAreReportedAndTheBoundaryStaysUsable() {
        XCTAssertNil(issue(.authorized, precise: true, hasLocation: true, accuracy: weakGPS, failure: nil))
        XCTAssertNil(issue(.authorized, precise: true, hasLocation: true, accuracy: 0, failure: nil))
        XCTAssertNil(issue(.authorized, precise: true, hasLocation: true, accuracy: -1, failure: nil))
        XCTAssertNil(issue(.authorized, precise: true, hasLocation: true, accuracy: .nan, failure: nil))
        XCTAssertEqual(issue(.authorized, precise: true, hasLocation: true, accuracy: weakGPS + 0.1, failure: nil), .poorAccuracy(meters: weakGPS + 0.1))
        XCTAssertEqual(issue(.authorized, precise: true, hasLocation: false, accuracy: 80, failure: nil), .waitingForSignal)
    }

    func testReliableCompassWinsAndCourseRequiresMovement() {
        XCTAssertEqual(HeadingDisplay.maximumReliableAccuracyDegrees, 25)
        XCTAssertEqual(HeadingDisplay.minimumMovingSpeedMetersPerSecond, 0.5)
        XCTAssertEqual(HeadingDisplay.best(trueHeading: 0, magneticHeading: 180), 0)
        XCTAssertEqual(HeadingDisplay.best(trueHeading: nil, magneticHeading: 180), 180)

        XCTAssertTrue(HeadingDisplay.isReliable(accuracy: 0, heading: 12))
        XCTAssertTrue(HeadingDisplay.isReliable(accuracy: 25, heading: 0))
        XCTAssertFalse(HeadingDisplay.isReliable(accuracy: 25.1, heading: 12))
        XCTAssertFalse(HeadingDisplay.isReliable(accuracy: -0.1, heading: 12))
        XCTAssertFalse(HeadingDisplay.isReliable(accuracy: .nan, heading: 12))
        XCTAssertFalse(HeadingDisplay.isReliable(accuracy: .infinity, heading: 12))
        XCTAssertFalse(HeadingDisplay.isReliable(accuracy: 5, heading: .nan))
        XCTAssertFalse(HeadingDisplay.isReliable(accuracy: 5, heading: .infinity))

        XCTAssertEqual(HeadingDisplay.choose(reliableCompass: 20, course: 90, speed: 2), 20)
        XCTAssertEqual(HeadingDisplay.choose(reliableCompass: nil, course: 90, speed: 0.51), 90)
        XCTAssertNil(HeadingDisplay.choose(reliableCompass: nil, course: 90, speed: 0.5))
        XCTAssertNil(HeadingDisplay.choose(reliableCompass: nil, course: 90, speed: 0))
        XCTAssertNil(HeadingDisplay.choose(reliableCompass: nil, course: 90, speed: nil))
        XCTAssertNil(HeadingDisplay.choose(reliableCompass: nil, course: 90, speed: .nan))
        XCTAssertNil(HeadingDisplay.choose(reliableCompass: nil, course: 90, speed: -1))
        XCTAssertEqual(HeadingDisplay.choose(reliableCompass: nil, course: 90, speed: .infinity), 90)
        XCTAssertNil(HeadingDisplay.choose(reliableCompass: nil, course: nil, speed: 3))
        XCTAssertEqual(HeadingDisplay.choose(reliableCompass: nil, course: -1, speed: 1), -1)
    }

    private func issue(
        _ permission: LocationGuidance.Permission,
        precise: Bool,
        hasLocation: Bool,
        accuracy: Double?,
        failure: LocationGuidance.Failure?
    ) -> LocationGuidance.Issue? {
        LocationGuidance.issue(
            permission: permission,
            isPrecise: precise,
            hasLocation: hasLocation,
            horizontalAccuracy: accuracy,
            failure: failure,
            poorAccuracyMeters: weakGPS
        )
    }
}
