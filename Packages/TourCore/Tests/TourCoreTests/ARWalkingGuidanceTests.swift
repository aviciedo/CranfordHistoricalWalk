import XCTest
@testable import TourCore

final class ARWalkingGuidanceTests: XCTestCase {
    func testCameraFacingChangesTheDirectionWithoutChangingTheDestination() throws {
        // The destination stays north. The visitor looks north, east, south and west.
        let cameras: [(Double, Double, Double)] = [(0, -1, 0), (1, 0, -90), (0, 1, -180), (-1, 0, 90)]
        for (x, z, expected) in cameras {
            let result = try XCTUnwrap(ARWalkingGuidance.relativeBearing(directionX: 0, directionZ: -1, cameraForwardX: x, cameraForwardZ: z))
            XCTAssertEqual(abs(result - expected).truncatingRemainder(dividingBy: 360), 0, accuracy: 0.001)
        }
    }

    func testRightAndLeftMatchScreenRotation() throws {
        for (x, expected) in [(1.0, 90.0), (-1.0, -90.0)] {
            let bearing = try XCTUnwrap(ARWalkingGuidance.relativeBearing(directionX: x, directionZ: 0, cameraForwardX: 0, cameraForwardZ: -1))
            XCTAssertEqual(bearing, expected, accuracy: 0.001)
        }
    }

    func testWorldAlignmentRotationDoesNotChangeCameraRelativeGuidance() throws {
        // Rotating both the AR world and camera 90 degrees preserves a right turn.
        let northWorld = try XCTUnwrap(ARWalkingGuidance.relativeBearing(directionX: 1, directionZ: 0, cameraForwardX: 0, cameraForwardZ: -1))
        let rotatedWorld = try XCTUnwrap(ARWalkingGuidance.relativeBearing(directionX: 0, directionZ: 1, cameraForwardX: 1, cameraForwardZ: 0))
        XCTAssertEqual(northWorld, rotatedWorld, accuracy: 0.001)
    }

    func testNorthWrapUsesTheShortTurn() throws {
        func vector(_ degrees: Double) -> (Double, Double) { (sin(degrees * .pi / 180), -cos(degrees * .pi / 180)) }
        let destination = vector(1), camera = vector(359)
        let result = try XCTUnwrap(ARWalkingGuidance.relativeBearing(directionX: destination.0, directionZ: destination.1, cameraForwardX: camera.0, cameraForwardZ: camera.1))
        XCTAssertEqual(result, 2, accuracy: 0.001)
    }

    func testHorizontalProjectionWorksWhenPhoneIsTilted() throws {
        let result = try XCTUnwrap(ARWalkingGuidance.relativeBearing(directionX: 10, directionZ: 0, cameraForwardX: 0, cameraForwardZ: -0.4))
        XCTAssertEqual(result, 90, accuracy: 0.001)
    }

    func testVerticalCameraAndZeroDirectionAreUnavailable() {
        XCTAssertNil(ARWalkingGuidance.relativeBearing(directionX: 0, directionZ: -1, cameraForwardX: 0, cameraForwardZ: 0.1))
        XCTAssertNil(ARWalkingGuidance.relativeBearing(directionX: 0, directionZ: 0, cameraForwardX: 0, cameraForwardZ: -1))
    }

    func testInvalidVectorsNeverBecomeAnArrow() {
        for invalid in [Double.nan, .infinity, -.infinity] {
            XCTAssertNil(ARWalkingGuidance.relativeBearing(directionX: invalid, directionZ: -1, cameraForwardX: 0, cameraForwardZ: -1))
            XCTAssertNil(ARWalkingGuidance.relativeBearing(directionX: 0, directionZ: -1, cameraForwardX: 0, cameraForwardZ: invalid))
        }
    }

    func testInstructionsAndUnknownFacingArePlainLanguage() {
        for (angle, message) in [(0.0, "Walk ahead"), (35, "Bear right"), (-35, "Bear left"), (90, "Turn right"), (-90, "Turn left"), (170, "Turn around")] {
            XCTAssertEqual(ARWalkingGuidance.instruction(for: angle), message)
        }
        XCTAssertEqual(ARWalkingGuidance.instruction(for: nil), "Hold your phone up and look around")
        XCTAssertEqual(ARWalkingGuidance.instruction(for: .nan), "Hold your phone up and look around")
    }
}
