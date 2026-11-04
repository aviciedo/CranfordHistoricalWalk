import XCTest
@testable import TourCore

final class GroundPlaneSelectionTests: XCTestCase {
    private let cameraY: Float = 2

    func testEligibleFloorIsTakenAndFurnitureCeilingOrVerticalPlanesAreNot() {
        let floor = plane(center: [0, 1, 0])
        XCTAssertEqual(GroundPlaneSelection.chosenCenter([floor], cameraY: cameraY), floor.center)
        for rejected in [GroundSurfaceKind.table, .seat, .ceiling] {
            XCTAssertNil(GroundPlaneSelection.chosenCenter([plane(center: [0, 1, 0], kind: rejected)], cameraY: cameraY))
        }
        for accepted in [GroundSurfaceKind.floor, .none, .unknown, .wall, .window, .door] {
            XCTAssertNotNil(GroundPlaneSelection.chosenCenter([plane(center: [0, 1, 0], kind: accepted)], cameraY: cameraY))
        }
        XCTAssertNil(GroundPlaneSelection.chosenCenter([plane(center: [0, 1, 0], horizontal: false)], cameraY: cameraY))
        XCTAssertNil(GroundPlaneSelection.chosenCenter([], cameraY: cameraY))
    }

    func testAreaClearanceAndDistanceUseClosedBounds() {
        let area = GroundPlaneSelection.minimumArea
        XCTAssertNil(GroundPlaneSelection.chosenCenter([plane(center: [0, 1, 0], area: area - 0.001)], cameraY: cameraY))
        XCTAssertNotNil(GroundPlaneSelection.chosenCenter([plane(center: [0, 1, 0], area: area)], cameraY: cameraY))

        let minimum = GroundPlaneSelection.minimumClearanceBelowCamera
        XCTAssertNil(GroundPlaneSelection.chosenCenter([plane(center: .zero)], cameraY: minimum),
                     "Exactly 0.45 m below the camera is still too close")
        XCTAssertNotNil(GroundPlaneSelection.chosenCenter([plane(center: .zero)], cameraY: minimum + 0.001))

        let maximum = GroundPlaneSelection.maximumClearanceBelowCamera
        XCTAssertNil(GroundPlaneSelection.chosenCenter([plane(center: .zero)], cameraY: maximum),
                     "Exactly 2.5 m below the camera is out of reach")
        XCTAssertNotNil(GroundPlaneSelection.chosenCenter([plane(center: .zero)], cameraY: maximum - 0.001))

        let limit = GroundPlaneSelection.maximumHorizontalDistance
        XCTAssertNil(GroundPlaneSelection.chosenCenter([plane(center: [0, 1, 0], distance: limit)], cameraY: cameraY))
        XCTAssertNotNil(GroundPlaneSelection.chosenCenter([plane(center: [0, 1, 0], distance: limit - 0.001)], cameraY: cameraY))
        XCTAssertNil(GroundPlaneSelection.chosenCenter([plane(center: [0, 1, 0], distance: .nan)], cameraY: cameraY))
        XCTAssertNil(GroundPlaneSelection.chosenCenter([plane(center: [0, 1, 0], area: .nan)], cameraY: cameraY))
        XCTAssertNil(GroundPlaneSelection.chosenCenter([plane(center: [0, .nan, 0])], cameraY: cameraY))
    }

    func testCloserEligiblePlaneWinsAndAnEqualDistanceKeepsTheEarlierSample() {
        let near = SIMD3<Float>(1, 1, 0)
        let far = SIMD3<Float>(4, 1, 0)
        let tied = SIMD3<Float>(-1, 1, 0)
        XCTAssertEqual(GroundPlaneSelection.chosenCenter([
            plane(center: far, kind: .floor, distance: 4), plane(center: near, kind: .none, distance: 1)
        ], cameraY: cameraY), near)
        XCTAssertEqual(GroundPlaneSelection.chosenCenter([
            plane(center: near, distance: 1), plane(center: tied, distance: 1)
        ], cameraY: cameraY), near)
        XCTAssertEqual(GroundPlaneSelection.chosenCenter([
            plane(center: near, kind: .table, distance: 1), plane(center: far, kind: .floor, distance: 4)
        ], cameraY: cameraY), far)
    }

    func testHeightAdoptsTheFirstSampleThenMovesTwelvePercent() {
        XCTAssertEqual(GroundPlaneSelection.updatedHeight(previous: nil, measuredY: 1.25), 1.25)
        let blended = GroundPlaneSelection.updatedHeight(previous: 1, measuredY: 2)
        XCTAssertEqual(blended, 1 + GroundPlaneSelection.heightSmoothing, accuracy: 0.00001)
    }

    func testRaycastSuppliesHeightWithoutSlidingOntoFurniture() {
        let floor = GroundPlaneSelection.raycastChoice(classification: .floor, hitHeight: 1, groundHeight: 1)
        XCTAssertEqual(floor, .init(height: 1, isVerifiedFloor: true))
        for unverified in [GroundSurfaceKind.none, .unknown, .wall, .window, .door] {
            XCTAssertEqual(GroundPlaneSelection.raycastChoice(classification: unverified, hitHeight: 1.1, groundHeight: 1),
                           .init(height: 1.1, isVerifiedFloor: false))
        }
        for ignored in [GroundSurfaceKind.table, .seat, .ceiling] {
            XCTAssertNil(GroundPlaneSelection.raycastChoice(classification: ignored, hitHeight: 1, groundHeight: 1))
        }
        let tolerance = GroundPlaneSelection.raycastHeightTolerance
        XCTAssertNil(GroundPlaneSelection.raycastChoice(classification: .floor, hitHeight: 1 + tolerance, groundHeight: 1))
        XCTAssertNil(GroundPlaneSelection.raycastChoice(classification: .floor, hitHeight: 1 - tolerance, groundHeight: 1))
        XCTAssertEqual(GroundPlaneSelection.raycastChoice(classification: .floor,
            hitHeight: 1 + tolerance - 0.001, groundHeight: 1)?.isVerifiedFloor, true)
        XCTAssertNil(GroundPlaneSelection.raycastChoice(classification: .floor, hitHeight: .nan, groundHeight: 1))
        XCTAssertNil(GroundPlaneSelection.raycastChoice(classification: .floor, hitHeight: .infinity, groundHeight: 1))
    }

    private func plane(center: SIMD3<Float>, area: Float = 1, horizontal: Bool = true,
                       kind: GroundSurfaceKind = .floor, distance: Float = 1) -> GroundPlaneSelection.Observation {
        .init(center: center, area: area, isHorizontal: horizontal, classification: kind, horizontalDistance: distance)
    }
}
