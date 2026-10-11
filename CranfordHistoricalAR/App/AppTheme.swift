import SwiftUI

/// Restrained palette: archival paper, ink, and a single brass accent (spec §13).
enum AppTheme {
    static let accent = Color("AccentColor")
    static let ink = Color(light: Color(red: 0.11, green: 0.12, blue: 0.13), dark: Color(red: 0.93, green: 0.92, blue: 0.89))
    static let parchment = Color(light: Color(red: 0.96, green: 0.94, blue: 0.90), dark: Color(red: 0.10, green: 0.10, blue: 0.11))
    static let brass = Color(red: 0.72, green: 0.56, blue: 0.27)
    static let heritageGreen = Color(red: 0.16, green: 0.33, blue: 0.27)
    static let visited = Color(red: 0.35, green: 0.52, blue: 0.42)
    static let warning = Color(red: 0.78, green: 0.45, blue: 0.16)

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
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
    }
}
