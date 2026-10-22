import AVFoundation
import TourCore
import XCTest
@testable import CranfordHistoricalAR

@MainActor
final class NarrationPlayerTests: XCTestCase {
    func testProducedNarrationsAreBundledPlayableAndDoNotAutoStart() async throws {
        for (index, filename) in [(0, "stop_01_droeschers_mill"), (1, "stop_02_greystone")] {
            let stop = HistoricalStop.previewStops[index]
            XCTAssertEqual(stop.narrationSource, .bundledAudio(fileName: filename + ".mp3"))
            let url = try XCTUnwrap(Bundle.main.url(forResource: filename, withExtension: "mp3"))
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)
            XCTAssertEqual(duration.seconds, stop.estimatedVisitDuration, accuracy: 0.5)
            let player = NarrationPlayer()
            defer { player.stop() }
            XCTAssertTrue(player.prepare(stop))
            XCTAssertEqual(player.kind, .recording)
            XCTAssertFalse(player.isPlaying, "Selecting a produced recording must still require Play")
        }
    }

    func testPreviewCreatorStopsMatchTheBundledContent() async throws {
        let document = try await BundledJSONHistoricalStopService().loadTour()
        for id in ["hpab-001", "hpab-002", "hpab-004"] {
            let stop = try XCTUnwrap(document.stops.first { $0.id == id })
            var preview = try XCTUnwrap(HistoricalStop.previewStops.first { $0.id == id })
            // Previews use the equivalent derived departure radius; JSON supplies it explicitly.
            preview.departureRadius = stop.departureRadius
            XCTAssertEqual(preview, stop)
        }
    }

    func testProducedReleaseOverridesLegacySystemAndRemoteSources() throws {
        let player = NarrationPlayer()
        defer { player.stop() }
        for recording in ProducedNarrationRelease.recordings {
            var stop = try XCTUnwrap(HistoricalStop.previewStops.first { $0.id == recording.stopID })
            for legacyURL in [URL?.none, URL(string: "http://preservecranford.com/Audio/old.mp3")] {
                stop.audioURL = legacyURL
                XCTAssertTrue(player.prepare(stop))
                XCTAssertEqual(player.preparedSource, .bundledAudio(fileName: recording.fileName))
                XCTAssertEqual(player.kind, .recording)
                XCTAssertFalse(player.isPlaying)
            }
        }
    }

    func testChangedSourceForSameStopReplacesPreparedSpeech() {
        var stop = HistoricalStop.previewStops[0]
        stop.id = "source-change-regression"
        stop.audioURL = nil
        stop.narrationVoicePreference = .systemDefault
        let player = NarrationPlayer()
        defer { player.stop() }
        XCTAssertTrue(player.prepare(stop))
        XCTAssertEqual(player.kind, .synthesizedSpeech)
        stop.audioURL = URL(string: "stop_01_droeschers_mill.mp3")
        XCTAssertTrue(player.prepare(stop))
        XCTAssertEqual(player.kind, .recording)
        XCTAssertEqual(player.preparedSource, .bundledAudio(fileName: "stop_01_droeschers_mill.mp3"))
        XCTAssertFalse(player.isPlaying)
    }

    func testChangedTranscriptForSameStopRefreshesPreparedSpeech() {
        var stop = HistoricalStop.previewStops[0]
        stop.id = "text-change-regression"
        stop.audioURL = nil
        stop.narrationVoicePreference = .systemDefault
        let player = NarrationPlayer()
        defer { player.stop() }
        XCTAssertTrue(player.prepare(stop))
        stop.narrationText = "The updated story."
        XCTAssertTrue(player.prepare(stop))
        XCTAssertEqual(player.preparedSource, .synthesizedSpeech(text: "The updated story."))
    }

    func testReleaseRejectsMissingAudioOrOutdatedTranscript() throws {
        let data = try Data(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "historical_stops", withExtension: "json")))
        var document = try HistoricalStopDecoder.decode(data)
        XCTAssertThrowsError(try ProducedNarrationRelease.install(in: &document, bundle: Bundle(for: Self.self)))
        document.stops[0].narrationText = "An outdated script."
        XCTAssertThrowsError(try ProducedNarrationRelease.install(in: &document, bundle: .main))
    }

    func testReleaseCorrectsLegacyAudioMetadataAndPreservesOtherStops() throws {
        let data = try Data(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "historical_stops", withExtension: "json")))
        var document = try HistoricalStopDecoder.decode(data)
        let remaining = Array(document.stops.dropFirst(2))
        document.stops[0].audioURL = nil
        document.stops[1].audioURL = URL(string: "http://preservecranford.com/Audio/Greystone.mp3")
        try ProducedNarrationRelease.install(in: &document, bundle: .main)
        for (stop, recording) in zip(document.stops, ProducedNarrationRelease.recordings) {
            XCTAssertEqual(stop.narrationSource, .bundledAudio(fileName: recording.fileName))
            XCTAssertEqual(stop.estimatedVisitDuration, recording.duration)
        }
        XCTAssertEqual(Array(document.stops.dropFirst(2)), remaining)
    }

    func testRequestedMaleVoiceDoesNotSilentlyFallBackWhenMissing() {
        XCTAssertNil(NarrationPlayer.selectSpeechVoice(preference: .warmMaleEnglish, from: []))
        XCTAssertNil(NarrationPlayer.makeSpeechUtterance(text: "The mill story.", voice: nil, preference: .warmMaleEnglish))
        XCTAssertNotNil(NarrationPlayer.makeSpeechUtterance(text: "A default story.", voice: nil, preference: .systemDefault))
    }

    func testAvailableVoiceIsMaleEnglishAndUsesGentlePacing() throws {
        guard let voice = NarrationPlayer.selectSpeechVoice(preference: .warmMaleEnglish, from: AVSpeechSynthesisVoice.speechVoices()) else {
            throw XCTSkip("Download an English male voice on this test device to exercise its speech settings.")
        }
        XCTAssertEqual(voice.gender, .male)
        XCTAssertTrue(voice.language.lowercased().hasPrefix("en"))
        XCTAssertFalse(voice.voiceTraits.contains(.isNoveltyVoice))
        XCTAssertFalse(voice.voiceTraits.contains(.isPersonalVoice))
        let script = "Droescher’s Mill: A River That Built a Town."
        let utterance = try XCTUnwrap(NarrationPlayer.makeSpeechUtterance(text: script, voice: voice, preference: .warmMaleEnglish))
        XCTAssertEqual(utterance.speechString, script)
        XCTAssertEqual(utterance.voice?.identifier, voice.identifier)
        XCTAssertLessThan(utterance.rate, AVSpeechUtteranceDefaultSpeechRate)
        XCTAssertGreaterThan(utterance.rate, AVSpeechUtteranceMinimumSpeechRate)
        XCTAssertEqual(utterance.pitchMultiplier, 0.98, accuracy: 0.001)
    }
}
