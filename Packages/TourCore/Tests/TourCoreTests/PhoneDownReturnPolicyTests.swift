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
}
