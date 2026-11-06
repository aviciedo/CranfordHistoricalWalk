import SwiftUI
import TourCore

/// Shared transport follows the playing story, independently of the walking destination.
struct SharedNarrationBar: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(TourViewModel.self) private var tour
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let availableHeight: CGFloat
    @ScaledMetric(relativeTo: .title2) private var transportSymbolSize: CGFloat = 32

    private var artworkSize: CGFloat { min(72, max(56, availableHeight * 0.085)) }

    var body: some View {
        let player = dependencies.narrationPlayer
        if player.isPersistentPlayerVisible, let id = player.stopID,
           let stop = tour.stop(withID: id) {
            VStack(alignment: .leading, spacing: 4) {
                storyControls(for: stop)
                    .padding(.leading, 16).padding(.trailing, 44).padding(.top, 12)
                if case .failed(let message) = player.status {
                    Text(message).font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16).padding(.top, 4)
                }
                HStack(spacing: 4) {
                    skipButton(backward: true)
                    NarrationSeekRail(stop: stop)
                    skipButton(backward: false)
                }
                .padding(.horizontal, 8).padding(.bottom, 8)
            }
            .overlay(alignment: .topTrailing) {
                Button { player.dismissPersistentPlayer() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 23, weight: .medium))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close player")
                .accessibilityHint("Pauses narration and saves your position")
                .accessibilityIdentifier("narration.closePlayer")
            }
            .foregroundStyle(AppTheme.ivory)
            .background(AppTheme.forest, in: RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 12).padding(.top, 6).padding(.bottom, 4)
            .background(AppTheme.ivory)
            .accessibilityIdentifier("narration.persistentPlayer")
        }
    }

    @ViewBuilder
    private func storyControls(for stop: HistoricalStop) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                storyTitle(stop.name)
                HStack(spacing: 12) {
                    artwork(for: stop)
                    Spacer(minLength: 0)
                    playbackButton(for: stop)
                }
            }
        } else {
            HStack(alignment: .center, spacing: 10) {
                artwork(for: stop)
                storyTitle(stop.name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                playbackButton(for: stop)
            }
        }
    }

    private func storyTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(.title3, design: .serif).weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)
    }

    private func artwork(for stop: HistoricalStop) -> some View {
        StopListIllustration(stopID: stop.id, artwork: stop.artwork, usesInk: true)
            .padding(3)
            .frame(width: artworkSize, height: artworkSize)
            .background(AppTheme.ivory, in: RoundedRectangle(cornerRadius: 12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityHidden(true)
    }

    private func playbackButton(for stop: HistoricalStop) -> some View {
        let player = dependencies.narrationPlayer
        return Button {
            guard player.prepare(stop) else { return }
            player.togglePlayPause()
        } label: {
            Group {
                if player.status == .loading {
                    ProgressView().tint(AppTheme.forest).controlSize(.large)
                } else {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: min(40, transportSymbolSize), weight: .semibold))
                        .offset(x: player.isPlaying ? 0 : 2)
                }
            }
            .foregroundStyle(AppTheme.forest)
            .frame(width: 64, height: 64)
            .background(AppTheme.ivory, in: Circle())
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(player.isPlaying ? "Pause narration" : "Play narration for \(stop.name)")
        .accessibilityValue(player.status == .loading ? "Loading" : "")
        .accessibilityIdentifier("narration.playPause")
    }

    private func skipButton(backward: Bool) -> some View {
        let player = dependencies.narrationPlayer
        return Button {
            player.skip(by: backward ? -NarrationPlayer.skipInterval : NarrationPlayer.skipInterval)
        } label: {
            Image(systemName: backward ? "gobackward.15" : "goforward.15")
                .font(.system(size: 20, weight: .regular))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!player.canSeek)
        .opacity(player.canSeek ? 0.9 : 0.4)
        .accessibilityLabel(backward ? "Back 15 seconds" : "Forward 15 seconds")
        .accessibilityIdentifier(backward ? "narration.skipBackward" : "narration.skipForward")
    }
}

/// Seek rail and actual elapsed/total time share a 44pt target; scrubbing previews the time.
private struct NarrationSeekRail: View {
    @Environment(AppDependencies.self) private var dependencies
    @ScaledMetric(relativeTo: .caption) private var timelineHeight: CGFloat = 44
    let stop: HistoricalStop
    @State private var scrubProgress: Double?

    var body: some View {
        let player = dependencies.narrationPlayer
        let canSeek = player.stopID == stop.id && player.canSeek
        let progress = min(1, max(0, scrubProgress ?? player.progress))
        let elapsed = scrubProgress.flatMap { value in player.duration.map { value * $0 } } ?? player.elapsed
        GeometryReader { viewport in
            VStack(spacing: 5) {
                ZStack(alignment: .leading) {
                    Capsule().fill(AppTheme.ivory.opacity(0.3))
                    Capsule().fill(AppTheme.ivory).frame(width: viewport.size.width * CGFloat(progress))
                }
                .frame(height: 3)
                ViewThatFits(in: .horizontal) {
                    timeLabels(elapsed: elapsed, duration: player.duration, stacked: false)
                    timeLabels(elapsed: elapsed, duration: player.duration, stacked: true)
                }
                .font(.caption.monospacedDigit())
            }
            .frame(width: viewport.size.width, height: viewport.size.height)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard canSeek, viewport.size.width > 0 else { return }
                    scrubProgress = min(1, max(0, Double(value.location.x / viewport.size.width)))
                }
                .onEnded { value in
                    if canSeek, let duration = player.duration, viewport.size.width > 0 {
                        let target = min(1, max(0, Double(value.location.x / viewport.size.width)))
                        player.seek(to: target * duration)
                    }
                    scrubProgress = nil
                })
        }
        .frame(height: max(44, timelineHeight))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Narration position for \(stop.name)")
        .accessibilityValue("\(NarrationPlaybackTime.text(elapsed)) elapsed; \(NarrationPlaybackTime.text(player.duration)) total")
        .accessibilityHint(canSeek ? "Swipe up or down to move fifteen seconds" : "Seeking is currently unavailable")
        .accessibilityAdjustableAction { direction in
            guard canSeek else { return }
            switch direction {
            case .increment: player.skip(by: NarrationPlayer.skipInterval)
            case .decrement: player.skip(by: -NarrationPlayer.skipInterval)
            @unknown default: break
            }
        }
        .onChange(of: player.stopID) { _, _ in scrubProgress = nil }
        .onChange(of: player.canSeek) { _, _ in scrubProgress = nil }
    }

    @ViewBuilder
    private func timeLabels(elapsed: TimeInterval, duration: TimeInterval?, stacked: Bool) -> some View {
        if stacked {
            VStack(alignment: .leading, spacing: 0) {
                Text(NarrationPlaybackTime.text(elapsed)).fixedSize()
                Text(NarrationPlaybackTime.text(duration)).fixedSize()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack {
                Text(NarrationPlaybackTime.text(elapsed)).fixedSize()
                Spacer(minLength: 8)
                Text(NarrationPlaybackTime.text(duration)).fixedSize()
            }
        }
    }
}

enum NarrationPlaybackTime {
    static func text(_ seconds: TimeInterval?) -> String {
        guard let seconds, seconds.isFinite,
              let value = Int(exactly: max(0, seconds).rounded(.down)) else { return "--:--" }
        let remainder = String(format: "%02d", value % 60)
        if value >= 3600 {
            return "\(value / 3600):\(String(format: "%02d", value / 60 % 60)):\(remainder)"
        }
        return "\(value / 60):\(remainder)"
    }
}
