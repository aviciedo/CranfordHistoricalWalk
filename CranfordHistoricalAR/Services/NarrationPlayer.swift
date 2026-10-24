import AVFoundation
import Foundation
import Observation
import TourCore

/// Plays a stop's narration: a recorded file (remote or bundled) through `AVPlayer`, or — when no
/// recording exists — its dedicated script/description read by `AVSpeechSynthesizer`. One instance is shared
/// app-wide (see `AppDependencies`) so the map sheet and the AR screen can never talk over each other.
///
/// Owns the audio session and interruption handling for the shared narration controls.
@MainActor
@Observable
final class NarrationPlayer: NSObject {
    enum Kind: Equatable { case recording, synthesizedSpeech }

    enum Status: Equatable {
        case idle
        case loading
        case playing
        case paused
        case finished
        case failed(String)
    }

    private(set) var hasStartedPlayback = false
    private(set) var isPersistentPlayerVisible = false
    @ObservationIgnored private let resumeStore: any NarrationResumeStore
    private var resumeState: NarrationResumeState
    @ObservationIgnored private var resumeSeconds: Double = 0
    @ObservationIgnored private var preparedSourceID: String?
    @ObservationIgnored private var pendingSeekTarget: Double?
    @ObservationIgnored private var seekGeneration = 0
    @ObservationIgnored private var lastCheckpointDate = Date.distantPast
    private(set) var stopID: String?
    private(set) var title: String = ""
    private(set) var kind: Kind?
    private(set) var preparedSource: HistoricalStop.NarrationSource?
    @ObservationIgnored private var preparedVoicePreference: NarrationVoicePreference?
    private(set) var status: Status = .idle
    /// Seconds. For synthesized speech this is wall-clock time spent speaking.
    private(set) var elapsed: TimeInterval = 0
    /// Seconds; `nil` until known (recordings) or always for synthesized speech.
    private(set) var duration: TimeInterval?
    /// 0…1. Recordings: elapsed/duration. Speech: fraction of characters spoken.
    private(set) var progress: Double = 0

    static let skipInterval: TimeInterval = 15

    // AVPlayer
    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var itemObservers: [NSObjectProtocol] = []
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?

    // Speech
    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var speechText: String = ""
    @ObservationIgnored private var speechVoice: AVSpeechSynthesisVoice?
    @ObservationIgnored private var speechPreference: NarrationVoicePreference = .systemDefault
    @ObservationIgnored private var activeUtterance: AVSpeechUtterance?
    @ObservationIgnored private var speechStartedAt: Date?
    @ObservationIgnored private var speechElapsedBeforePause: TimeInterval = 0
    @ObservationIgnored private var speechTicker: Task<Void, Never>?

    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?
    @ObservationIgnored private var wasPlayingBeforeInterruption = false

    override convenience init() {
        self.init(resumeStore: InMemoryNarrationResumeStore())
    }

    init(resumeStore: any NarrationResumeStore) {
        self.resumeStore = resumeStore
        self.resumeState = resumeStore.load().sanitized()
        super.init()
        synthesizer.delegate = self
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance(), queue: .main
        ) { [weak self] note in
            let info = note.userInfo ?? [:]
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt
            MainActor.assumeIsolated {
                self?.handleInterruption(typeValue: typeValue, optionsValue: optionsValue)
            }
        }
    }

    var isActive: Bool { status == .playing || status == .paused || status == .loading }
    var isPlaying: Bool { status == .playing }
    var canSeek: Bool { kind == .recording && duration != nil }

    /// Completion belongs to the recording, independent of the visible screen or route.
    @ObservationIgnored var onCompletion: ((String) -> Void)?

    // Loaded metadata never prepares a player, activates audio, or automatically resumes.
    var resumableStoryID: String? { resumeState.lastStoryID }
    var resumableElapsed: Double {
        resumableStoryID.flatMap { resumeState.bookmarks[$0]?.elapsed } ?? 0
    }

    func hasSavedResume(for stop: HistoricalStop) -> Bool {
        guard let sourceID = Self.recordingSourceID(for: stop),
              let saved = resumeState.bookmarks[stop.id] else { return false }
        return saved.sourceID == sourceID
    }

    /// Explicit Home resume action. Both approved recordings support precise position restoration.
    /// Future synthesized speech is deliberately excluded instead of promising an exact seek.
    func resumeSavedStory(_ stop: HistoricalStop) {
        guard hasSavedResume(for: stop), prepare(stop) else { return }
        play()
    }

    func checkpointPlayback() {
        guard kind == .recording, let stopID, let sourceID = preparedSourceID else { return }
        if status == .finished {
            resumeState.bookmarks[stopID] = nil
            if resumeState.lastStoryID == stopID { resumeState.lastStoryID = nil }
        } else {
            // A pending seek's intended position wins over transient AVPlayer time zero.
            let seconds = pendingSeekTarget ?? (resumeSeconds > 0 ? resumeSeconds : elapsed)
            guard seconds.isFinite, seconds >= 0,
                  hasStartedPlayback || seconds > 0 || resumeState.bookmarks[stopID] != nil else { return }
            resumeState.bookmarks[stopID] = NarrationBookmark(sourceID: sourceID, elapsed: seconds)
            if hasStartedPlayback || seconds > 0 { resumeState.lastStoryID = stopID }
        }
        resumeStore.save(resumeState)
        lastCheckpointDate = Date()
    }

    private static func recordingSourceID(for stop: HistoricalStop) -> String? {
        guard let source = ProducedNarrationRelease.source(for: stop) else { return nil }
        if let digest = stop.narrationAudioSHA256 { return "produced:\(digest)" }
        if let recording = ProducedNarrationRelease.recording(for: stop) {
            return "produced:\(recording.audioSHA256)"
        }
        switch source {
        case .bundledAudio(let name): return "bundle:\(name)"
        case .remoteAudio(let url): return "url:\(url.absoluteString)"
        case .synthesizedSpeech: return nil
        }
    }

    // MARK: Loading

    /// Prepares narration for `stop`. Only the same stop, source and voice are reused; a change
    /// stops whatever was playing. Returns false when narration or its required voice is unavailable.
    @discardableResult
    func prepare(_ stop: HistoricalStop) -> Bool {
        let source = ProducedNarrationRelease.source(for: stop)
        if stopID == stop.id, preparedSource == source,
           preparedVoicePreference == stop.narrationVoicePreference, kind != nil {
            // Retry refreshes downloaded voices / failed recordings instead of keeping a failure.
            guard case .failed = status else { return true }
        }
        checkpointPlayback()
        tearDown()
        let sourceID = Self.recordingSourceID(for: stop)
        preparedSourceID = sourceID
        if let saved = resumeState.bookmarks[stop.id], saved.sourceID == sourceID {
            resumeSeconds = saved.elapsed
        } else {
            resumeState.bookmarks[stop.id] = nil
            if resumeState.lastStoryID == stop.id { resumeState.lastStoryID = nil }
            resumeStore.save(resumeState)
            resumeSeconds = 0
        }
        hasStartedPlayback = false
        isPersistentPlayerVisible = false
        stopID = stop.id
        title = stop.name
        guard let source else {
            kind = nil
            status = .idle
            return false
        }
        preparedSource = source
        preparedVoicePreference = stop.narrationVoicePreference
        switch source {
        case .remoteAudio(let url):
            loadRecording(url: url)
        case .bundledAudio(let fileName):
            let base = (fileName as NSString).deletingPathExtension
            let ext = (fileName as NSString).pathExtension
            if let url = Bundle.main.url(forResource: base, withExtension: ext.isEmpty ? nil : ext) {
                loadRecording(url: url)
            } else {
                kind = .recording
                status = .failed("Narration file \"\(fileName)\" is not in the app bundle.")
                return false
            }
        case .synthesizedSpeech(let text):
            kind = .synthesizedSpeech
            speechText = text
            speechPreference = stop.narrationVoicePreference
            speechVoice = Self.selectSpeechVoice(preference: speechPreference, from: AVSpeechSynthesisVoice.speechVoices())
            if speechPreference == .warmMaleEnglish, speechVoice == nil {
                status = .failed(Self.maleVoiceUnavailableMessage)
                return false
            }
            status = .idle
            duration = nil
            progress = 0
            elapsed = 0
        }
        return true
    }

    private func loadRecording(url: URL) {
        kind = .recording
        status = .loading
        duration = nil
        progress = 0
        elapsed = 0
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = true
        self.player = player

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            let status = item.status
            let seconds = item.duration.seconds
            let message = item.error?.localizedDescription
            Task { @MainActor [weak self] in
                guard let self, self.player?.currentItem === item else { return }
                switch status {
                case .readyToPlay:
                    if seconds.isFinite, seconds > 0 { self.duration = seconds }
                    if self.resumeSeconds > 0 {
                        let resume = min(self.resumeSeconds, self.duration ?? self.resumeSeconds)
                        self.resumeSeconds = 0
                        self.seek(to: resume)
                    }
                    if self.pendingPlayWhenReady && self.pendingSeekTarget == nil {
                        self.player?.play()
                        self.status = .playing
                        self.pendingPlayWhenReady = false
                    } else if self.status == .loading {
                        self.status = .paused
                    }
                case .failed:
                    self.status = .failed(message ?? "The narration could not be loaded.")
                default:
                    break
                }
            }
        }
        itemObservers.append(NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard self?.player?.currentItem === item else { return }
                self?.recordingDidFinish()
            }
        })
        itemObservers.append(NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] note in
            let message = (note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error)?.localizedDescription
            MainActor.assumeIsolated {
                guard self?.player?.currentItem === item else { return }
                self?.status = .failed(message ?? "Playback stopped unexpectedly.")
            }
        })
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard self?.player?.currentItem === item else { return }
                self?.recordingTimeDidChange(time.seconds)
            }
        }
    }

    // MARK: Transport

    func play() {
        guard kind != nil else { return }
        hasStartedPlayback = true
        isPersistentPlayerVisible = true
        activateSession()
        switch kind {
        case .recording:
            guard let player else { return }
            if status == .finished { seek(to: 0) }
            if player.currentItem?.status == .readyToPlay && pendingSeekTarget == nil && resumeSeconds == 0 {
                player.play()
                status = .playing
            } else {
                status = .loading
                pendingPlayWhenReady = true
            }
            checkpointPlayback()
        case .synthesizedSpeech:
            if synthesizer.isPaused {
                synthesizer.continueSpeaking()
            } else {
                if status == .finished || !synthesizer.isSpeaking {
                    speechElapsedBeforePause = 0
                    progress = 0
                    elapsed = 0
                    guard let utterance = Self.makeSpeechUtterance(text: speechText, voice: speechVoice, preference: speechPreference) else {
                        status = .failed(Self.maleVoiceUnavailableMessage)
                        deactivateSession()
                        return
                    }
                    activeUtterance = utterance
                    synthesizer.speak(utterance)
                }
            }
            speechStartedAt = Date()
            status = .playing
            startSpeechTicker()
        case nil:
            break
        }
    }

    func pause() {
        switch kind {
        case .recording:
            player?.pause()
            pendingPlayWhenReady = false
            if status == .playing || status == .loading { status = .paused }
        case .synthesizedSpeech:
            guard synthesizer.isSpeaking, !synthesizer.isPaused else { return }
            synthesizer.pauseSpeaking(at: .word)
            accumulateSpeechElapsed()
            speechTicker?.cancel()
            status = .paused
        case nil:
            break
        }
        checkpointPlayback()
    }

    /// Close is a reversible dismissal, not Stop: retain both in-memory and durable positions.
    func dismissPersistentPlayer() {
        pause()
        wasPlayingBeforeInterruption = false
        isPersistentPlayerVisible = false
        deactivateSession()
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    /// Stops playback and releases the audio session; the prepared stop is kept so play() restarts.
    func stop() {
        isPersistentPlayerVisible = false
        switch kind {
        case .recording:
            player?.pause()
            player?.seek(to: .zero)
            pendingPlayWhenReady = false
        case .synthesizedSpeech:
            activeUtterance = nil // Invalidate queued callbacks before another stop starts speaking.
            synthesizer.stopSpeaking(at: .immediate)
            speechTicker?.cancel()
        case nil:
            break
        }
        elapsed = 0
        progress = 0
        speechElapsedBeforePause = 0
        if kind != nil { status = .idle }
        resumeSeconds = 0
        pendingSeekTarget = nil
        seekGeneration += 1
        if let stopID {
            resumeState.bookmarks[stopID] = nil
            if resumeState.lastStoryID == stopID { resumeState.lastStoryID = nil }
            resumeStore.save(resumeState)
        }
        deactivateSession()
    }

    func skip(by seconds: TimeInterval) {
        guard canSeek, let duration else { return }
        seek(to: min(max(elapsed + seconds, 0), duration))
    }

    func seek(to seconds: TimeInterval) {
        guard canSeek, let player, seconds.isFinite else { return }
        let clamped = min(max(0, seconds), duration ?? seconds)
        resumeSeconds = 0
        pendingSeekTarget = clamped
        seekGeneration += 1
        let generation = seekGeneration
        elapsed = clamped
        if let duration, duration > 0 { progress = clamped / duration }
        if status == .finished { status = .paused }
        checkpointPlayback()
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self, weak player] finished in
            Task { @MainActor [weak self, weak player] in
                guard let self, let player, self.player === player, self.seekGeneration == generation else { return }
                self.pendingSeekTarget = nil
                if finished {
                    self.elapsed = clamped
                    if let duration = self.duration, duration > 0 { self.progress = clamped / duration }
                }
                if self.pendingPlayWhenReady, player.currentItem?.status == .readyToPlay {
                    player.play()
                    self.status = .playing
                    self.pendingPlayWhenReady = false
                }
                self.checkpointPlayback()
            }
        }
    }

    // MARK: Internals

    @ObservationIgnored private var pendingPlayWhenReady = false

    static let maleVoiceUnavailableMessage = "Download an English male voice in iPhone Settings → Accessibility → Read & Speak (or Spoken Content) → Voices → English, then tap Play again. You can read the narration below."

    static func selectSpeechVoice(preference: NarrationVoicePreference, from voices: [AVSpeechSynthesisVoice]) -> AVSpeechSynthesisVoice? {
        guard preference == .warmMaleEnglish else { return nil }
        let options = voices.map { voice in
            let quality: SpeechVoiceOption.Quality
            switch voice.quality {
            case .premium: quality = .premium
            case .enhanced: quality = .enhanced
            default: quality = .standard
            }
            return SpeechVoiceOption(identifier: voice.identifier, language: voice.language,
                                     isMale: voice.gender == .male, quality: quality,
                                     isNovelty: voice.voiceTraits.contains(.isNoveltyVoice),
                                     isPersonal: voice.voiceTraits.contains(.isPersonalVoice))
        }
        guard let selected = NarrationVoiceSelection.maleEnglishVoice(from: options) else { return nil }
        return voices.first { $0.identifier == selected.identifier }
    }

    static func makeSpeechUtterance(text: String, voice: AVSpeechSynthesisVoice?, preference: NarrationVoicePreference) -> AVSpeechUtterance? {
        if preference == .warmMaleEnglish, voice == nil { return nil }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * (preference == .warmMaleEnglish ? 0.92 : 0.95)
        utterance.pitchMultiplier = preference == .warmMaleEnglish ? 0.98 : 1
        utterance.preUtteranceDelay = preference == .warmMaleEnglish ? 0.15 : 0
        utterance.postUtteranceDelay = preference == .warmMaleEnglish ? 0.25 : 0
        utterance.prefersAssistiveTechnologySettings = false
        return utterance
    }

    private func recordingTimeDidChange(_ observedSeconds: Double) {
        if resumeSeconds > 0 || pendingSeekTarget != nil { return }
        // A queued pre-seek callback must not replace the just-restored position with zero.
        let seconds = player?.currentTime().seconds ?? observedSeconds
        guard seconds.isFinite else { return }
        elapsed = seconds
        if duration == nil, let d = player?.currentItem?.duration.seconds, d.isFinite, d > 0 { duration = d }
        if let duration, duration > 0 { progress = min(seconds / duration, 1) }
        if status == .loading, player?.timeControlStatus == .playing { status = .playing; pendingPlayWhenReady = false }
        if status == .paused, player?.timeControlStatus == .playing { status = .playing }
        if status == .playing, Date().timeIntervalSince(lastCheckpointDate) >= 5 { checkpointPlayback() }
    }

    private func recordingDidFinish() {
        if let stopID { onCompletion?(stopID) }
        status = .finished
        progress = 1
        if let duration { elapsed = duration }
        checkpointPlayback()
        deactivateSession()
    }

    private func startSpeechTicker() {
        speechTicker?.cancel()
        speechTicker = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled, self.status == .playing {
                self.elapsed = self.speechElapsedBeforePause + (self.speechStartedAt.map { Date().timeIntervalSince($0) } ?? 0)
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func accumulateSpeechElapsed() {
        if let started = speechStartedAt { speechElapsedBeforePause += Date().timeIntervalSince(started) }
        speechStartedAt = nil
        elapsed = speechElapsedBeforePause
    }

    fileprivate func speechDidProgress(characterEnd: Int, utterance: AVSpeechUtterance) {
        guard kind == .synthesizedSpeech, activeUtterance === utterance, !speechText.isEmpty else { return }
        // AVFoundation ranges use UTF-16, not Swift's grapheme-cluster count.
        progress = min(Double(characterEnd) / Double(speechText.utf16.count), 1)
    }

    fileprivate func speechDidFinish(utterance: AVSpeechUtterance) {
        guard kind == .synthesizedSpeech, activeUtterance === utterance else { return }
        accumulateSpeechElapsed()
        speechTicker?.cancel()
        activeUtterance = nil
        progress = 1
        duration = elapsed
        if let stopID { onCompletion?(stopID) }
        status = .finished
        deactivateSession()
    }

    fileprivate func speechDidCancel(utterance: AVSpeechUtterance) {
        guard kind == .synthesizedSpeech, activeUtterance === utterance, status != .idle else { return }
        activeUtterance = nil
        speechTicker?.cancel()
        status = .idle
    }

    private func handleInterruption(typeValue: UInt?, optionsValue: UInt?) {
        guard let typeValue, let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        switch type {
        case .began:
            wasPlayingBeforeInterruption = isPlaying
            if isPlaying { pause() }
        case .ended:
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue ?? 0)
            if wasPlayingBeforeInterruption, options.contains(.shouldResume) { play() }
            wasPlayingBeforeInterruption = false
        @unknown default:
            break
        }
    }

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
    }

    private func deactivateSession() {
        // Lets music ducked by `.duckOthers` come back up. Errors here are harmless.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func tearDown() {
        // Source replacement must not erase the outgoing durable bookmark.
        player?.pause()
        activeUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)
        speechTicker?.cancel()
        pendingPlayWhenReady = false
        pendingSeekTarget = nil
        seekGeneration += 1
        resumeSeconds = 0
        if kind != nil { deactivateSession() }
        if let timeObserver, let player { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        statusObservation = nil
        itemObservers.forEach(NotificationCenter.default.removeObserver)
        itemObservers.removeAll()
        player = nil
        kind = nil
        preparedSource = nil
        preparedSourceID = nil
        preparedVoicePreference = nil
        speechVoice = nil
        speechPreference = .systemDefault
        duration = nil
        progress = 0
        elapsed = 0
        status = .idle
    }
}

extension NarrationPlayer: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        let end = characterRange.location + characterRange.length
        Task { @MainActor in self.speechDidProgress(characterEnd: end, utterance: utterance) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speechDidFinish(utterance: utterance) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speechDidCancel(utterance: utterance) }
    }
}
