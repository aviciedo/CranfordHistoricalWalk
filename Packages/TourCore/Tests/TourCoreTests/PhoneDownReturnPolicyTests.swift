import XCTest
@testable import TourCore

final class PhoneDownReturnPolicyTests: XCTestCase {
    func testOpeningFlatDoesNotExitAndRaisedContinuousHoldDoes() {
        var policy = PhoneDownReturnPolicy()
        for i in 0...20 { XCTAssertFalse(policy.update(x: 0,y: 0,z: -1,timestamp: Double(i) * 0.2)) }
        XCTAssertFalse(policy.update(x: 0,y: -1,z: 0,timestamp: 5))
        for i in 0..<10 { XCTAssertFalse(policy.update(x: 0,y: 0,z: -1,timestamp: 6 + Double(i) * 0.2)) }
        XCTAssertTrue(policy.update(x: 0,y: 0,z: -1,timestamp: 8))
    }
    func testGapModalInvalidSampleAndResetBreakHold() {
        for mode in 0..<4 {
            var policy = PhoneDownReturnPolicy()
            _ = policy.update(x: 0,y: -1,z: 0,timestamp: 1)
            _ = policy.update(x: 0,y: 0,z: -1,timestamp: 1.2)
            switch mode {
            case 0: _ = policy.update(x: 0,y: 0,z: -1,timestamp: 10)
            case 1: _ = policy.update(x: 0,y: 0,z: -1,timestamp: 1.4,suspended: true)
            case 2: _ = policy.update(x: .nan,y: 0,z: -1,timestamp: 1.4)
            default: policy.reset()
            }
            XCTAssertFalse(policy.update(x: 0,y: 0,z: -1,timestamp: 10.2))
        }
    }

    func testInterruptedHoldRestartsAndFaceDownOrTiltCannotExit() {
        var gapped = PhoneDownReturnPolicy()
        XCTAssertFalse(gapped.update(x: 0, y: -1, z: 0, timestamp: 1))
        XCTAssertFalse(gapped.update(x: 0, y: 0, z: -1, timestamp: 2))
        XCTAssertFalse(gapped.update(x: 0, y: 0, z: -1, timestamp: 4), "A motion gap must not finish the original hold")
        for i in 1...9 {
            XCTAssertFalse(gapped.update(x: 0, y: 0, z: -1, timestamp: 4 + Double(i) * 0.2))
        }
        XCTAssertTrue(gapped.update(x: 0, y: 0, z: -1, timestamp: 6))

        var backwards = PhoneDownReturnPolicy()
        XCTAssertFalse(backwards.update(x: 0, y: -1, z: 0, timestamp: 10))
        XCTAssertFalse(backwards.update(x: 0, y: 0, z: -1, timestamp: 10.2))
        XCTAssertFalse(backwards.update(x: 0, y: 0, z: -1, timestamp: 8))
        for i in 1...9 {
            XCTAssertFalse(backwards.update(x: 0, y: 0, z: -1, timestamp: 8 + Double(i) * 0.2))
        }
        XCTAssertTrue(backwards.update(x: 0, y: 0, z: -1, timestamp: 10))

        var suspended = PhoneDownReturnPolicy()
        XCTAssertFalse(suspended.update(x: 0, y: -1, z: 0, timestamp: 1))
        XCTAssertFalse(suspended.update(x: 0, y: 0, z: -1, timestamp: 1.2))
        XCTAssertFalse(suspended.update(x: 0, y: 0, z: -1, timestamp: 1.4, suspended: true))
        XCTAssertFalse(suspended.update(x: 0, y: 0, z: -1, timestamp: 2))
        for i in 1...9 {
            XCTAssertFalse(suspended.update(x: 0, y: 0, z: -1, timestamp: 2 + Double(i) * 0.2))
        }
        XCTAssertTrue(suspended.update(x: 0, y: 0, z: -1, timestamp: 4))

        for sample in [(x: 0.0, y: 0.0, z: 1.0), (x: 0.35, y: 0.0, z: -1.0), (x: 0.0, y: 0.0, z: -0.92)] {
            var policy = PhoneDownReturnPolicy()
            XCTAssertFalse(policy.update(x: 0, y: -1, z: 0, timestamp: 1))
            for i in 0...20 {
                XCTAssertFalse(policy.update(x: sample.x, y: sample.y, z: sample.z, timestamp: 1.2 + Double(i) * 0.2))
            }
        }
    }
}
