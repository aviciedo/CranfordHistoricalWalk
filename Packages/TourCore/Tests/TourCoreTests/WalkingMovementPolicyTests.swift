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
    func testDuplicateAndOutOfOrderFixesDoNotMoveAnchor() {
        var policy = WalkingMovementPolicy()
        XCTAssertEqual(fix(&policy, 0, 0), .started)
        XCTAssertEqual(fix(&policy, 40, 0), .ignored)
        XCTAssertEqual(fix(&policy, 40, -1), .ignored)
        guard case .advanced(let distance) = fix(&policy, 3, 2) else { return XCTFail() }
        XCTAssertEqual(distance, 3, accuracy: 0.01)
    }
}
