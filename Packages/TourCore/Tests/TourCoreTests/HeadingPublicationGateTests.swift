import XCTest
@testable import TourCore

final class HeadingPublicationGateTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 5_000)

    func testReliableHeadingsPublishAtFiveHertzAndUnreliableOnesResetTheClock() {
        var gate = HeadingPublicationGate()
        XCTAssertTrue(gate.shouldPublish(isReliable: true, timestamp: start))
        XCTAssertFalse(gate.shouldPublish(isReliable: true, timestamp: start.addingTimeInterval(0.199)))
        XCTAssertEqual(gate.lastPublication, start, "A dropped sample must not move the 5 Hz clock")
        XCTAssertTrue(gate.shouldPublish(isReliable: true, timestamp: start.addingTimeInterval(0.2)))

        let unreliable = start.addingTimeInterval(0.25)
        XCTAssertTrue(gate.shouldPublish(isReliable: false, timestamp: unreliable))
        XCTAssertFalse(gate.shouldPublish(isReliable: true, timestamp: unreliable.addingTimeInterval(0.199)))
        XCTAssertTrue(gate.shouldPublish(isReliable: false, timestamp: unreliable.addingTimeInterval(0.05)))

        gate.reset()
        XCTAssertNil(gate.lastPublication)
        XCTAssertTrue(gate.shouldPublish(isReliable: true, timestamp: unreliable.addingTimeInterval(0.1)))
    }

    func testEarlierReliableHeadingDoesNotPublishOverANewerOne() {
        var gate = HeadingPublicationGate()
        XCTAssertTrue(gate.shouldPublish(isReliable: true, timestamp: start))
        XCTAssertFalse(gate.shouldPublish(isReliable: true, timestamp: start.addingTimeInterval(-0.01)))
        XCTAssertEqual(gate.lastPublication, start)
    }
}
