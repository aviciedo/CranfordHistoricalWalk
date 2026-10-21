import XCTest
@testable import TourCore

final class NarrationPlaybackPolicyTests: XCTestCase {
    func testInterruptionBeganPausesOnlyWhilePlayingAndRemembersThat() {
        XCTAssertEqual(NarrationInterruptionPolicy.beganType, 1)
        XCTAssertEqual(NarrationInterruptionPolicy.endedType, 0)
        XCTAssertEqual(NarrationInterruptionPolicy.shouldResumeOption, 1)

        XCTAssertEqual(
            NarrationInterruptionPolicy.decision(typeRaw: 1, optionsRaw: 1, isPlaying: true, wasPlayingBefore: false),
            .began(pausePlayback: true)
        )
        XCTAssertEqual(
            NarrationInterruptionPolicy.decision(typeRaw: 1, optionsRaw: nil, isPlaying: false, wasPlayingBefore: true),
            .began(pausePlayback: false)
        )
    }

    func testInterruptionEndedResumesOnlyAPlayingNarrationWhenTheSystemAllowsIt() {
        XCTAssertEqual(
            NarrationInterruptionPolicy.decision(typeRaw: 0, optionsRaw: 1, isPlaying: false, wasPlayingBefore: true),
            .ended(resumePlayback: true)
        )
        XCTAssertEqual(
            NarrationInterruptionPolicy.decision(typeRaw: 0, optionsRaw: 3, isPlaying: false, wasPlayingBefore: true),
            .ended(resumePlayback: true),
            "Extra option bits still include shouldResume"
        )
        XCTAssertEqual(
            NarrationInterruptionPolicy.decision(typeRaw: 0, optionsRaw: 0, isPlaying: false, wasPlayingBefore: true),
            .ended(resumePlayback: false)
        )
        XCTAssertEqual(
            NarrationInterruptionPolicy.decision(typeRaw: 0, optionsRaw: nil, isPlaying: false, wasPlayingBefore: true),
            .ended(resumePlayback: false)
        )
        XCTAssertEqual(
            NarrationInterruptionPolicy.decision(typeRaw: 0, optionsRaw: 1, isPlaying: true, wasPlayingBefore: false),
            .ended(resumePlayback: false)
        )
    }

    func testUnknownOrMissingInterruptionsLeavePlaybackAlone() {
        XCTAssertEqual(NarrationInterruptionPolicy.decision(typeRaw: nil, optionsRaw: 1, isPlaying: true, wasPlayingBefore: true), .ignore)
        XCTAssertEqual(NarrationInterruptionPolicy.decision(typeRaw: 2, optionsRaw: 1, isPlaying: true, wasPlayingBefore: true), .ignore)
        XCTAssertEqual(NarrationInterruptionPolicy.decision(typeRaw: 99, optionsRaw: nil, isPlaying: false, wasPlayingBefore: false), .ignore)
    }

    func testSpeechProgressUsesUTF16AndClampsOnlyTheUpperEnd() {
        let thumbsUp = "A👍"
        XCTAssertEqual(thumbsUp.utf16.count, 3)
        XCTAssertEqual(thumbsUp.count, 2)
        XCTAssertEqual(NarrationSpeechProgress.fraction(characterEndUTF16: 1, utf16Length: thumbsUp.utf16.count), 1.0 / 3.0)
        XCTAssertEqual(NarrationSpeechProgress.fraction(characterEndUTF16: 3, utf16Length: thumbsUp.utf16.count), 1)
        XCTAssertEqual(NarrationSpeechProgress.fraction(characterEndUTF16: 0, utf16Length: 10), 0)
        XCTAssertEqual(NarrationSpeechProgress.fraction(characterEndUTF16: 11, utf16Length: 10), 1)
        XCTAssertEqual(NarrationSpeechProgress.fraction(characterEndUTF16: -2, utf16Length: 10), -0.2)
        XCTAssertNil(NarrationSpeechProgress.fraction(characterEndUTF16: 4, utf16Length: 0))
    }
}
