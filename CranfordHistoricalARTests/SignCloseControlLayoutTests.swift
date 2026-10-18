import XCTest
@testable import CranfordHistoricalAR

final class SignCloseControlLayoutTests: XCTestCase {
    func testPlaqueCloseControlCoversTheCornerGlyphAndNotTheCardBody() {
        let cardWidth: Float = 0.45
        let cardHeight: Float = 0.30
        let planeY: Float = 0
        let layout = SignCloseControlLayout.make(
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            planeY: planeY,
            forPlaqueCard: true
        )

        let inset = cardWidth * (54 / 720)
        XCTAssertEqual(layout.centerX, cardWidth / 2 - inset, accuracy: 0.0001)
        XCTAssertEqual(layout.centerY, planeY + cardHeight / 2 - inset, accuracy: 0.0001)
        XCTAssertEqual(layout.size, 0.09, accuracy: 0.0001)

        // The drawn xmark is the only thing that should dismiss. The card center
        // is body copy; hitting it used to advance the tour.
        XCTAssertTrue(layout.contains(x: layout.centerX, y: layout.centerY))
        XCTAssertFalse(layout.contains(x: 0, y: planeY))
        XCTAssertGreaterThan(layout.centerX - layout.size / 2, 0)
        XCTAssertGreaterThan(layout.centerY - layout.size / 2, planeY)
    }

    func testGeoSignKeepsTheLargeCornerTarget() {
        let layout = SignCloseControlLayout.make(
            cardWidth: 1.6,
            cardHeight: 0.9,
            planeY: 0.45,
            forPlaqueCard: false
        )
        XCTAssertEqual(layout.size, 0.22, accuracy: 0.0001)
        XCTAssertEqual(layout.centerX, 0.64, accuracy: 0.0001)
        XCTAssertEqual(layout.centerY, 0.74, accuracy: 0.0001)
    }
}
