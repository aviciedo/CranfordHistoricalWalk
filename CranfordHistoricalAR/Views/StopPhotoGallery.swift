import SwiftUI
import TourCore

/// One shared gallery for stop details reached from Home, Map, Stops or AR.
struct StopPhotoGallery: View {
    @Environment(AppNavigation.self) private var navigation
    let stop: HistoricalStop
    let height: CGFloat
    var isObscured = false
    @State private var expanded: ExpandedPhoto?
    private var photos: [HistoricalStopPhoto] { stop.galleryPhotos }
    private var selection: Int {
        get { min(max(0, navigation.photoSelections[stop.id] ?? 0), max(0, photos.count - 1)) }
        nonmutating set { navigation.photoSelections[stop.id] = newValue }
    }

    var body: some View {
        if photos.isEmpty {
            StopPhoto(stop: stop, height: height, cornerRadius: 16, contentMode: .fit)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { viewport in
                    TabView(selection: Binding(get: { selection }, set: { selection = $0 })) {
                        ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                            GalleryPhotoPage(stop: stop, photo: photo, isSelected: index == selection,
                                             positionDescription: "Photo \(index + 1) of \(photos.count)") { image in
                                expanded = ExpandedPhoto(image: image, photo: photo)
                            }
                            .frame(width: viewport.size.width, height: viewport.size.height)
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
                .frame(height: height)
                .background(AppTheme.playerSurface, in: RoundedRectangle(cornerRadius: 16))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay {
                    if photos.count > 1 {
                        HStack {
                            photoArrow("chevron.left", label: "Previous photo", amount: -1)
                            Spacer()
                            photoArrow("chevron.right", label: "Next photo", amount: 1)
                        }
                        .padding(.horizontal, 12)
                    }
                }
                if photos.indices.contains(selection) {
                    let photo = photos[selection]
                    VStack(alignment: .leading, spacing: 4) {
                        Text(photo.caption).font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        if let credit = photo.credit {
                            Text(credit).font(.caption).foregroundStyle(AppTheme.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .onChange(of: navigation.homeReturnID) { _, _ in expanded = nil }
            .fullScreenCover(item: $expanded) { item in
                StopPhotoViewer(image: item.image, title: item.photo.caption, credit: item.photo.credit)
            }
        }
    }

    private func photoArrow(_ symbol: String, label: String, amount: Int) -> some View {
        Button { move(by: amount) } label: {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.forest)
                .frame(width: 44, height: 44)
                .background(.white, in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                .contentShape(Circle())
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
    let positionDescription: String
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
                    .accessibilityValue(positionDescription)
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
