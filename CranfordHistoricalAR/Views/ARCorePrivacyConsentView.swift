import SwiftUI

/// First-run Geospatial notice. Text is Google's required disclosure
/// (https://developers.google.com/ar/develop/privacy-requirements).
struct ARCorePrivacyConsentView: View {
    var onAccept: () -> Void
    var onDecline: () -> Void

    private static let learnMore = URL(string: "https://support.google.com/ar?p=how-google-play-services-for-ar-handles-your-data")!

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "globe.americas")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(AppTheme.brass)
            Text("ARCore Geospatial")
                .font(.system(.title2, design: .serif).weight(.semibold))
                .multilineTextAlignment(.center)
            Text("To power this session, Google will process sensor data (e.g., camera and location).")
                .font(.body)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Link("Learn more", destination: Self.learnMore)
                .font(.headline)
            Text("This application runs on Google Play Services for AR (ARCore), which is provided by Google and governed by the Google Privacy Policy.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("You can continue the walking tour with GPS and compass only. Signs and arrows will be less precisely placed.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(spacing: 10) {
                Button(action: onAccept) {
                    Text("Continue with Geospatial AR")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.heritageGreen, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(.white)
                }
                Button("Use GPS only", action: onDecline)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.top, 8)
        }
        .padding(28)
        .background(AppTheme.parchment)
    }
}

/// Compact home-screen disclosure (same Google requirement, always reachable).
struct ARCoreHomeDisclosure: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("This application runs on Google Play Services for AR (ARCore), which is provided by Google and governed by the Google Privacy Policy.")
            if let url = URL(string: "https://policies.google.com/privacy") {
                Link("Google Privacy Policy", destination: url)
            }
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
    }
}
