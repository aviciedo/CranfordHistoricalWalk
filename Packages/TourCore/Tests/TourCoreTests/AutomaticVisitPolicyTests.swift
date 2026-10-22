import XCTest
@testable import TourCore

final class AutomaticVisitPolicyTests: XCTestCase {
    private let first = Date(timeIntervalSince1970: 1_800_000_000)
    private let second = Date(timeIntervalSince1970: 1_800_000_005)

    private func evaluate(
        plaque: Bool = false, ar: Bool = false, pinned: Bool = false,
        timestamp: Date? = nil, last: Date? = nil,
        accuracy: Double = 5, distance: Double = 10, radius: Double = 35
    ) -> Date? {
        AutomaticVisitPolicy.evaluationTimestamp(
            hasPlaqueReference: plaque, arSessionActive: ar, discoveryPinnedToThisStop: pinned,
            sampleTimestamp: timestamp ?? first, lastEvaluatedTimestamp: last,
            horizontalAccuracy: accuracy, distanceMeters: distance, arrivalRadius: radius)
    }

    func testAccurateFixIsEligibleOnceAndCannotCascadeIntoTheNextStop() {
        XCTAssertEqual(evaluate(), first)
        XCTAssertNil(evaluate(last: first), "The same stationary fix must not complete the next stop")
        XCTAssertEqual(evaluate(timestamp: second, last: first, distance: 8), second)
        XCTAssertNil(evaluate(timestamp: second, last: first, distance: 40), "A consumed fix's replacement still has to be on site")
    }

    func testPlaqueDiscoveryHoldsWithoutConsumingTheFix() {
        XCTAssertNil(evaluate(plaque: true, ar: true))
        XCTAssertNil(evaluate(plaque: true, pinned: true), "A selected site is held before the camera session starts")
        XCTAssertEqual(evaluate(plaque: true), first, "Map-only GPS still completes a plaque stop")
        XCTAssertEqual(evaluate(ar: true), first, "A stop without a plaque still advances during AR")
    }

    func testHeldFixRemainsEligibleAfterDiscoveryEnds() {
        XCTAssertNil(evaluate(plaque: true, ar: true))
        XCTAssertEqual(evaluate(plaque: true, ar: false, last: nil), first)
    }

    func testUncertaintyMustFitAndWeakFixesAreNotRemembered() {
        XCTAssertEqual(evaluate(accuracy: 25, distance: 10, radius: 35), first)
        XCTAssertNil(evaluate(accuracy: 25.1, distance: 0, radius: 35))
        XCTAssertEqual(evaluate(accuracy: 5, distance: 30, radius: 35), first)
        XCTAssertNil(evaluate(accuracy: 5, distance: 30.1, radius: 35))
        XCTAssertNil(evaluate(accuracy: .nan))
        XCTAssertNil(evaluate(distance: .infinity))
        XCTAssertNil(evaluate(radius: .nan))
    }

    func testNegativeAccuracyStillMatchesTheInnerGate() {
        // The location pipeline rejects negative accuracy before this gate. The gate itself
        // still treats it as eligible so reordering those checks cannot silently drop the fix.
        XCTAssertEqual(evaluate(accuracy: -1, distance: 10, radius: 35), first)
    }
}
