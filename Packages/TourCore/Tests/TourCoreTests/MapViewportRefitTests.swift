import XCTest
@testable import TourCore

final class MapViewportRefitTests: XCTestCase {
    func testBoundsFitsReissueOnlyWhileTheCameraIsAutomatic() {
        for camera in [MapViewportRefit.Camera.overview, .navigation] {
            XCTAssertTrue(MapViewportRefit.shouldReissue(camera: camera, fit: .bounds, hasRequest: true))
        }
        for camera in [MapViewportRefit.Camera.follow, .free] {
            XCTAssertFalse(MapViewportRefit.shouldReissue(camera: camera, fit: .bounds, hasRequest: true),
                           "A leftover bounds request must not move a follow or free camera")
        }
    }

    func testFollowAndZoomStayPutEvenInNavigationOrOverview() {
        for camera in [MapViewportRefit.Camera.overview, .navigation, .follow, .free] {
            XCTAssertFalse(MapViewportRefit.shouldReissue(camera: camera, fit: .positioned, hasRequest: true))
            XCTAssertFalse(MapViewportRefit.shouldReissue(camera: camera, fit: nil, hasRequest: false))
            XCTAssertFalse(MapViewportRefit.shouldReissue(camera: camera, fit: .bounds, hasRequest: false))
            XCTAssertFalse(MapViewportRefit.shouldReissue(camera: camera, fit: nil, hasRequest: true))
        }
    }

    func testZeroOrNonPositiveViewportIsNotAFit() {
        XCTAssertFalse(MapViewportRefit.acceptsSize(width: 0, height: 320))
        XCTAssertFalse(MapViewportRefit.acceptsSize(width: 200, height: 0))
        XCTAssertFalse(MapViewportRefit.acceptsSize(width: -1, height: 320))
        XCTAssertFalse(MapViewportRefit.acceptsSize(width: 200, height: -0.1))
        XCTAssertFalse(MapViewportRefit.acceptsSize(width: .nan, height: 320))
        XCTAssertFalse(MapViewportRefit.acceptsSize(width: 200, height: .nan))
        XCTAssertTrue(MapViewportRefit.acceptsSize(width: .leastNonzeroMagnitude, height: .leastNonzeroMagnitude))
        XCTAssertTrue(MapViewportRefit.acceptsSize(width: 390, height: 200))
    }
}
