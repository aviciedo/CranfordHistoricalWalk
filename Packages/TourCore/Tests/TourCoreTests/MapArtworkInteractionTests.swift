import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import TourCore

final class MapArtworkInteractionTests: XCTestCase {
    private let clip = CGRect(x: 10, y: 10, width: 200, height: 200)
    private func target(_ id: String, frame: CGRect, z: CGFloat = 1, hidden: Bool = false) -> MapArtworkTarget {
        MapArtworkTarget(id: id, frame: frame, zPosition: z, isHidden: hidden)
    }

    func testClippedArtworkAndNumberBadgesDoNotReceiveTheTap() {
        let frame = CGRect(x: 150, y: 160, width: 96, height: 80)
        let art = target("mill", frame: frame, z: 2)
        let badge = CGRect(x: 170, y: 180, width: 44, height: 44)
        XCTAssertEqual(MapArtworkHitTesting.artworkID(at: CGPoint(x: 160, y: 170), clip: clip,
            badgeTargets: [badge], artwork: [art]), "mill")
        XCTAssertNil(MapArtworkHitTesting.artworkID(at: CGPoint(x: 190, y: 200), clip: clip,
            badgeTargets: [badge], artwork: [art]), "The 44pt number stays a map hit")
        XCTAssertTrue(frame.contains(CGPoint(x: 230, y: 190)))
        XCTAssertNil(MapArtworkHitTesting.artworkID(at: CGPoint(x: 230, y: 190), clip: clip,
            badgeTargets: [], artwork: [art]), "Artwork past the clip must not react")
        XCTAssertNil(MapArtworkHitTesting.artworkID(at: CGPoint(x: 40, y: 40), clip: clip,
            badgeTargets: [badge], artwork: [art]))
    }

    func testTopmostVisibleCalloutWinsAndEqualLayersKeepInputOrder() {
        let shared = CGRect(x: 40, y: 40, width: 80, height: 64)
        let church = target("church", frame: shared, z: 1)
        let hotel = target("hotel", frame: shared, z: 1)
        let point = CGPoint(x: 50, y: 50)
        XCTAssertEqual(MapArtworkHitTesting.artworkID(at: point, clip: clip, badgeTargets: [],
            artwork: [church, hotel]), "church")
        XCTAssertEqual(MapArtworkHitTesting.artworkID(at: point, clip: clip, badgeTargets: [],
            artwork: [hotel, church]), "hotel")
        let active = target("mill", frame: shared, z: 2)
        XCTAssertEqual(MapArtworkHitTesting.artworkID(at: point, clip: clip, badgeTargets: [],
            artwork: [church, active]), "mill")
        XCTAssertEqual(MapArtworkHitTesting.artworkID(at: point, clip: clip, badgeTargets: [],
            artwork: [target("mill", frame: shared, z: 2, hidden: true), church]), "church")
    }

    func testOverlappingBadgeHolesMergeSoTheIntersectionStaysOpen() {
        let first = CGRect(x: 0, y: 0, width: 44, height: 44)
        let second = CGRect(x: 20, y: 10, width: 44, height: 44)
        let third = CGRect(x: 200, y: 0, width: 44, height: 44)
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 400)
        let separate = MapArtworkMask.badgeCutouts([first, third], clippedTo: bounds)
        XCTAssertEqual(separate, [
            CGRect(x: 4, y: 4, width: 36, height: 36),
            CGRect(x: 204, y: 4, width: 36, height: 36)
        ])
        let merged = MapArtworkMask.badgeCutouts([first, second], clippedTo: bounds)
        XCTAssertEqual(merged, [CGRect(x: 4, y: 4, width: 56, height: 46)])
        let overlap = CGRect(x: 24, y: 14, width: 16, height: 26)
        XCTAssertTrue(merged[0].contains(CGPoint(x: overlap.midX, y: overlap.midY)),
                      "The shared region must remain one hole, not an even-odd cancellation")
        XCTAssertEqual(MapArtworkMask.badgeCutouts([second, first], clippedTo: bounds), merged)
    }

    func testAChainOfOverlappingBadgesCollapsesAndTheClipTrimsTheRest() {
        let chain = [
            CGRect(x: 0, y: 0, width: 44, height: 44),
            CGRect(x: 30, y: 0, width: 44, height: 44),
            CGRect(x: 60, y: 0, width: 44, height: 44)
        ]
        let open = MapArtworkMask.badgeCutouts(chain, clippedTo: CGRect(x: 0, y: 0, width: 400, height: 80))
        XCTAssertEqual(open, [CGRect(x: 4, y: 4, width: 96, height: 36)])
        let trimmed = MapArtworkMask.badgeCutouts(chain, clippedTo: CGRect(x: 0, y: 0, width: 30, height: 30))
        XCTAssertEqual(trimmed, [CGRect(x: 4, y: 4, width: 26, height: 26)])
        XCTAssertTrue(MapArtworkMask.badgeCutouts(
            [CGRect(x: 500, y: 500, width: 44, height: 44)],
            clippedTo: CGRect(x: 0, y: 0, width: 100, height: 100)).isEmpty)
        XCTAssertTrue(MapArtworkMask.badgeCutouts([], clippedTo: clip).isEmpty)
    }
}
