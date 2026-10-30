import SwiftUI

/// Warm-white surfaces, forest ink and hunter-green transport from the selected walking-screen reference.
enum AppTheme {
    static let accent = Color("AccentColor")
    static let forest = Color(red: 48 / 255, green: 70 / 255, blue: 57 / 255)
    static let riverBlue = Color(red: 82 / 255, green: 119 / 255, blue: 132 / 255)
    static let ivory = Color(red: 247 / 255, green: 244 / 255, blue: 239 / 255)
    static let sage = Color(red: 107 / 255, green: 127 / 255, blue: 91 / 255)
    static let sand = Color(red: 217 / 255, green: 201 / 255, blue: 178 / 255)
    static let terracotta = Color(red: 201 / 255, green: 111 / 255, blue: 79 / 255)
    static let ink = Color(light: forest, dark: ivory)
    /// Interior of the sketchbook-paper asset, including UIKit curl backing and margins.
    static let sketchbookPaper = Color(red: 248 / 255, green: 242 / 255, blue: 230 / 255)
    static let parchment = ivory
    static let surface = ivory
    static let playerSurface = ivory
    /// Navigation stays warm white with fixed high-contrast labels, including in dark appearance.
    static let navigationBackground = ivory
    static let navigationInactive = Color(red: 110 / 255, green: 113 / 255, blue: 105 / 255)
    static let secondaryInk = Color(light: Color(red: 0.34, green: 0.37, blue: 0.33), dark: sand)
    // Semantic aliases keep the existing AR and developer screens on the same palette.
    static let brass = Color(light: forest, dark: sand)
    static let heritageGreen = forest
    static let visited = Color(light: forest, dark: Color(red: 0.72, green: 0.81, blue: 0.66))
    static let warning = Color(light: Color(red: 0.58, green: 0.25, blue: 0.15), dark: Color(red: 0.94, green: 0.65, blue: 0.49))

    enum Fonts {
        static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .serif) }
        static let eyebrow: Font = .system(.caption, design: .default).weight(.semibold)
        static let title: Font = .system(.title2, design: .serif).weight(.semibold)
        static let body: Font = .system(.body, design: .default)
        static let metric: Font = .system(.title3, design: .rounded).weight(.semibold)
    }

    static let cornerRadius: CGFloat = 20
}

extension Color {
    /// Dynamic color helper without an asset catalog entry.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

/// Small uppercase label used for "NEXT STOP", "CURRENT", etc.
struct EyebrowText: View {
    let text: String
    var color: Color = .secondary

    init(_ text: String, color: Color = .secondary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(AppTheme.Fonts.eyebrow)
            .tracking(1.4)
            .foregroundStyle(color)
    }
}

/// Translucent card used by the navigation panel and overlays.
struct GlassCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
            )

    }
}

/// Shared full-width action row used on Home and within a stop's story menu.
/// Keep typography, icon column, chevron and touch geometry identical across both.
struct AppMenuRowLabel: View {
    let title: String
    let symbol: String
    var chevron = "chevron.right"

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title2).frame(width: 28)
                .accessibilityHidden(true)
            Text(title).font(.body)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Image(systemName: chevron).font(.subheadline.weight(.medium))
                .accessibilityHidden(true)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// Retains native disclosure state while using the same row as Home's menu actions.
struct AppMenuDisclosureStyle: DisclosureGroupStyle {
    let title: String
    let symbol: String

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { configuration.isExpanded.toggle() } label: {
                AppMenuRowLabel(title: title, symbol: symbol,
                                chevron: configuration.isExpanded ? "chevron.down" : "chevron.right")
            }
            .buttonStyle(.plain)
            .accessibilityValue(Text(configuration.isExpanded ? "Expanded" : "Collapsed"))
            .accessibilityHint("Expands or collapses the stop history")
            .accessibilityIdentifier("stop.detailsDisclosure")
            if configuration.isExpanded {
                configuration.content.padding(.top, 8).padding(.bottom, 16)
            }
        }
    }
}
