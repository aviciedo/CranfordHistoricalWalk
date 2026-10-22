import XCTest
@testable import TourCore

final class PhoneDownReturnPolicyTests: XCTestCase {
    private let opened = Date(timeIntervalSince1970: 1_800_000_000)

    private func sample(_ state: inout PhoneDownReturnState, x: Double = 0, y: Double = 0, z: Double,
                        leaving: Bool = false, at time: Date) -> Bool {
        PhoneDownReturnPolicy.shouldReturnToMap(&state, x: x, y: y, z: z, isLeaving: leaving, now: time)
    }

    func testOpeningAlreadyFlatDoesNotLeaveOrStartTheHold() {
        var state = PhoneDownReturnState()
        for second in 0...5 {
            XCTAssertFalse(sample(&state, z: -1, at: opened.addingTimeInterval(TimeInterval(second))))
        }
        XCTAssertFalse(state.phoneWasRaised)
        XCTAssertNil(state.horizontalSince)
    }

    func testRaisedPhoneThenLevelScreenUpLeavesAtExactlyTwoSeconds() {
        var state = PhoneDownReturnState()
        XCTAssertFalse(sample(&state, z: 0, at: opened))
        XCTAssertTrue(state.phoneWasRaised)
        XCTAssertFalse(sample(&state, z: -0.95, at: opened))
        XCTAssertEqual(state.horizontalSince, opened)
        XCTAssertFalse(sample(&state, z: -0.95, at: opened.addingTimeInterval(1.999)))
        XCTAssertTrue(sample(&state, z: -0.95, at: opened.addingTimeInterval(2)))
    }

    func testLiftingDuringTheHoldRestartsTheFullTwoSeconds() {
        var state = PhoneDownReturnState()
        XCTAssertFalse(sample(&state, z: -0.2, at: opened))
        XCTAssertFalse(sample(&state, z: -1, at: opened))
        XCTAssertFalse(sample(&state, z: 0.2, at: opened.addingTimeInterval(1.5)))
        XCTAssertNil(state.horizontalSince)
        let again = opened.addingTimeInterval(1.5)
        XCTAssertFalse(sample(&state, z: -1, at: again))
        XCTAssertFalse(sample(&state, z: -1, at: again.addingTimeInterval(1.999)))
        XCTAssertTrue(sample(&state, z: -1, at: again.addingTimeInterval(2)))
    }

    func testBoundariesRequireStrictlyLevelScreenUpAfterARaisedPhone() {
        var state = PhoneDownReturnState()
        XCTAssertFalse(sample(&state, z: 0.699, at: opened))
        XCTAssertTrue(state.phoneWasRaised)
        XCTAssertFalse(sample(&state, z: -0.92, at: opened), "Exactly -0.92 is not screen-up")
        XCTAssertNil(state.horizontalSince)
        XCTAssertFalse(sample(&state, x: 0.35, z: -0.95, at: opened))
        XCTAssertFalse(sample(&state, y: -0.35, z: -0.95, at: opened))
        XCTAssertNil(state.horizontalSince)
        XCTAssertFalse(sample(&state, x: 0.349, y: -0.349, z: -0.920001, at: opened))
        XCTAssertEqual(state.horizontalSince, opened)

        state = PhoneDownReturnState()
        XCTAssertFalse(sample(&state, z: 0.70, at: opened), "Exactly 0.70 has not counted as raised")
        XCTAssertFalse(state.phoneWasRaised)
        XCTAssertFalse(sample(&state, z: -1, at: opened.addingTimeInterval(3)))
        XCTAssertFalse(state.phoneWasRaised)
    }

    func testTiltClearsTheHoldAndLeavingIgnoresMotion() {
        var state = PhoneDownReturnState()
        XCTAssertFalse(sample(&state, z: 0, at: opened))
        XCTAssertFalse(sample(&state, z: -1, at: opened))
        XCTAssertFalse(sample(&state, z: -0.8, at: opened.addingTimeInterval(1)))
        XCTAssertNil(state.horizontalSince)

        XCTAssertFalse(sample(&state, z: -1, at: opened.addingTimeInterval(1)))
        let snapshot = state
        XCTAssertFalse(sample(&state, z: 0, leaving: true, at: opened.addingTimeInterval(4)))
        XCTAssertEqual(state, snapshot)
        XCTAssertFalse(sample(&state, z: -1, leaving: true, at: opened.addingTimeInterval(8)))
        XCTAssertEqual(state, snapshot)
    }

    func testNonfiniteGravityClearsTheHoldWithoutLeaving() {
        var state = PhoneDownReturnState()
        XCTAssertFalse(sample(&state, z: 0, at: opened))
        XCTAssertFalse(sample(&state, z: -1, at: opened))
        XCTAssertFalse(sample(&state, z: .nan, at: opened.addingTimeInterval(3)))
        XCTAssertNil(state.horizontalSince)
        XCTAssertTrue(state.phoneWasRaised)
    }
}
