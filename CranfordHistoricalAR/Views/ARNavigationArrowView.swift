import SwiftUI
import TourCore

/// Small, legible directions at the camera's lower edge; the arrows live in the scene.
struct ARNavigationArrowView: View {
    var relativeBearing: Double?
    var detail: String
    var cue: ARWalkingGuidance.RouteCue?
    var isApproximate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let cue {
                Text(cue.streetLabel).font(.title3.weight(.semibold))
                Label(cue.instruction, systemImage: cue.direction.symbolName)
                    .font(.subheadline.weight(.medium))
            } else {
                Text(ARWalkingGuidance.instruction(for: relativeBearing)).font(.headline)
                Text(detail).font(.subheadline)
            }
            if isApproximate {
                Text("GPS positioning is approximate").font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .foregroundStyle(.white)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.forest.opacity(0.88), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

/// Entry / look-around cue. A camera-relative arrow must not be confused with a future street turn.
struct ARWalkingOrientationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var relativeBearing: Double?
    var street: String
    var distance: String?
    var isUpcomingTurn: Bool

    private var direction: ARWalkingGuidance.Direction? {
        relativeBearing.map { ARWalkingGuidance.direction(for: $0) }
    }

    var body: some View {
        VStack(spacing: 10) {
            if let relativeBearing {
                ARChevronSymbol(relativeBearing: relativeBearing)
                    .frame(width: 200, height: 190)
            } else {
                Image(systemName: "viewfinder").font(.system(size: 80, weight: .medium))
                    .accessibilityHidden(true)
            }
            Text(ARWalkingGuidance.instruction(for: relativeBearing))
                .font(.title2.weight(.bold))
            Text(street).font(.title3.weight(.semibold))
            if let distance {
                Text(isUpcomingTurn ? "\(distance) to the next turn" : "Walk \(distance)")
                    .font(.subheadline.weight(.medium)).monospacedDigit()
            }
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(AppTheme.ivory)
        .shadow(color: AppTheme.forest.opacity(0.95), radius: 2)
        .shadow(color: .black.opacity(0.45), radius: 10, y: 2)
        .padding(20)
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: direction)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
    }
}

/// Transparent texture for the upright RealityKit turn sign, rather than a camera-fixed card.
struct ARFloatingTurnContent: View {
    let cue: ARWalkingGuidance.RouteCue

    var body: some View {
        VStack(spacing: 8) {
            Text(cue.streetLabel)
                .font(.system(size: 44, weight: .semibold))
                .lineLimit(2).minimumScaleFactor(0.65)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20).padding(.vertical, 10)
                .foregroundStyle(AppTheme.ivory)
                .background(AppTheme.forest.opacity(0.9), in: RoundedRectangle(cornerRadius: 14))
            Text(cue.instruction)
                .font(.system(size: 28, weight: .medium)).monospacedDigit()
                .foregroundStyle(AppTheme.ivory)
                .shadow(color: AppTheme.forest, radius: 3)
        }
        .padding(24)
        .frame(width: 640, height: 240)
        .environment(\.colorScheme, .light)
    }
}


/// Camera-fixed entry cue shares the world mesh silhouette and palette.
private struct ARChevronSymbol: View {
    var relativeBearing: Double
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { _ in
                ZStack {
                    ChevronSilhouette().fill(AppTheme.forest).offset(x: 7, y: 6)
                    ChevronSilhouette().fill(.white)
                }
                .frame(width: 48, height: 100)
            }
        }
        .rotationEffect(.degrees(ARChevronGeometry.rotationDegrees(relativeBearing: relativeBearing)))
        .shadow(color: .black.opacity(0.25), radius: 4, y: 3)
        .accessibilityHidden(true)
    }
}

private struct ChevronSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addLines(ARChevronGeometry.outline.map {
            CGPoint(x: (CGFloat($0.x) + 0.45) * rect.width,
                    y: (0.95 - CGFloat($0.y)) / 1.9 * rect.height)
        })
        path.closeSubpath()
        return path
    }
}
