import XCTest
@testable import TourCore

final class WalkSimulatorTests: XCTestCase {
    func testStepsTowardTargetAtConfiguredSpeed() {
        let sim = WalkSimulator(metersPerSecond: 2)
        let target = GeoMath.destination(from: cranfordCenter, bearing: 90, distance: 100)
        let s = sim.step(from: cranfordCenter, toward: target, deltaTime: 5)
        XCTAssertFalse(s.didArrive)
        XCTAssertEqual(GeoMath.distance(from: cranfordCenter, to: s.coordinate), 10, accuracy: 0.01)
        XCTAssertEqual(s.course ?? -1, 90, accuracy: 0.1)
    }

    func testArrivesExactlyWithoutOvershoot() {
        let sim = WalkSimulator(metersPerSecond: 1.4)
        let target = GeoMath.destination(from: cranfordCenter, bearing: 45, distance: 5)
        let s = sim.step(from: cranfordCenter, toward: target, deltaTime: 60)
        XCTAssertTrue(s.didArrive)
        XCTAssertEqual(s.coordinate, target)
        let again = sim.step(from: target, toward: target, deltaTime: 1)
        XCTAssertTrue(again.didArrive)
        XCTAssertNil(again.course)
    }

    func testFollowsPolylineCorners() {
        let start = cranfordCenter
        let corner = GeoMath.destination(from: start, bearing: 90, distance: 100)
        let end = GeoMath.destination(from: corner, bearing: 0, distance: 100)
        let sim = WalkSimulator(metersPerSecond: 10)
        // 15 s * 10 m/s = 150 m: 100 m east to the corner then 50 m north.
        let s = sim.step(from: start, along: [start, corner, end], toward: end, deltaTime: 15)
        let expected = GeoMath.destination(from: corner, bearing: 0, distance: 50)
        XCTAssertEqual(GeoMath.distance(from: s.coordinate, to: expected), 0, accuracy: 0.05)
        XCTAssertEqual(s.course ?? -1, 0, accuracy: 0.1)
        XCTAssertFalse(s.didArrive)

        let finished = sim.step(from: s.coordinate, along: [start, corner, end], toward: end, deltaTime: 100)
        XCTAssertTrue(finished.didArrive)
        XCTAssertEqual(finished.coordinate, end)
    }

    func testSimulatedWalkEventuallyTriggersArrivalRadius() {
        let stop = makeStop(lat: 40.6600, lng: -74.2990)
        var sm = StopProximityStateMachine(stop: stop)
        var pos = cranfordCenter
        let sim = WalkSimulator(metersPerSecond: 1.4)
        var presented = false
        for _ in 0..<2000 {
            pos = sim.step(from: pos, toward: stop.coordinate, deltaTime: 1).coordinate
            let d = GeoMath.distance(from: pos, to: stop.coordinate)
            if sm.handle(.distanceUpdated(meters: d)).contains(.presentSign) {
                presented = true
                XCTAssertLessThanOrEqual(d, stop.arrivalRadius)
                break
            }
        }
        XCTAssertTrue(presented)
    }
}
