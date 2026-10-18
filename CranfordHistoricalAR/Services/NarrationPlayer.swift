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

    private(set) var stopID: String?
    private(set) var title: String = ""
    private(set) var kind: Kind?
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

    override init() {
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

    // MARK: Loading

    /// Prepares narration for `stop`. Re-preparing the same stop is a no-op; a different stop
    /// stops whatever was playing. Returns false when narration or its required voice is unavailable.
    @discardableResult
    func prepare(_ stop: HistoricalStop) -> Bool {
        if stopID == stop.id, kind != nil {
            // Retry refreshes downloaded voices / failed recordings instead of keeping a failure.
            guard case .failed = status else { return true }
        }
        tearDown()
        stopID = stop.id
        title = stop.name
        guard let source = stop.narrationSource else {
            kind = nil
            status = .idle
            return false
        }
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
                    if self.pendingPlayWhenReady {
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
            MainActor.assumeIsolated { self?.recordingDidFinish() }
        })
        itemObservers.append(NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] note in
            let message = (note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error)?.localizedDescription
            MainActor.assumeIsolated { self?.status = .failed(message ?? "Playback stopped unexpectedly.") }
        })
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] time in
            MainActor.assumeIsolated { self?.recordingTimeDidChange(time.seconds) }
        }
    }

    // MARK: Transport

    func play() {
        guard kind != nil else { return }
        activateSession()
        switch kind {
        case .recording:
            guard let player else { return }
            if status == .finished { player.seek(to: .zero) }
            player.play()
            status = player.currentItem?.status == .readyToPlay ? .playing : .loading
            if status == .loading { pendingPlayWhenReady = true }
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
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    /// Stops playback and releases the audio session; the prepared stop is kept so play() restarts.
    func stop() {
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
        deactivateSession()
    }

    func skip(by seconds: TimeInterval) {
        guard canSeek, let duration else { return }
        seek(to: min(max(elapsed + seconds, 0), duration))
    }

    func seek(to seconds: TimeInterval) {
        guard canSeek, let player else { return }
        let clamped = max(0, seconds)
        elapsed = clamped
        if let duration, duration > 0 { progress = clamped / duration }
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        if status == .finished { status = .paused }
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

    private func recordingTimeDidChange(_ seconds: Double) {
        guard seconds.isFinite else { return }
        elapsed = seconds
        if duration == nil, let d = player?.currentItem?.duration.seconds, d.isFinite, d > 0 { duration = d }
        if let duration, duration > 0 { progress = min(seconds / duration, 1) }
        if status == .loading, player?.timeControlStatus == .playing { status = .playing; pendingPlayWhenReady = false }
        if status == .paused, player?.timeControlStatus == .playing { status = .playing }
    }

    private func recordingDidFinish() {
        status = .finished
        progress = 1
        if let duration { elapsed = duration }
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
        if kind != nil { stop() }
        if let timeObserver, let player { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        statusObservation = nil
        itemObservers.forEach(NotificationCenter.default.removeObserver)
        itemObservers.removeAll()
        player = nil
        kind = nil
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
