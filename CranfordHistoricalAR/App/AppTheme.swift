import SwiftUI

/// Warm-white surfaces, forest ink and terracotta transport from the selected walking-screen reference.
enum AppTheme {
    static let accent = Color("AccentColor")
    static let forest = Color(red: 48 / 255, green: 70 / 255, blue: 57 / 255)
    static let ivory = Color(red: 247 / 255, green: 244 / 255, blue: 239 / 255)
    static let sage = Color(red: 107 / 255, green: 127 / 255, blue: 91 / 255)
    static let sand = Color(red: 217 / 255, green: 201 / 255, blue: 178 / 255)
    static let terracotta = Color(red: 201 / 255, green: 111 / 255, blue: 79 / 255)
    static let ink = Color(light: forest, dark: ivory)
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
