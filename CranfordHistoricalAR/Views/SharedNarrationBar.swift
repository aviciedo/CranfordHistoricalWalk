import SwiftUI
import TourCore

/// One shared footer, always bound to the playing story rather than the walking destination.
struct SharedNarrationBar: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(TourViewModel.self) private var tour
    let availableHeight: CGFloat

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title2) private var transportSymbolSize: CGFloat = 36

    private var artworkSize: CGFloat { max(96, min(128, availableHeight * 0.14)) }

    var body: some View {
        let player = dependencies.narrationPlayer
        if player.isPersistentPlayerVisible, let id = player.stopID,
           let stop = tour.stop(withID: id) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)
                storyControls(for: stop)
                    .padding(.horizontal, 16).padding(.top, 16)
                if case .failed(let message) = player.status {
                    Text(message).font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16).padding(.top, 8)
                }
                Spacer(minLength: 0)
                NarrationSeekRail(stop: stop)
                    .frame(height: 44)
                    .padding(.horizontal, 16).padding(.bottom, 4)
            }
            // Content can grow for large text and errors; the host reserves its actual height.
            .frame(minHeight: max(180, min(220, availableHeight * 0.2)))
            .overlay(alignment: .topTrailing) {
                Button { player.dismissPersistentPlayer() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close player")
                .accessibilityHint("Pauses narration and saves your position")
                .accessibilityIdentifier("narration.closePlayer")
                .padding(.top, 4).padding(.trailing, 4)
            }
            .foregroundStyle(.white)
            .background(AppTheme.forest, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 12).padding(.top, 6).padding(.bottom, 4)
            .background(AppTheme.ivory)
            .accessibilityIdentifier("narration.persistentPlayer")
        }
    }

    @ViewBuilder
    private func storyControls(for stop: HistoricalStop) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) {
                ScrollingStoryTitle(text: stop.name)
                    .padding(.trailing, 44)
                HStack(spacing: 16) {
                    artwork(for: stop)
                    Spacer(minLength: 0)
                    playbackButton(for: stop)
                }
            }
        } else {
            HStack(alignment: .center, spacing: 16) {
                artwork(for: stop)
                VStack(alignment: .leading, spacing: 12) {
                    // The title reserves the close button's corner without wasting a full top row.
                    ScrollingStoryTitle(text: stop.name)
                        .padding(.trailing, 44)
                    playbackButton(for: stop)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func artwork(for stop: HistoricalStop) -> some View {
        StopListIllustration(stopID: stop.id, artwork: stop.artwork)
            .frame(width: artworkSize, height: artworkSize)
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
                    ProgressView().tint(AppTheme.forest)
                        .controlSize(.large)
                } else {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: min(48, transportSymbolSize), weight: .semibold))
                        .offset(x: player.isPlaying ? 0 : 2)
                }
            }
            .foregroundStyle(AppTheme.forest)
            .frame(width: 64, height: 64)
            .background(.white, in: Circle())
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(player.isPlaying ? "Pause narration" : "Play narration for \(stop.name)")
        .accessibilityValue(player.status == .loading ? "Loading" : "")
        .accessibilityIdentifier("narration.playPause")
    }
}

/// A full spoken accessibility label, with a slow visual marquee only when the title overflows.
private struct ScrollingStoryTitle: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    let text: String
    @State private var textWidth: CGFloat = 0
    @State private var startedAt = Date()
    @ScaledMetric(relativeTo: .title2) private var lineHeight: CGFloat = 34

    var body: some View {
        Group {
            if reduceMotion || dynamicTypeSize.isAccessibilitySize {
                Text(text).font(AppTheme.Fonts.title)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                GeometryReader { viewport in
                    let overflows = textWidth > viewport.size.width + 1
                    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !overflows || scenePhase != .active)) { context in
                        let distance = textWidth + 28
                        let cycle = Double(distance) / 26 + 1.5
                        let phase = max(0, context.date.timeIntervalSince(startedAt)).truncatingRemainder(dividingBy: cycle)
                        let offset = overflows ? min(distance, CGFloat(max(0, phase - 1.5)) * 26) : 0
                        HStack(spacing: 28) {
                            title
                            if overflows { title }
                        }
                        .offset(x: -offset)
                        .frame(width: viewport.size.width, height: viewport.size.height, alignment: .leading)
                    }
                    .clipped()
                    .background {
                        title.hidden().background {
                            GeometryReader { measurement in
                                Color.clear.preference(key: StoryTitleWidth.self, value: measurement.size.width)
                            }
                        }
                    }
                    .onChange(of: viewport.size.width) { _, _ in startedAt = Date() }
                }
                .frame(height: lineHeight)
                .onPreferenceChange(StoryTitleWidth.self) { width in
                    if abs(textWidth - width) > 0.5 { textWidth = width; startedAt = Date() }
                }
            }
        }
        .onChange(of: text) { _, _ in startedAt = Date() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { startedAt = Date() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .allowsHitTesting(false)
    }

    private var title: some View {
        Text(text).font(AppTheme.Fonts.title)
            .fixedSize(horizontal: true, vertical: false)
    }
}

private struct StoryTitleWidth: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// The rail stays visually thin, with a larger invisible touch target and VoiceOver adjustment.
private struct NarrationSeekRail: View {
    @Environment(AppDependencies.self) private var dependencies
    let stop: HistoricalStop
    @State private var scrubProgress: Double?

    var body: some View {
        let player = dependencies.narrationPlayer
        let canSeek = player.stopID == stop.id && player.canSeek
        GeometryReader { viewport in
            let progress = min(1, max(0, scrubProgress ?? player.progress))
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.28))
                Capsule().fill(.white).frame(width: viewport.size.width * CGFloat(progress))
            }
            .frame(height: 3)
            .frame(maxHeight: .infinity, alignment: .center)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Narration position for \(stop.name)")
        .accessibilityValue("\(Int(min(1, max(0, scrubProgress ?? player.progress)) * 100)) percent")
        .accessibilityHint(canSeek ? "Swipe up or down to move fifteen seconds" : "Seeking is currently unavailable")
        .accessibilityAdjustableAction { direction in
            guard canSeek else { return }
            switch direction {
            case .increment: player.skip(by: 15)
            case .decrement: player.skip(by: -15)
            @unknown default: break
            }
        }
        .onChange(of: player.stopID) { _, _ in scrubProgress = nil }
    }
}
