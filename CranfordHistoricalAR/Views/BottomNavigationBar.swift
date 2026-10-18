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
