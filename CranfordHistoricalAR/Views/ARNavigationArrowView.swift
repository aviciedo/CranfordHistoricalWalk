import SwiftUI
import TourCore

/// Remains readable even when the world-space arrows are beside or behind the camera.
struct ARNavigationArrowView: View {
    /// Degrees from the camera's horizontal facing; positive means turn right.
    var relativeBearing: Double?
    var detail: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(AppTheme.forest).frame(width: 64, height: 64)
                if let relativeBearing {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 29, weight: .semibold))
                        .foregroundStyle(AppTheme.ivory)
                        .rotationEffect(.degrees(relativeBearing))
                } else {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(AppTheme.ivory)
                }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(ARWalkingGuidance.instruction(for: relativeBearing))
                    .font(.headline)
                Text(detail).font(.subheadline)
                    .foregroundStyle(AppTheme.forest.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(AppTheme.forest)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.ivory, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}
