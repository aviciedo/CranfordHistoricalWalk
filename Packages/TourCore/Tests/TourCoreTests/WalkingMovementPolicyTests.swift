import XCTest
@testable import TourCore

final class WalkingMovementPolicyTests: XCTestCase {
    let origin = GeoCoordinate(latitude: 40.65, longitude: -74.3)
    let time = Date(timeIntervalSince1970: 1000)
    func point(_ meters: Double) -> GeoCoordinate { GeoMath.destination(from: origin, bearing: 0, distance: meters) }
    func fix(_ policy: inout WalkingMovementPolicy, _ meters: Double, _ sec: Double,
             accuracy: Double = 3, speed: Double? = nil, allowed: Bool = true) -> WalkingMovementPolicy.Update {
        policy.update(coordinate: point(meters), accuracy: accuracy, timestamp: time.addingTimeInterval(sec),
            speed: speed, recordingAllowed: allowed, now: time.addingTimeInterval(sec))
    }
    func testJitterJumpRecoveryAndRealBacktracking() {
        var policy = WalkingMovementPolicy()
        XCTAssertEqual(fix(&policy, 0, 0), .started)
        XCTAssertEqual(fix(&policy, 1, 1), .ignored)
        guard case .advanced(let forward) = fix(&policy, 3, 2) else { return XCTFail("Real movement lost") }
        XCTAssertEqual(forward, 3, accuracy: 0.01)
        XCTAssertEqual(fix(&policy, 225, 3), .started)
        XCTAssertEqual(fix(&policy, 3, 4), .started)
        guard case .advanced(let back) = fix(&policy, 0, 6) else { return XCTFail("Backtracking must count") }
        XCTAssertEqual(back, 3, accuracy: 0.01)
    }
    func testGapsWeakSignalsAndPauseNeverConnectSegments() {
        var policy = WalkingMovementPolicy()
        XCTAssertEqual(fix(&policy, 0, 0), .started)
        XCTAssertEqual(fix(&policy, 3, 11), .started)
        XCTAssertEqual(fix(&policy, 4, 12, accuracy: 26), .interrupted)
        XCTAssertEqual(fix(&policy, 5, 13), .started)
        XCTAssertEqual(fix(&policy, 6, 14, allowed: false), .interrupted)
        XCTAssertEqual(fix(&policy, 7, 15), .started)
        XCTAssertEqual(fix(&policy, 9, 16, speed: 5), .interrupted)
    }
    func testTenSecondsTwoMetersAndFourMetersPerSecondAreClosed() {
        let justUnder = point(1.5)
        XCTAssertLessThan(GeoMath.distance(from: origin, to: justUnder), 2)
        var short = WalkingMovementPolicy()
        XCTAssertEqual(fix(&short, 0, 0), .started)
        XCTAssertEqual(short.update(coordinate: justUnder, accuracy: 3, timestamp: time.addingTimeInterval(1),
            now: time.addingTimeInterval(1)), .ignored)

        let step = point(2.01)
        let twoMeters = GeoMath.distance(from: origin, to: step)
        XCTAssertGreaterThanOrEqual(twoMeters, 2)
        XCTAssertLessThan(twoMeters, 2.02)
        var continued = WalkingMovementPolicy()
        XCTAssertEqual(fix(&continued, 0, 0), .started)
        guard case .advanced(let held) = continued.update(coordinate: step, accuracy: 3,
            timestamp: time.addingTimeInterval(10), now: time.addingTimeInterval(10)) else {
            return XCTFail("A step of at least 2 m at exactly 10 s still belongs to this segment")
        }
        XCTAssertEqual(held, twoMeters, accuracy: 0.001)

        var gap = WalkingMovementPolicy()
        XCTAssertEqual(fix(&gap, 0, 0), .started)
        XCTAssertEqual(gap.update(coordinate: step, accuracy: 3, timestamp: time.addingTimeInterval(10.0001),
            now: time.addingTimeInterval(10.0001)), .started)

        let forty = GeoMath.distance(from: origin, to: point(40))
        let atLimit = forty / 4
        var pace = WalkingMovementPolicy()
        XCTAssertEqual(fix(&pace, 0, 0), .started)
        guard case .advanced(let walking) = pace.update(coordinate: point(40), accuracy: 3,
            timestamp: time.addingTimeInterval(atLimit), now: time.addingTimeInterval(atLimit)) else {
            return XCTFail("Exactly 4 m/s still continues the segment")
        }
        XCTAssertEqual(walking, forty, accuracy: 0.001)

        var running = WalkingMovementPolicy()
        XCTAssertEqual(fix(&running, 0, 0), .started)
        let tooFast = forty / 4.0001
        XCTAssertEqual(running.update(coordinate: point(40), accuracy: 3, timestamp: time.addingTimeInterval(tooFast),
            now: time.addingTimeInterval(tooFast)), .started)

        var jitter = WalkingMovementPolicy()
        XCTAssertEqual(fix(&jitter, 0, 0), .started)
        XCTAssertEqual(fix(&jitter, 1.5, 1), .ignored)
        guard case .advanced(let fromAnchor) = fix(&jitter, 4, 2) else { return XCTFail("Jitter must not become the anchor") }
        XCTAssertEqual(fromAnchor, GeoMath.distance(from: origin, to: point(4)), accuracy: 0.02)
    }

    func testFreshnessAccuracyAndReportedSpeedUseClosedLimits() {
        func sample(_ policy: inout WalkingMovementPolicy, age: Double, speed: Double? = nil,
                    accuracy: Double = 3, latitude: Double = origin.latitude) -> WalkingMovementPolicy.Update {
            policy.update(coordinate: GeoCoordinate(latitude: latitude, longitude: origin.longitude),
                accuracy: accuracy, timestamp: time, speed: speed, now: time.addingTimeInterval(age))
        }
        var policy = WalkingMovementPolicy()
        XCTAssertEqual(sample(&policy, age: -5), .started)
        policy.reset()
        XCTAssertEqual(sample(&policy, age: -5.001), .interrupted)
        policy.reset()
        XCTAssertEqual(sample(&policy, age: 29.999), .started)
        policy.reset()
        XCTAssertEqual(sample(&policy, age: 30), .interrupted)
        policy.reset()
        XCTAssertEqual(sample(&policy, age: 0, speed: 0), .started)
        policy.reset()
        XCTAssertEqual(sample(&policy, age: 0, speed: 4), .started)
        policy.reset()
        XCTAssertEqual(sample(&policy, age: 0, speed: 4.0001), .interrupted)
        policy.reset()
        XCTAssertEqual(sample(&policy, age: 0, speed: -0.01), .interrupted)
        policy.reset()
        XCTAssertEqual(sample(&policy, age: 0, speed: .nan), .interrupted)
        policy.reset()
        XCTAssertEqual(sample(&policy, age: 0, speed: .infinity), .interrupted)
        policy.reset()
        XCTAssertEqual(sample(&policy, age: 0, accuracy: 0), .started)
        policy.reset()
        XCTAssertEqual(sample(&policy, age: 0, accuracy: 25), .started)
        policy.reset()
        XCTAssertEqual(sample(&policy, age: 0, accuracy: 25.0001), .interrupted)
        policy.reset()
        XCTAssertEqual(sample(&policy, age: 0, accuracy: -0.01), .interrupted)
        policy.reset()
        XCTAssertEqual(sample(&policy, age: 0, latitude: 91), .interrupted)

        var broken = WalkingMovementPolicy()
        XCTAssertEqual(fix(&broken, 0, 0), .started)
        XCTAssertEqual(fix(&broken, 10, 2, accuracy: 26), .interrupted)
        XCTAssertEqual(fix(&broken, 12, 3), .started)
        guard case .advanced(let resumed) = fix(&broken, 16, 4) else { return XCTFail("The new segment must start after the gap") }
        XCTAssertEqual(resumed, GeoMath.distance(from: point(12), to: point(16)), accuracy: 0.02)
    }

    func testDuplicateAndOutOfOrderFixesDoNotMoveAnchor() {
        var policy = WalkingMovementPolicy()
        XCTAssertEqual(fix(&policy, 0, 0), .started)
        XCTAssertEqual(fix(&policy, 40, 0), .ignored)
        XCTAssertEqual(fix(&policy, 40, -1), .ignored)
        guard case .advanced(let distance) = fix(&policy, 3, 2) else { return XCTFail() }
        XCTAssertEqual(distance, 3, accuracy: 0.01)
    }
}
