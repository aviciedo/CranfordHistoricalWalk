import AVFoundation
import Foundation
import Observation
import TourCore

/// Plays a stop's narration: a recorded file (remote or bundled) through `AVPlayer`, or — when no
/// recording exists — the stop's description read by `AVSpeechSynthesizer`. One instance is shared
/// app-wide (see `AppDependencies`) so the map sheet and the AR screen can never talk over each other.
///
/// Owns the audio session and interruption handling. Views never touch this directly; they go
/// through `NarrationViewModel`.
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
    /// stops whatever was playing. Returns false when the stop has nothing to narrate.
    @discardableResult
    func prepare(_ stop: HistoricalStop) -> Bool {
        if stopID == stop.id, kind != nil { return true }
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
                    let utterance = AVSpeechUtterance(string: speechText)
                    utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
                    utterance.prefersAssistiveTechnologySettings = false
                    synthesizer.speak(utterance)
                }
            }
            speechStartedAt = Date()
            startSpeechTicker()
            status = .playing
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
        seek(to: NarrationSeek.position(afterSkipping: seconds, from: elapsed, duration: duration))
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

    fileprivate func speechDidProgress(characterLocation: Int) {
        guard kind == .synthesizedSpeech, !speechText.isEmpty else { return }
        progress = min(Double(characterLocation) / Double(speechText.count), 1)
    }

    fileprivate func speechDidFinish() {
        guard kind == .synthesizedSpeech else { return }
        accumulateSpeechElapsed()
        speechTicker?.cancel()
        progress = 1
        status = .finished
        deactivateSession()
    }

    fileprivate func speechDidCancel() {
        guard kind == .synthesizedSpeech, status != .idle else { return }
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
        duration = nil
        progress = 0
        elapsed = 0
        status = .idle
    }
}

extension NarrationPlayer: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        let location = characterRange.location
        Task { @MainActor in self.speechDidProgress(characterLocation: location) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speechDidFinish() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speechDidCancel() }
    }
}
