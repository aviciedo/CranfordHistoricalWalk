import SwiftUI
import TourCore

/// One shared gallery for stop details reached from Home, Map, Stops or AR.
struct StopPhotoGallery: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    let stop: HistoricalStop
    var isObscured = false
    @State private var selection = 0
    @State private var isPaused = false
    @State private var isVisible = false
    @State private var expanded: ExpandedPhoto?

    private var photos: [HistoricalStopPhoto] { stop.galleryPhotos }
    private var rotates: Bool {
        photos.count > 1 && isVisible && !isObscured && !isPaused && expanded == nil
            && scenePhase == .active && !reduceMotion && !voiceOver
    }
    private var rotationKey: String { "\(stop.id)|\(selection)|\(rotates)" }

    var body: some View {
        if photos.count < 2 {
            StopPhoto(stop: stop, height: 240, cornerRadius: 16)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                TabView(selection: $selection) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                        GalleryPhotoPage(stop: stop, photo: photo, isSelected: index == selection) { image in
                            expanded = ExpandedPhoto(image: image, photo: photo)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 240)
                .background(AppTheme.playerSurface, in: RoundedRectangle(cornerRadius: 16))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                HStack(spacing: 8) {
                    Button { move(by: -1) } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 44)
                    }.accessibilityLabel("Previous photo")
                    Text("\(selection + 1) of \(photos.count)")
                        .font(.subheadline).monospacedDigit()
                        .accessibilityLabel("Photo \(selection + 1) of \(photos.count)")
                    Button { move(by: 1) } label: {
                        Image(systemName: "chevron.right").frame(width: 44, height: 44)
                    }.accessibilityLabel("Next photo")
                    Spacer(minLength: 0)
                    // With VoiceOver or Reduce Motion enabled, photos are always advanced manually.
                    if !reduceMotion && !voiceOver {
                        Button { isPaused.toggle() } label: {
                            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(isPaused ? "Play slideshow" : "Pause slideshow")
                    }
                }
                .buttonStyle(.plain)
                if photos.indices.contains(selection) {
                    let photo = photos[selection]
                    Text(photo.caption).font(.subheadline)
                    if let credit = photo.credit {
                        Text(credit).font(.caption).foregroundStyle(AppTheme.secondaryInk)
                    }
                }
            }
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
            .onChange(of: stop.id) { _, _ in selection = 0; isPaused = false }
            .task(id: rotationKey) {
                guard rotates else { return }
                do { try await Task.sleep(for: .seconds(6)) } catch { return }
                guard !Task.isCancelled, rotates else { return }
                // Changing the selected page restarts the delay, including after a manual swipe.
                selection = (selection + 1) % photos.count
            }
            .fullScreenCover(item: $expanded) { item in
                StopPhotoViewer(image: item.image, title: item.photo.caption, credit: item.photo.credit)
            }
        }
    }

    private func move(by amount: Int) {
        isPaused = true
        selection = (selection + amount + photos.count) % photos.count
    }

    private struct ExpandedPhoto: Identifiable {
        let image: LoadedImage
        let photo: HistoricalStopPhoto
        var id: String { photo.id }
    }
}

private struct GalleryPhotoPage: View {
    @Environment(AppDependencies.self) private var dependencies
    let stop: HistoricalStop
    let photo: HistoricalStopPhoto
    let isSelected: Bool
    let onOpen: (LoadedImage) -> Void
    @State private var image: LoadedImage?
    @State private var isLoading = true

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let image {
                    Button { onOpen(image) } label: {
                        // Keep the whole photograph visible, especially portrait photographs.
                        Image(uiImage: image.image).resizable().scaledToFit()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Enlarge \(photo.caption)")
                    .accessibilityHint("Opens a photo with pinch to zoom and a Close button")
                } else if isLoading {
                    ProgressView().frame(width: proxy.size.width, height: proxy.size.height)
                } else {
                    Label("Photo unavailable", systemImage: "photo")
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .foregroundStyle(AppTheme.secondaryInk)
                }
            }
        }
        .task(id: isSelected) {
            guard isSelected else { image = nil; return }
            isLoading = true
            let loaded = await dependencies.imageLoader.image(for: photo, at: stop)
            guard !Task.isCancelled else { return }
            image = loaded
            isLoading = false
        }
    }
}
