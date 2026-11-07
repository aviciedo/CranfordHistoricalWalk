import XCTest
@testable import TourCore

final class NarrationPlaybackTimeTests: XCTestCase {
    func testLabelsTruncateSubsecondsAndPadHourBoundaries() {
        XCTAssertEqual(NarrationPlaybackTime.text(nil), "--:--")
        XCTAssertEqual(NarrationPlaybackTime.text(.nan), "--:--")
        XCTAssertEqual(NarrationPlaybackTime.text(.infinity), "--:--")
        XCTAssertEqual(NarrationPlaybackTime.text(-.infinity), "--:--")
        XCTAssertEqual(NarrationPlaybackTime.text(-4.2), "0:00")
        XCTAssertEqual(NarrationPlaybackTime.text(0), "0:00")
        XCTAssertEqual(NarrationPlaybackTime.text(45.9), "0:45")
        XCTAssertEqual(NarrationPlaybackTime.text(59.999), "0:59")
        XCTAssertEqual(NarrationPlaybackTime.text(60), "1:00")
        XCTAssertEqual(NarrationPlaybackTime.text(61), "1:01")
        XCTAssertEqual(NarrationPlaybackTime.text(3599.9), "59:59")
        XCTAssertEqual(NarrationPlaybackTime.text(3600), "1:00:00")
        XCTAssertEqual(NarrationPlaybackTime.text(3661), "1:01:01")
        XCTAssertEqual(NarrationPlaybackTime.text(7322.8), "2:02:02")
        XCTAssertEqual(NarrationPlaybackTime.text(1e20), "--:--", "A duration past Int must not trap or print a truncated hour")
    }

    func testScrubStaysInsideTheRecordingAndPreviewsOnlyAKnownDuration() {
        XCTAssertEqual(NarrationPlaybackTime.scrubFraction(locationX: 0, width: 200), 0)
        XCTAssertEqual(NarrationPlaybackTime.scrubFraction(locationX: 50, width: 200), 0.25)
        XCTAssertEqual(NarrationPlaybackTime.scrubFraction(locationX: 200, width: 200), 1)
        XCTAssertEqual(NarrationPlaybackTime.scrubFraction(locationX: 260, width: 200), 1)
        XCTAssertEqual(NarrationPlaybackTime.scrubFraction(locationX: -12, width: 200), 0)
        XCTAssertNil(NarrationPlaybackTime.scrubFraction(locationX: 10, width: 0))
        XCTAssertNil(NarrationPlaybackTime.scrubFraction(locationX: 10, width: -4))
        XCTAssertNil(NarrationPlaybackTime.scrubFraction(locationX: .nan, width: 200))
        XCTAssertNil(NarrationPlaybackTime.scrubFraction(locationX: 10, width: .infinity))

        XCTAssertEqual(NarrationPlaybackTime.railProgress(scrubFraction: nil, playbackProgress: 1.4), 1)
        XCTAssertEqual(NarrationPlaybackTime.railProgress(scrubFraction: nil, playbackProgress: -0.2), 0)
        XCTAssertEqual(NarrationPlaybackTime.railProgress(scrubFraction: 0.5, playbackProgress: 0.1), 0.5)

        let duration = 151.3
        let start = NarrationPlaybackTime.scrubFraction(locationX: -20, width: 100)
        let end = NarrationPlaybackTime.scrubFraction(locationX: 140, width: 100)
        XCTAssertEqual(NarrationPlaybackTime.displayedElapsed(scrubFraction: start, duration: duration, fallbackElapsed: 40), 0)
        XCTAssertEqual(NarrationPlaybackTime.displayedElapsed(scrubFraction: end, duration: duration, fallbackElapsed: 40), duration)
        XCTAssertEqual(NarrationPlaybackTime.displayedElapsed(scrubFraction: 0, duration: duration, fallbackElapsed: 40), 0,
                       "A drag to the start previews zero even when playback is already underway")
        XCTAssertEqual(NarrationPlaybackTime.displayedElapsed(scrubFraction: nil, duration: duration, fallbackElapsed: 40), 40)
        XCTAssertEqual(NarrationPlaybackTime.displayedElapsed(scrubFraction: 0.5, duration: nil, fallbackElapsed: 40), 40)
    }
}
