import Foundation
import TourCore
import XCTest
#if canImport(CranfordHistoricalAR)
import AVFoundation
@testable import CranfordHistoricalAR

@MainActor
final class NarrationPlayerTests: XCTestCase {
    func testClosingPersistentPlayerPausesWithoutLosingBookmark() async throws {
        let player = NarrationPlayer()
        let stop = HistoricalStop.previewStops[0]
        defer { player.stop() }
        XCTAssertFalse(player.isPersistentPlayerVisible)
        XCTAssertFalse(player.hasSavedResume(for: stop), "A fresh story uses Play narration")
        XCTAssertTrue(player.prepare(stop))
        try await waitForAudio { player.canSeek }
        XCTAssertFalse(player.hasSavedResume(for: stop), "Preparing alone must not offer Resume")
        XCTAssertFalse(player.isPersistentPlayerVisible, "Preparing does not show transport")
        player.seek(to: 42)
        player.play()
        XCTAssertTrue(player.isPersistentPlayerVisible)
        player.dismissPersistentPlayer()
        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(player.isPersistentPlayerVisible)
        XCTAssertTrue(player.hasSavedResume(for: stop), "Closing with saved progress uses Resume narration")
        XCTAssertEqual(player.resumableStoryID, stop.id)
        XCTAssertEqual(player.resumableElapsed, 42, accuracy: 1)
        XCTAssertTrue(player.prepare(stop))
        XCTAssertFalse(player.isPersistentPlayerVisible, "Preparing the same story must not undo X")
        player.resumeSavedStory(stop)
        try await waitForAudio { player.isPlaying && player.elapsed >= 41 }
        XCTAssertTrue(player.isPersistentPlayerVisible)
    }

    func testCloseDuringLoadCancelsDeferredPlaybackAndStaysHidden() async throws {
        let player = NarrationPlayer()
        defer { player.stop() }
        XCTAssertTrue(player.prepare(HistoricalStop.previewStops[0]))
        player.play()
        player.dismissPersistentPlayer()
        try await waitForAudio { player.canSeek }
        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(player.isPersistentPlayerVisible)
        XCTAssertEqual(player.status, .paused)
    }

    func testOrdinaryPauseKeepsPersistentPlayerAvailable() async throws {
        let player = NarrationPlayer()
        defer { player.stop() }
        XCTAssertTrue(player.prepare(HistoricalStop.previewStops[0]))
        player.play()
        player.pause()
        XCTAssertTrue(player.isPersistentPlayerVisible)
        XCTAssertFalse(player.isPlaying)
    }

    func testCompletionOfMillRecordingWhileWalkingToParkRecordsOnlyMillLearning() async throws {
        let dependencies = AppDependencies.preview()
        let tour = dependencies.tourViewModel
        await tour.loadStopsIfNeeded()
        let mill = HistoricalStop.previewStops[0]
        let park = HistoricalStop.previewStops[1]
        tour.progress.selectStop(withID: park.id)
        let player = dependencies.narrationPlayer
        defer { player.stop(); tour.stopLocation(); tour.cancelRouting() }
        XCTAssertTrue(player.prepare(mill))
        try await waitForAudio { player.canSeek }
        let duration = try XCTUnwrap(player.duration)
        player.seek(to: max(0, duration - 0.15))
        player.play()
        try await waitForAudio { player.status == .finished }
        XCTAssertEqual(tour.currentStop?.id, park.id)
        XCTAssertNil(player.resumableStoryID, "A completed recording must not be offered as unfinished")
        XCTAssertFalse(player.hasSavedResume(for: mill), "A finished recording returns to Play narration")
        XCTAssertNotNil(tour.activities[mill.id].listenedAt)
        XCTAssertFalse(tour.activities[park.id].learningCompleted)
        XCTAssertNil(tour.activities[mill.id].visitedAt)
        XCTAssertNil(tour.activities[mill.id].bonusFoundAt)
    }

    func testAutomaticWalkingTransitionAndUndoLeavePlayingMillNarrationAlone() async throws {
        let dependencies = AppDependencies.preview()
        let tour = dependencies.tourViewModel
        await tour.loadStopsIfNeeded()
        tour.startTour(); tour.isAutomaticNavigationVisible = true
        let stops = HistoricalStop.previewStops
        let player = dependencies.narrationPlayer
        defer { player.stop(); tour.stopLocation(); tour.cancelRouting() }
        XCTAssertTrue(player.prepare(stops[0]))
        try await waitForAudio { player.canSeek }
        player.seek(to: 35); player.play()
        try await waitForAudio { player.isPlaying }
        let now = Date()
        let away = GeoCoordinate(latitude: stops[0].latitude + 0.002, longitude: stops[0].longitude)
        for (point, age) in [(stops[0].coordinate, -15.0), (stops[0].coordinate, -12.0), (away, -6.0), (away, 0.0)] {
            let sample = LocationSample(coordinate: point, horizontalAccuracy: 3, timestamp: now.addingTimeInterval(age))
            tour.evaluateAutomaticProgression(sample, now: now)
        }
        XCTAssertEqual(tour.currentStop?.id, stops[1].id)
        XCTAssertEqual(player.stopID, stops[0].id)
        XCTAssertTrue(player.isPlaying)
        XCTAssertGreaterThanOrEqual(player.elapsed, 34)
        tour.undoAutomaticTransition()
        XCTAssertEqual(tour.currentStop?.id, stops[0].id)
        XCTAssertEqual(player.stopID, stops[0].id)
        XCTAssertTrue(player.isPlaying)
    }

    func testPreviousStopLeavesPlayingStoryAndPositionUnchanged() async throws {
        let dependencies = AppDependencies.preview()
        let tour = dependencies.tourViewModel
        await tour.loadStopsIfNeeded()
        tour.progress.start()
        for _ in 0..<3 { tour.completeCurrentStopAndAdvance() }
        let stops = HistoricalStop.previewStops
        let player = dependencies.narrationPlayer
        defer { player.stop(); tour.stopLocation(); tour.cancelRouting() }
        XCTAssertTrue(player.prepare(stops[0]))
        try await waitForAudio { player.canSeek }
        player.seek(to: 35); player.play()
        try await waitForAudio { player.isPlaying }
        XCTAssertTrue(tour.goToPreviousStop())
        XCTAssertEqual(tour.currentStop?.id, stops[2].id)
        XCTAssertEqual(player.stopID, stops[0].id)
        XCTAssertTrue(player.isPlaying)
        XCTAssertGreaterThanOrEqual(player.elapsed, 34)
    }

    func testRecordingBookmarkSurvivesExplicitSwitchToAnotherStory() async throws {
        let player = NarrationPlayer()
        defer { player.stop() }
        let stops = HistoricalStop.previewStops
        XCTAssertTrue(player.prepare(stops[0]))
        XCTAssertFalse(player.hasStartedPlayback)
        try await waitForAudio { player.canSeek }
        player.seek(to: 42)
        XCTAssertTrue(player.prepare(stops[1]))
        try await waitForAudio { player.canSeek }
        XCTAssertTrue(player.prepare(stops[0]))
        try await waitForAudio { player.canSeek && abs(player.elapsed - 42) < 1 }
        XCTAssertEqual(player.elapsed, 42, accuracy: 1)
        XCTAssertFalse(player.isPlaying, "Returning to a recording must not autoplay")
    }

    func testSavedRecordingRestoresMetadataWithoutPreparingOrAutoplaying() async throws {
        let store = InMemoryNarrationResumeStore()
        let stop = HistoricalStop.previewStops[0]
        let first = NarrationPlayer(resumeStore: store)
        XCTAssertTrue(first.prepare(stop))
        try await waitForAudio { first.canSeek }
        first.seek(to: 42)
        first.pause()
        first.checkpointPlayback()

        let restored = NarrationPlayer(resumeStore: store)
        defer { first.stop(); restored.stop() }
        XCTAssertEqual(restored.resumableStoryID, stop.id)
        XCTAssertEqual(restored.resumableElapsed, 42, accuracy: 0.1)
        XCTAssertTrue(restored.hasSavedResume(for: stop))
        XCTAssertNil(restored.stopID, "Restoring metadata must not even prepare AVPlayer")
        XCTAssertNil(restored.kind)
        XCTAssertEqual(restored.status, .idle)
        XCTAssertFalse(restored.hasStartedPlayback)
        XCTAssertFalse(restored.isPersistentPlayerVisible)
        XCTAssertFalse(restored.isPlaying)
        XCTAssertTrue(restored.prepare(stop))
        try await waitForAudio { restored.canSeek && abs(restored.elapsed - 42) < 1 }
        XCTAssertFalse(restored.isPlaying)
    }

    func testExplicitSavedStoryResumeStartsAtSavedRecordingPosition() async throws {
        let store = InMemoryNarrationResumeStore()
        let stop = HistoricalStop.previewStops[0]
        let first = NarrationPlayer(resumeStore: store)
        XCTAssertTrue(first.prepare(stop))
        try await waitForAudio { first.canSeek }
        first.seek(to: 42)
        first.pause()
        let restored = NarrationPlayer(resumeStore: store)
        defer { first.stop(); restored.stop() }
        restored.resumeSavedStory(stop)
        try await waitForAudio { restored.isPlaying && restored.elapsed >= 41 }
        XCTAssertEqual(restored.stopID, stop.id)
        XCTAssertTrue(restored.hasStartedPlayback)
    }

    func testChangedRecordingSourceRejectsPreviousBookmark() async throws {
        let store = InMemoryNarrationResumeStore()
        var stop = HistoricalStop.previewStops[0]
        stop.id = "resume-source-version"
        stop.audioURL = URL(string: "stop_01_droeschers_mill.mp3")
        let first = NarrationPlayer(resumeStore: store)
        XCTAssertTrue(first.prepare(stop))
        try await waitForAudio { first.canSeek }
        first.seek(to: 42)
        first.pause()
        stop.audioURL = URL(string: "stop_02_greystone.mp3")
        let restored = NarrationPlayer(resumeStore: store)
        defer { first.stop(); restored.stop() }
        XCTAssertFalse(restored.hasSavedResume(for: stop))
        XCTAssertTrue(restored.prepare(stop))
        try await waitForAudio { restored.canSeek }
        XCTAssertEqual(restored.elapsed, 0, accuracy: 0.1)
        XCTAssertNil(restored.resumableStoryID)
        XCTAssertFalse(restored.isPlaying)
    }

    private func waitForAudio(_ predicate: @escaping @MainActor () -> Bool) async throws {
        for _ in 0..<200 {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(25))
        }
        XCTFail("Audio did not reach the expected state within five seconds")
    }

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

    func testUnavailableRecordingDoesNotDisableTourOrFallBackToSpeech() throws {
        let data = try Data(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "historical_stops", withExtension: "json")))
        var document = try HistoricalStopDecoder.decode(data)
        try ProducedNarrationRelease.install(in: &document, bundle: Bundle(for: Self.self))
        XCTAssertEqual(document.stops.count, 5)
        XCTAssertTrue(document.stops[0].narrationPending)
        XCTAssertNil(ProducedNarrationRelease.source(for: document.stops[0]))
        document = try HistoricalStopDecoder.decode(data)
        document.stops[0].narrationText = "An outdated script."
        try ProducedNarrationRelease.install(in: &document, bundle: .main)
        XCTAssertTrue(document.stops[0].narrationPending)
        XCTAssertNil(ProducedNarrationRelease.source(for: document.stops[0]))
        XCTAssertNotNil(document.stops[0].narrationText)
        XCTAssertFalse(document.stops[1].narrationPending)
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
        for (stop, recording) in zip(document.stops, document.recordings ?? []) {
            XCTAssertEqual(stop.narrationAudioSHA256, recording.audioSHA256)
        }
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

#else
@testable import ActivityModelHarness
#endif

/// Foundation-only tests also run in the portable activity harness.
@MainActor
final class NarrationResumeStoreTests: XCTestCase {
    func testDurableResumeRoundTripsIndependentStoryBookmarks() async throws {
        let suite = "cranford.audio-resume.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = NarrationResumeState(lastStoryID: "mill", bookmarks: [
            "mill": NarrationBookmark(sourceID: "release-one", elapsed: 84),
            "park": NarrationBookmark(sourceID: "release-two", elapsed: 21)
        ])
        LocalNarrationResumeStore(defaults: defaults).save(state)
        XCTAssertEqual(LocalNarrationResumeStore(defaults: defaults).load(), state)
        XCTAssertEqual(LocalStopActivityStore(defaults: defaults).load(), StopActivityLedger(), "A bookmark must never create learning or visit evidence")
    }

    func testCorruptStoredResumeDoesNotPreventAppStartup() async throws {
        let suite = "cranford.audio-resume.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("not-json".utf8), forKey: "cranford.narration-resume.v1")
        XCTAssertEqual(LocalNarrationResumeStore(defaults: defaults).load(), NarrationResumeState())
    }

    func testInvalidPositionsAndUnknownLastStoryAreRejected() async {
        let store = InMemoryNarrationResumeStore()
        store.save(NarrationResumeState(lastStoryID: "invalid", bookmarks: [
            "invalid": NarrationBookmark(sourceID: "source", elapsed: .nan),
            "negative": NarrationBookmark(sourceID: "source", elapsed: -5),
            "infinite": NarrationBookmark(sourceID: "source", elapsed: .infinity),
            "no-source": NarrationBookmark(sourceID: "", elapsed: 5),
            "valid": NarrationBookmark(sourceID: "source", elapsed: 0)
        ]))
        XCTAssertNil(store.load().lastStoryID)
        XCTAssertEqual(store.load().bookmarks, ["valid": NarrationBookmark(sourceID: "source", elapsed: 0)])
    }
}
