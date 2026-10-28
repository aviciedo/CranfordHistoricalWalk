import SwiftUI
import TourCore

/// One compact GPS maneuver card. World-space chevrons supply the visual AR direction.
struct ARNavigationArrowView: View {
    var detail: String
    var cue: ARWalkingGuidance.RouteCue?
    var isApproximate: Bool
    var needsGroundScan = false
    var needsOrientation = false
    var nextStopName: String? = nil
    var onContinue: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 16) {
                VStack(spacing: 4) {
                    Image(systemName: cue?.direction.symbolName ?? "location")
                        .font(.system(size: 28, weight: .semibold))
                        .accessibilityHidden(true)
                    if let cue {
                        Text(cue.distanceText).font(.subheadline.weight(.semibold))
                            .monospacedDigit().fixedSize()
                    }
                }
                .frame(minWidth: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text(cue?.streetLabel ?? "Walking directions")
                        .font(.headline)
                    Text(cue.map { $0.isUpcomingTurn ? $0.direction.instruction : "Continue ahead" } ?? detail)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if needsGroundScan {
                Text("Tilt your phone slightly down to find the ground")
                    .font(.caption).foregroundStyle(.white.opacity(0.85))
            } else if needsOrientation {
                Text("Point your phone along the route")
                    .font(.caption).foregroundStyle(.white.opacity(0.85))
            } else if isApproximate {
                Text("GPS alignment is approximate").font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
            if let onContinue {
                Divider().overlay(.white.opacity(0.25))
                Button(action: onContinue) {
                    Label(nextStopName.map { "Walk to \($0)" } ?? "Finish walk",
                          systemImage: nextStopName == nil ? "checkmark" : "figure.walk")
                        .font(.headline).fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("ar.startNextLeg")
            }
        }
        .foregroundStyle(.white)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.forest.opacity(0.90), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}
