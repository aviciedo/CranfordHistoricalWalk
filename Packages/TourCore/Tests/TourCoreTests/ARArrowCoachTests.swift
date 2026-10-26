import XCTest
@testable import TourCore

final class ARArrowCoachTests: XCTestCase {
    func testActivatedStopSilencesTrackingCoach() {
        XCTAssertEqual(ARArrowCoach.trackingNotice(hasActivatedStop: false),
                       "AR tracking is not ready. Hold still and slowly scan your surroundings.")
        XCTAssertNil(ARArrowCoach.trackingNotice(hasActivatedStop: true))
    }

    func testHiddenArrowReasonsStayExplicit() {
        XCTAssertEqual(ARArrowCoach.needsRoute, "Walking arrows need a walking route and a fresh location. Use the map or retry directions.")
        XCTAssertEqual(ARArrowCoach.waitingForAlignment, "Waiting for accurate location and compass alignment. Use the map while AR aligns.")
        XCTAssertEqual(ARArrowCoach.noDirection, "No walking direction is available. Return to the map to check your route.")
        XCTAssertEqual(ARArrowCoach.arrowsCouldNotLoad, "The AR arrows could not load. Return to the map for directions.")
        XCTAssertEqual(ARArrowCoach.noRoutePosition, "No nearby route position is available. Check your location on the map.")
        XCTAssertEqual(ARArrowCoach.unableToPlace, "Unable to place walking arrows. Scan the pavement or return to the map.")
    }

    func testVisibleSignClearsTheCoachEvenWhenTheBearingIsLarge() {
        XCTAssertNil(ARArrowCoach.screenNotice(canProjectPlacement: true, isInFront: true, isOnScreen: true,
                                              relativeBearing: 90))
        XCTAssertNil(ARArrowCoach.screenNotice(canProjectPlacement: true, isInFront: true, isOnScreen: true,
                                              relativeBearing: nil))
    }

    func testOffScreenBearingUsesAClosedThirtyFiveDegreeWindow() {
        for bearing in [0.0, 35, -35, .nan] {
            XCTAssertEqual(ARArrowCoach.screenNotice(canProjectPlacement: true, isInFront: true, isOnScreen: false,
                                                    relativeBearing: bearing),
                           "Raise or tilt your phone toward the route to see the arrows.", "\(bearing)")
        }
        XCTAssertEqual(ARArrowCoach.screenNotice(canProjectPlacement: true, isInFront: false, isOnScreen: true,
                                                relativeBearing: 35.001), "Turn your phone to the right to see the arrows.")
        XCTAssertEqual(ARArrowCoach.screenNotice(canProjectPlacement: true, isInFront: true, isOnScreen: false,
                                                relativeBearing: -35.001), "Turn your phone to the left to see the arrows.")
        XCTAssertEqual(ARArrowCoach.screenNotice(canProjectPlacement: true, isInFront: false, isOnScreen: false,
                                                relativeBearing: nil), "Raise or tilt your phone toward the route to see the arrows.")
    }

    func testMissingPlacementAsksTheVisitorToWalkRatherThanTurn() {
        XCTAssertEqual(ARArrowCoach.screenNotice(canProjectPlacement: false, isInFront: false, isOnScreen: false,
                                                relativeBearing: 90),
                       "Walk a little farther along the route to bring the arrows into view.")
    }

    func testPinnedSignStaysVisibleThroughTheClosedTwoToTwentyMetreWindow() {
        XCTAssertTrue(ARArrowCoach.keepsPinnedSignVisible(position: [0, 100, -2], camera: .zero))
        XCTAssertTrue(ARArrowCoach.keepsPinnedSignVisible(position: [0, -40, -20], camera: .zero))
        XCTAssertFalse(ARArrowCoach.keepsPinnedSignVisible(position: [0, 0, -1.999], camera: .zero))
        XCTAssertFalse(ARArrowCoach.keepsPinnedSignVisible(position: [0, 0, -20.001], camera: .zero))
        XCTAssertFalse(ARArrowCoach.keepsPinnedSignVisible(position: [0, 0, .nan], camera: .zero))
        XCTAssertFalse(ARArrowCoach.keepsPinnedSignVisible(position: [0, 0, -8], camera: [.nan, 0, 0]))
    }
}
