import SwiftUI

/// Flat, full-width navigation that keeps the reference layout across iOS versions.
/// The native TabView above it retains each screen's state; taps only change presentation.
struct BottomNavigationBar: View {
    @Binding var selection: AppNavigation.Tab

    var body: some View {
        HStack(spacing: 0) {
            tab(.home, title: "Home", symbol: "house", selectedSymbol: "house.fill")
            tab(.map, title: "Map", symbol: "map", selectedSymbol: "map.fill")
            tab(.stops, title: "Stops", symbol: "mappin", selectedSymbol: "mappin")
        }
        .padding(.vertical, 4)
        .background(AppTheme.navigationBackground)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main navigation")
    }

    private func tab(_ tab: AppNavigation.Tab, title: String, symbol: String, selectedSymbol: String) -> some View {
        let selected = selection == tab
        return Button { selection = tab } label: {
            VStack(spacing: 5) {
                Image(systemName: selected ? selectedSymbol : symbol)
                    .font(.system(size: 24, weight: .regular))
                    .frame(height: 27)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.caption.weight(selected ? .semibold : .regular))
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? AppTheme.forest : AppTheme.navigationInactive)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("navigation.\(title.lowercased())")
    }
}

#Preview {
    BottomNavigationBar(selection: .constant(.map))
}

/// Shared screen navigation. The audio player's X remains a separate transport action.
struct ScreenBackButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Label("Back", systemImage: "chevron.left")
                .font(.subheadline.weight(.medium)).padding(.horizontal, 14)
                .frame(minHeight: 44).background(.white, in: Capsule())
        }
        .buttonStyle(.plain).foregroundStyle(AppTheme.forest)
        .accessibilityLabel("Back to previous screen")
        .accessibilityIdentifier("screen.back")
    }
}

struct ScreenHomeButton: View {
    @Environment(AppNavigation.self) private var navigation
    var body: some View {
        Button { navigation.goHome() } label: {
            Image(systemName: "xmark").font(.system(size: 17, weight: .medium))
                .frame(width: 44, height: 44).background(.white, in: Circle())
        }
        .buttonStyle(.plain).foregroundStyle(AppTheme.forest)
        .accessibilityLabel("Close and return Home")
        .accessibilityHint("Keeps your audio position and walking progress")
        .accessibilityIdentifier("screen.home")
    }
}

struct ScreenReturnBar: View {
    var onBack: () -> Void
    var body: some View {
        HStack {
            ScreenBackButton(action: onBack)
            Spacer(minLength: 12)
            ScreenHomeButton()
        }
    }
}

/// Identical safe-area-relative button and title geometry for the main pages.
struct ScreenPageHeader<Heading: View>: View {
    let onBack: () -> Void
    let heading: Heading

    init(onBack: @escaping () -> Void, @ViewBuilder heading: () -> Heading) {
        self.onBack = onBack
        self.heading = heading()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenReturnBar(onBack: onBack)
            heading
                .font(.system(.largeTitle, design: .serif).weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
        }
        .padding(.horizontal, 24).padding(.top, 8)
    }
}

/// Each modal dismisses its own level; parent hosts also clear their presentation bindings.
private struct ReturnHomeDismissal: ViewModifier {
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.dismiss) private var dismiss
    func body(content: Content) -> some View {
        content.onChange(of: navigation.homeReturnID) { _, _ in dismiss() }
    }
}

extension View {
    func dismissOnReturnHome() -> some View { modifier(ReturnHomeDismissal()) }
}
