import XCTest
@testable import TourCore

final class HomeMapFramingTests: XCTestCase {
    let mill = GeoCoordinate(latitude: 40.6519, longitude: -74.3024)
    let greystone = GeoCoordinate(latitude: 40.6568, longitude: -74.3012)
    /// Far enough that including it would shrink both stops to a speck.
    let distantUser = GeoCoordinate(latitude: 40.7357, longitude: -74.1724)

    func testHomeOverviewIgnoresADistantUserWhileTheLiveMapKeepsThem() {
        let stops = [mill, greystone]
        XCTAssertEqual(
            HomeMapFraming.overviewCoordinates(stops: stops, user: distantUser, includesUserLocation: false),
            stops
        )
        XCTAssertEqual(
            HomeMapFraming.overviewCoordinates(stops: stops, user: distantUser, includesUserLocation: true),
            stops + [distantUser]
        )
    }

    func testMissingUserFixIsOmittedAndAnEmptyTourStaysEmpty() {
        XCTAssertEqual(
            HomeMapFraming.overviewCoordinates(stops: [mill], user: nil, includesUserLocation: true),
            [mill]
        )
        XCTAssertEqual(
            HomeMapFraming.overviewCoordinates(stops: [], user: distantUser, includesUserLocation: false),
            []
        )
        XCTAssertEqual(
            HomeMapFraming.overviewCoordinates(stops: [], user: distantUser, includesUserLocation: true),
            [distantUser]
        )
    }

    func testLandmarksStayOnHomeAndAppearOnTheLiveMapOnlyAtTheZoomCutoff() {
        XCTAssertEqual(HomeMapFraming.landmarkMinimumZoom, 14.5)
        XCTAssertTrue(HomeMapFraming.showsLandmark(keepsLandmarksVisible: true, zoom: 0))
        XCTAssertTrue(HomeMapFraming.showsLandmark(keepsLandmarksVisible: true, zoom: -1))
        XCTAssertFalse(HomeMapFraming.showsLandmark(keepsLandmarksVisible: false, zoom: 14.5 - 0.000_1))
        XCTAssertTrue(HomeMapFraming.showsLandmark(keepsLandmarksVisible: false, zoom: 14.5))
        XCTAssertTrue(HomeMapFraming.showsLandmark(keepsLandmarksVisible: false, zoom: 18))
    }

    func testMapHeightStaysBetweenTheFloorAndCeiling() {
        XCTAssertEqual(HomeMapFraming.minimumMapHeight, 310)
        XCTAssertEqual(HomeMapFraming.maximumMapHeight, 350)
        XCTAssertEqual(HomeMapFraming.developerControlReserve, 56)

        let reserve = 238.0
        XCTAssertEqual(HomeMapFraming.mapHeight(availableHeight: 800, contentReserve: reserve, includesDeveloperControl: false), 350)
        XCTAssertEqual(HomeMapFraming.mapHeight(availableHeight: reserve + 350, contentReserve: reserve, includesDeveloperControl: false), 350)
        XCTAssertEqual(HomeMapFraming.mapHeight(availableHeight: reserve + 330, contentReserve: reserve, includesDeveloperControl: false), 330)
        XCTAssertEqual(HomeMapFraming.mapHeight(availableHeight: reserve + 310, contentReserve: reserve, includesDeveloperControl: false), 310)
        // A short viewport would otherwise shrink the map below the old fixed height.
        XCTAssertEqual(HomeMapFraming.mapHeight(availableHeight: 500, contentReserve: reserve, includesDeveloperControl: false), 310)
        XCTAssertEqual(HomeMapFraming.mapHeight(availableHeight: 0, contentReserve: reserve, includesDeveloperControl: false), 310)
    }

    func testDeveloperControlsConsumeTheirRowBeforeTheHeightClamp() {
        let reserve = 238.0
        // 600 - 238 - 56 = 306, which is still below the floor.
        XCTAssertEqual(HomeMapFraming.mapHeight(availableHeight: 600, contentReserve: reserve, includesDeveloperControl: true), 310)
        // 700 - 238 - 56 = 406, which clamps to the ceiling.
        XCTAssertEqual(HomeMapFraming.mapHeight(availableHeight: 700, contentReserve: reserve, includesDeveloperControl: true), 350)
        XCTAssertEqual(
            HomeMapFraming.mapHeight(availableHeight: reserve + 56 + 330, contentReserve: reserve, includesDeveloperControl: true),
            330
        )
    }
}
