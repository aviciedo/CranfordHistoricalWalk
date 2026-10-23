import SwiftUI
import TourCore

/// The rasterized RealityKit sign, in post and plaque-card forms. The interactive
/// reading and photo experience is shared by maps, stop lists and AR via StopDetailView.
struct HistoricalSignView: View {
    enum Style { case arTexture, arPlaqueCard, activationMarker, windowBonus }

    let stop: HistoricalStop
    var image: LoadedImage?
    var style: Style = .arTexture

    /// Logical width of the AR texture in points; keeps text crisp on the plane.
    static let textureWidth: CGFloat = 720

    var body: some View {
        switch style {
        case .arTexture: textureBody
        case .arPlaqueCard: plaqueCardBody
        case .activationMarker: activationMarkerBody
        case .windowBonus: windowBonusBody
        }
    }

    private var windowBonusBody: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("UNLOCKED HERE", systemImage: "sparkles").font(.system(size: 22, weight: .semibold))
                Spacer()
                Image(systemName: "xmark.circle.fill").font(.system(size: 34))
            }
            Text(stop.name).font(.system(size: 44, weight: .semibold, design: .serif))
            Label("A little more history", systemImage: "photo.on.rectangle.angled")
                .font(.system(size: 34, weight: .medium))
            Text("Bonus photographs, video and stories will appear here.")
                .font(.system(size: 28)).lineSpacing(4)
            Spacer(minLength: 0)
            Text("TEST PLACEHOLDER · TAP TO PREVIEW").font(.system(size: 20, weight: .medium))
        }
        .foregroundStyle(AppTheme.ivory).padding(40)
        .frame(width: 720, height: 470)
        .background(AppTheme.forest.opacity(0.72), in: RoundedRectangle(cornerRadius: 24))
        .environment(\.colorScheme, .light)
    }

    /// This is the tappable RealityKit marker, not a button that can fake a visit from home.
    private var activationMarkerBody: some View {
        VStack(spacing: 20) {
            Image(systemName: "viewfinder.circle.fill")
                .font(.system(size: 92, weight: .light))
                .foregroundStyle(AppTheme.forest)
            Text("Stop \(stop.order)")
                .font(.system(size: 28, weight: .medium))
            Text(stop.name)
                .font(.system(size: 48, weight: .semibold, design: .serif))
                .multilineTextAlignment(.center)
            Text("Tap to discover")
                .font(.system(size: 34, weight: .semibold))
        }
        .foregroundStyle(AppTheme.forest)
        .padding(44).frame(width: Self.textureWidth)
        .background(AppTheme.ivory, in: RoundedRectangle(cornerRadius: 36))
        .environment(\.colorScheme, .light)
    }

    // MARK: AR texture layout

    private var textureBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    if let date = stop.displayDate {
                        Text(date)
                            .font(.system(size: 46, weight: .semibold, design: .serif))
                            .foregroundStyle(SignPalette.brass)
                    }
                    Text(stop.isSample ? "SAMPLE HISTORIC SITE" : "CRANFORD HISTORIC SITE")
                        .font(.system(size: 20, weight: .semibold))
                        .tracking(5)
                        .foregroundStyle(SignPalette.inkMuted)
                }
                Spacer()
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(SignPalette.inkMuted.opacity(0.8))
                    .accessibilityHidden(true)
            }
            .padding(.bottom, 14)

            Text(stop.name)
                .font(.system(size: 44, weight: .bold, design: .serif))
                .foregroundStyle(SignPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 14)

            Text(stop.address)
                .font(.system(size: 22))
                .foregroundStyle(SignPalette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 16)

            Rectangle().fill(SignPalette.brass).frame(height: 3).padding(.bottom, 18)

            Text(stop.shortDescription)
                .font(.system(size: 27, weight: .regular, design: .serif))
                .foregroundStyle(SignPalette.ink)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            // No empty image frame when there is no image (spec §10).
            if let image {
                SignImage(image: image, cornerRadius: 14)
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .padding(.top, 22)
            }

            HStack {
                Image(systemName: "hand.tap")
                Text("Tap the sign to read more")
                Spacer()
                if stop.isSample {
                    Text("SAMPLE DATA").tracking(2)
                }
            }
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(SignPalette.inkMuted)
            .padding(.top, 24)
        }
        .padding(40)
        .frame(width: HistoricalSignView.textureWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(LinearGradient(colors: [SignPalette.paper, SignPalette.paperDeep], startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .inset(by: 10)
                .strokeBorder(SignPalette.brass.opacity(0.9), lineWidth: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(SignPalette.ink.opacity(0.35), lineWidth: 2)
        )
        .environment(\.colorScheme, .light)
    }

    // MARK: Plaque-anchored popup (no post; sits above the door)

    private var plaqueCardBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    if let date = stop.displayDate {
                        Text(date)
                            .font(.system(size: 40, weight: .semibold, design: .serif))
                            .foregroundStyle(SignPalette.brass)
                    }
                    Text(stop.isSample ? "SAMPLE HISTORIC SITE" : "CRANFORD HISTORIC SITE")
                        .font(.system(size: 18, weight: .semibold))
                        .tracking(4)
                        .foregroundStyle(SignPalette.inkMuted)
                }
                Spacer()
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(SignPalette.inkMuted.opacity(0.85))
                    .accessibilityHidden(true)
            }
            .padding(.bottom, 12)

            Text(stop.name)
                .font(.system(size: 40, weight: .bold, design: .serif))
                .foregroundStyle(SignPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 12)

            Text(stop.address)
                .font(.system(size: 20))
                .foregroundStyle(SignPalette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 14)

            Rectangle().fill(SignPalette.brass).frame(height: 3).padding(.bottom, 16)

            Text(stop.shortDescription)
                .font(.system(size: 24, weight: .regular, design: .serif))
                .foregroundStyle(SignPalette.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Text("Tap to read more")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(SignPalette.inkMuted)
                .padding(.top, 20)
        }
        .padding(36)
        .frame(width: HistoricalSignView.textureWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [SignPalette.paper, SignPalette.paperDeep], startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .inset(by: 10)
                .strokeBorder(SignPalette.brass.opacity(0.9), lineWidth: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(SignPalette.ink.opacity(0.35), lineWidth: 2)
        )
        .environment(\.colorScheme, .light)
    }

}

struct OnSiteBonusPreview: View {
    let stop: HistoricalStop
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                Label("Unlocked on site", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                Text("A little more history").font(.system(.largeTitle, design: .serif).weight(.semibold))
                Text(stop.name).font(.title3)
                Image(systemName: "photo.on.rectangle.angled").font(.system(size: 70, weight: .light))
                    .frame(maxWidth: .infinity, minHeight: 170)
                    .background(AppTheme.playerSurface, in: RoundedRectangle(cornerRadius: 18))
                Text("This is a test placeholder for future photographs, video or additional narration.")
                    .font(.body).foregroundStyle(AppTheme.secondaryInk)
                Text("You found the plaque to unlock this extra here.").font(.subheadline)
                Spacer()
            }
            .padding(24).foregroundStyle(AppTheme.ink).background(AppTheme.parchment)
            .navigationTitle("On-site extra").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { ScreenBackButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { ScreenHomeButton() }
            }
        }
        .dismissOnReturnHome()
    }
}

/// Shared details presentation used from maps, stops, audio and the AR screen.
struct HistoricalSignSheet: View {
    let stop: HistoricalStop
    var onStartDiscovery: (() -> Void)? = nil

    var body: some View {
        StopDetailView(stop: stop, onStartDiscovery: onStartDiscovery)
    }
}

/// Resolves local or remote artwork without leaving a blank frame when no image exists.
struct StopPhoto: View {
    @Environment(AppDependencies.self) private var dependencies
    let stop: HistoricalStop
    var height: CGFloat = 160
    var cornerRadius: CGFloat = 12
    var width: CGFloat? = nil
    var contentMode: ContentMode = .fill
    @State private var image: LoadedImage?

    var body: some View {
        Group {
            if let image {
                ExpandableStopImage(image: image, title: stop.name, cornerRadius: cornerRadius, contentMode: contentMode)
                    .frame(width: width, height: height)
                    .frame(maxWidth: width == nil ? .infinity : width)
                    .clipped()
            }
        }
        .task(id: stop.id) {
            image = dependencies.imageLoader.cachedImage(for: stop)
            if image == nil { image = await dependencies.imageLoader.image(for: stop) }
        }
    }
}

/// Image with a clear "PLACEHOLDER" ribbon when the asset is not real history (spec §10).
struct SignImage: View {
    let image: LoadedImage
    var cornerRadius: CGFloat
    var contentMode: ContentMode = .fill

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(uiImage: image.image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
                .clipped()
            if image.isPlaceholder {
                Text(image.kind == .illustration ? "PLACEHOLDER ILLUSTRATION" : "PLACEHOLDER IMAGE")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.55), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(.black.opacity(0.15), lineWidth: 1))
    }
}

enum SignPalette {
    static let paper = AppTheme.ivory
    static let paperDeep = AppTheme.sand
    static let ink = AppTheme.forest
    static let inkMuted = Color(red: 0.40, green: 0.37, blue: 0.32)
    static let brass = AppTheme.forest
}
