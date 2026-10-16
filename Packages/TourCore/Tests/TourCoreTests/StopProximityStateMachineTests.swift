import XCTest
@testable import TourCore

final class StopProximityStateMachineTests: XCTestCase {
    func testOpensAtArrivalRadius() {
        var sm = StopProximityStateMachine(arrivalRadius: 35, departureRadius: 50)
        XCTAssertEqual(sm.handle(.distanceUpdated(meters: 80)), [])
        XCTAssertEqual(sm.state, .approaching)
        XCTAssertEqual(sm.handle(.distanceUpdated(meters: 35)), [.presentSign])
        XCTAssertEqual(sm.state, .signPresented)
        XCTAssertTrue(sm.hasPresentedSign)
    }

    func testHysteresisPreventsFlappingOnBoundary() {
        var sm = StopProximityStateMachine(arrivalRadius: 35, departureRadius: 50)
        sm.handle(.distanceUpdated(meters: 34))
        XCTAssertEqual(sm.state, .signPresented)
        // Hovering between 35 and 50 m must not close.
        for d in [36.0, 40, 45, 49.9, 38, 36] {
            XCTAssertEqual(sm.handle(.distanceUpdated(meters: d)), [], "no effect at \(d) m")
            XCTAssertEqual(sm.state, .signPresented)
        }
        XCTAssertEqual(sm.handle(.distanceUpdated(meters: 50.1)), [.dismissSign])
        XCTAssertEqual(sm.state, .signDismissed)
        // Coming back inside 50 but outside 35 must not reopen.
        XCTAssertEqual(sm.handle(.distanceUpdated(meters: 45)), [])
        XCTAssertEqual(sm.state, .signDismissed)
    }

    func testReopensAfterLeavingAndReturning() {
        var sm = StopProximityStateMachine(arrivalRadius: 35, departureRadius: 50)
        sm.handle(.distanceUpdated(meters: 20))
        sm.handle(.distanceUpdated(meters: 60))
        XCTAssertEqual(sm.state, .signDismissed)
        sm.handle(.distanceUpdated(meters: 70))
        XCTAssertEqual(sm.state, .approaching)
        XCTAssertEqual(sm.handle(.distanceUpdated(meters: 30)), [.presentSign])
    }

    func testManualCloseStaysClosedWhileInsideRadius() {
        var sm = StopProximityStateMachine(arrivalRadius: 35, departureRadius: 50)
        sm.handle(.distanceUpdated(meters: 10))
        XCTAssertEqual(sm.handle(.userClosedSign), [.dismissSign])
        XCTAssertEqual(sm.state, .signDismissed)
        XCTAssertTrue(sm.hasManuallyDismissed)
        // Still standing at the site: must not auto-reopen.
        XCTAssertEqual(sm.handle(.distanceUpdated(meters: 5)), [])
        XCTAssertEqual(sm.handle(.distanceUpdated(meters: 30)), [])
        XCTAssertEqual(sm.state, .signDismissed)
        // User can reopen manually.
        XCTAssertEqual(sm.handle(.userOpenedSign), [.presentSign])
        XCTAssertFalse(sm.hasManuallyDismissed)
    }

    func testManualOpenFromFarAwayDoesNotDismissUntilArrivalThenLeave() {
        var sm = StopProximityStateMachine(arrivalRadius: 35, departureRadius: 50)
        sm.handle(.distanceUpdated(meters: 500))
        XCTAssertEqual(sm.handle(.userOpenedSign), [.presentSign])
        XCTAssertEqual(sm.state, .signPresented)
        XCTAssertTrue(sm.suppressesAutoDeparture)
        // Still outside (plaque vs an unverified geocode, or the same far fix again).
        // This must not count as walking away.
        XCTAssertEqual(sm.handle(.distanceUpdated(meters: 500)), [])
        XCTAssertEqual(sm.handle(.distanceUpdated(meters: 80)), [])
        XCTAssertEqual(sm.state, .signPresented)
        // A fix inside the arrival radius arms normal hysteresis.
        XCTAssertEqual(sm.handle(.distanceUpdated(meters: 20)), [])
        XCTAssertFalse(sm.suppressesAutoDeparture)
        XCTAssertEqual(sm.state, .signPresented)
        XCTAssertEqual(sm.handle(.distanceUpdated(meters: 42)), [])
        XCTAssertEqual(sm.handle(.distanceUpdated(meters: 60)), [.dismissSign])
        XCTAssertEqual(sm.state, .signDismissed)
    }

    func testManualOpenBeforeAnyFixWaitsForArrival() {
        var sm = StopProximityStateMachine(arrivalRadius: 35, departureRadius: 50)
        XCTAssertEqual(sm.handle(.userOpenedSign), [.presentSign])
        XCTAssertTrue(sm.suppressesAutoDeparture)
        XCTAssertEqual(sm.handle(.distanceUpdated(meters: 120)), [])
        XCTAssertEqual(sm.state, .signPresented)
        XCTAssertEqual(sm.handle(.distanceUpdated(meters: 10)), [])
        XCTAssertFalse(sm.suppressesAutoDeparture)
    }

    func testCompletionIsTerminal() {
        var sm = StopProximityStateMachine(arrivalRadius: 35, departureRadius: 50)
        sm.handle(.distanceUpdated(meters: 10))
        XCTAssertEqual(sm.handle(.markCompleted), [.dismissSign, .stopCompleted])
        XCTAssertEqual(sm.state, .completed)
        XCTAssertEqual(sm.handle(.distanceUpdated(meters: 5)), [])
        XCTAssertEqual(sm.handle(.userOpenedSign), [])
        XCTAssertEqual(sm.handle(.markCompleted), [])
        XCTAssertEqual(sm.state, .completed)
    }

    func testCompletionWithoutPresentedSign() {
        var sm = StopProximityStateMachine(arrivalRadius: 35, departureRadius: 50)
        XCTAssertEqual(sm.handle(.markCompleted), [.stopCompleted])
    }

    func testNearbyStateUsedWhenPresentationDeferred() {
        var sm = StopProximityStateMachine(arrivalRadius: 35, departureRadius: 50, state: .nearby)
        XCTAssertEqual(sm.handle(.distanceUpdated(meters: 40)), [])
        XCTAssertEqual(sm.state, .nearby)
        XCTAssertEqual(sm.handle(.signWasPresented), [])
        XCTAssertEqual(sm.state, .signPresented)
        var sm2 = StopProximityStateMachine(arrivalRadius: 35, departureRadius: 50, state: .nearby)
        sm2.handle(.distanceUpdated(meters: 55))
        XCTAssertEqual(sm2.state, .approaching)
    }

    func testResetReturnsToInitial() {
        var sm = StopProximityStateMachine(arrivalRadius: 35, departureRadius: 50)
        sm.handle(.distanceUpdated(meters: 10))
        sm.handle(.userClosedSign)
        sm.handle(.reset)
        XCTAssertEqual(sm, StopProximityStateMachine(arrivalRadius: 35, departureRadius: 50))
    }

    func testInitFromStopUsesEffectiveDepartureRadius() {
        let sm = StopProximityStateMachine(stop: makeStop(arrival: 35, departure: nil))
        XCTAssertEqual(sm.arrivalRadius, 35)
        XCTAssertEqual(sm.departureRadius, 50)
    }
}
