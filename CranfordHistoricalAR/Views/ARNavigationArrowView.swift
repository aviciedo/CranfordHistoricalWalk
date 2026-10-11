import SwiftUI

/// 2D direction indicator shown in the AR HUD (spec §7). It is the graceful fallback when the
/// 3D arrows cannot be trusted (no compass, poor tracking) and a quiet confirmation otherwise.
/// Later versions can replace this with richer guidance without touching the AR scene code.
struct ARNavigationArrowView: View {
    /// Degrees; positive = target is to the right. `nil` when heading is unknown.
    var relativeBearing: Double?
    var distanceText: String
    var isProminent: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: isProminent ? 64 : 44, height: isProminent ? 64 : 44)
                if let relativeBearing {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: isProminent ? 30 : 20, weight: .semibold))
                        .foregroundStyle(AppTheme.brass)
                        .rotationEffect(.degrees(relativeBearing))
                        .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.8), value: relativeBearing)
                        .accessibilityLabel(accessibilityDirection(relativeBearing))
                } else {
                    Image(systemName: "questionmark")
                        .font(.system(size: isProminent ? 24 : 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            if isProminent {
                VStack(alignment: .leading, spacing: 2) {
                    if let relativeBearing {
                        Text(hint(for: relativeBearing)).font(.subheadline.weight(.semibold))
                        Text("\(distanceText) to go").font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Text("Heading unavailable").font(.subheadline.weight(.semibold))
                        Text("Walk a few steps so GPS can tell which way you're facing.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(.trailing, 6)
            }
        }
        .padding(isProminent ? 10 : 0)
        .background(isProminent ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.clear), in: Capsule())
    }

    private func hint(for bearing: Double) -> String {
        switch abs(bearing) {
        case ..<20: return "Straight ahead"
        case ..<70: return bearing > 0 ? "Bear right" : "Bear left"
        case ..<135: return bearing > 0 ? "Turn right" : "Turn left"
        default: return "Turn around"
        }
    }

    private func accessibilityDirection(_ bearing: Double) -> String {
        "\(hint(for: bearing)), \(distanceText)"
    }
}
