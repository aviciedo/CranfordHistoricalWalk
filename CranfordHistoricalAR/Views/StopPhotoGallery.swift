import SwiftUI
import TourCore

/// One shared gallery for stop details reached from Home, Map, Stops or AR.
struct StopPhotoGallery: View {
    @Environment(AppNavigation.self) private var navigation
    let stop: HistoricalStop
    var isObscured = false
    @State private var expanded: ExpandedPhoto?
    private var photos: [HistoricalStopPhoto] { stop.galleryPhotos }
    private var selection: Int {
        get { min(max(0, navigation.photoSelections[stop.id] ?? 0), max(0, photos.count - 1)) }
        nonmutating set { navigation.photoSelections[stop.id] = newValue }
    }

    var body: some View {
        if photos.count < 2 {
            VStack(alignment: .leading, spacing: 8) {
                StopPhoto(stop: stop, height: 240, cornerRadius: 16)
                if let photo = photos.first { Text(photo.caption).font(.subheadline) }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                TabView(selection: Binding(get: { selection }, set: { selection = $0 })) {
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
                .overlay {
                    HStack {
                        photoArrow("chevron.left", label: "Previous photo", amount: -1)
                        Spacer()
                        photoArrow("chevron.right", label: "Next photo", amount: 1)
                    }
                    .padding(.horizontal, 8)
                }
                Text("\(selection + 1) of \(photos.count)")
                    .font(.caption).foregroundStyle(AppTheme.secondaryInk)
                    .accessibilityLabel("Photo \(selection + 1) of \(photos.count)")
                if photos.indices.contains(selection) {
                    let photo = photos[selection]
                    Text(photo.caption).font(.subheadline)
                    if let credit = photo.credit {
                        Text(credit).font(.caption).foregroundStyle(AppTheme.secondaryInk)
                    }
                }
            }
            .fullScreenCover(item: $expanded) { item in
                StopPhotoViewer(image: item.image, title: item.photo.caption, credit: item.photo.credit)
            }
        }
    }

    private func photoArrow(_ symbol: String, label: String, amount: Int) -> some View {
        Button { move(by: amount) } label: {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 52)
                .background(.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityLabel(label)
    }

    private func move(by amount: Int) {
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
