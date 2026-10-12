import SwiftUI
import TourCore

/// The historical sign's content (spec §8). Rendered two ways:
/// - `.arTexture`: fixed-width, high-contrast layout rasterized by `ImageRenderer` onto the AR plane.
/// - `.sheet`: scrollable, interactive version shown when the user taps the AR sign or arrives
///   while on the map (also the accessibility-friendly path).
struct HistoricalSignView: View {
    enum Style { case arTexture, arPlaqueCard, sheet }

    let stop: HistoricalStop
    var image: LoadedImage?
    var style: Style = .sheet
    var onClose: (() -> Void)? = nil
    var onMarkVisited: (() -> Void)? = nil
    var isVisited = false
    var continueTitle = "Continue to next stop"

    /// Logical width of the AR texture in points; keeps text crisp on the plane.
    static let textureWidth: CGFloat = 720

    var body: some View {
        switch style {
        case .arTexture: textureBody
        case .arPlaqueCard: plaqueCardBody
        case .sheet: sheetBody
        }
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

            Rectangle().fill(SignPalette.brass).frame(height: 3).padding(.bottom, 18)

            Text(stop.shortDescription)
                .font(.system(size: 27, weight: .regular, design: .serif))
                .foregroundStyle(SignPalette.ink)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            if let plaque = stop.plaque, plaque.isUsable {
                plaqueQuote(plaque, labelSize: 18, quoteSize: 26)
                    .padding(.top, 20)
            }

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

            Rectangle().fill(SignPalette.brass).frame(height: 3).padding(.bottom, 16)

            Text(stop.shortDescription)
                .font(.system(size: 24, weight: .regular, design: .serif))
                .foregroundStyle(SignPalette.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if !stop.longDescription.isEmpty {
                Text(stop.longDescription)
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundStyle(SignPalette.ink)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
            }

            if let plaque = stop.plaque, plaque.isUsable {
                plaqueQuote(plaque, labelSize: 16, quoteSize: 28)
                    .padding(.top, 18)
            }
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

    private func plaqueQuote(_ plaque: StopPlaque, labelSize: CGFloat, quoteSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(plaque.quoteLabel.uppercased())
                .font(.system(size: labelSize, weight: .semibold))
                .tracking(2)
                .foregroundStyle(SignPalette.inkMuted)
            Text("“\(plaque.transcription)”")
                .font(.system(size: quoteSize, weight: .regular, design: .serif).italic())
                .foregroundStyle(SignPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SignPalette.brass.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Sheet layout

    private var sheetBody: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let date = stop.displayDate {
                            Text(date).font(AppTheme.Fonts.display(34)).foregroundStyle(AppTheme.brass)
                        }
                        EyebrowText(stop.isSample ? "Sample historic site" : "Cranford historic site", color: .secondary)
                        Text(stop.name)
                            .font(AppTheme.Fonts.display(30))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let image {
                        SignImage(image: image, cornerRadius: 16)
                            .frame(height: 220)
                            .frame(maxWidth: .infinity)
                    }

                    NarrationControls(stop: stop)

                    if let plaque = stop.plaque, plaque.isUsable {
                        plaqueQuote(plaque, labelSize: 12, quoteSize: 20)
                    }

                    Text(stop.longDescription.isEmpty ? stop.shortDescription : stop.longDescription)
                        .font(.system(.body, design: .serif))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 4) {
                        Label(stop.address, systemImage: "mappin.and.ellipse")
                        if stop.isSample {
                            Label("Placeholder content — not verified history.", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(AppTheme.warning)
                        }
                        if stop.coordinatesUnverified {
                            Label("Coordinates are unverified — not a surveyed site position.", systemImage: "questionmark.circle")
                                .foregroundStyle(AppTheme.warning)
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    if let onMarkVisited {
                        VStack(spacing: 8) {
                            if isVisited {
                                Label("Visited", systemImage: "checkmark.circle.fill")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(AppTheme.visited)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Button(action: onMarkVisited) {
                                Label(isVisited ? continueTitle : "Mark as visited", systemImage: isVisited ? "arrow.right.circle" : "checkmark.circle")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.heritageGreen)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(20)
            }
            .background(AppTheme.parchment)
            .toolbar {
                if let onClose {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", action: onClose)
                    }
                }
            }
        }
    }
}

/// Sheet wrapper that resolves artwork through the app's `ImageLoader` and offers
/// "Mark as visited / Continue" for the current stop (spec §10, §11).
struct HistoricalSignSheet: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(TourViewModel.self) private var tour
    @Environment(\.dismiss) private var dismiss
    let stop: HistoricalStop
    /// Invoked after the sheet closes because the user continued to the next stop.
    var onContinue: (() -> Void)? = nil
    @State private var image: LoadedImage?

    var body: some View {
        let isCurrent = stop.id == tour.currentStop?.id
        HistoricalSignView(
            stop: stop,
            image: image,
            style: .sheet,
            onClose: { dismiss() },
            onMarkVisited: isCurrent ? {
                dismiss()
                tour.completeCurrentStopAndAdvance()
                onContinue?()
            } : nil,
            isVisited: tour.isCompleted(stop),
            continueTitle: tour.nextStop == nil ? "Finish tour" : "Continue to next stop"
        )
        .task(id: stop.id) {
            image = dependencies.imageLoader.cachedImage(for: stop)
            if image == nil { image = await dependencies.imageLoader.image(for: stop) }
        }
    }
}

/// Loads a stop's photograph (asset `imageName` or remote URL) and shows it only when one exists.
/// Placed under the stop name and above `NarrationControls`.
struct StopPhoto: View {
    @Environment(AppDependencies.self) private var dependencies
    let stop: HistoricalStop
    var height: CGFloat = 160
    var cornerRadius: CGFloat = 12
    @State private var image: LoadedImage?

    var body: some View {
        Group {
            if let image {
                SignImage(image: image, cornerRadius: cornerRadius)
                    .frame(height: height)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Photograph of \(stop.name)")
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

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(uiImage: image.image)
                .resizable()
                .scaledToFill()
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
    static let paper = Color(red: 0.97, green: 0.95, blue: 0.90)
    static let paperDeep = Color(red: 0.92, green: 0.88, blue: 0.80)
    static let ink = Color(red: 0.13, green: 0.12, blue: 0.11)
    static let inkMuted = Color(red: 0.40, green: 0.37, blue: 0.32)
    static let brass = Color(red: 0.68, green: 0.52, blue: 0.24)
}
