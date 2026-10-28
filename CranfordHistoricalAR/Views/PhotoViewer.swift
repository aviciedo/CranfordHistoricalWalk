import SwiftUI

/// A photograph opens in place; dismissing it never changes tour or navigation state.
struct ExpandableStopImage: View {
    @Environment(AppNavigation.self) private var navigation
    let image: LoadedImage
    let title: String
    var cornerRadius: CGFloat = 14
    var contentMode: ContentMode = .fill
    @State private var isExpanded = false

    var body: some View {
        Button { isExpanded = true } label: {
            SignImage(image: image, cornerRadius: cornerRadius, contentMode: contentMode)
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Enlarge image of \(title)")
        .accessibilityHint("Opens a full-screen image with zoom and a Close button")
        .onChange(of: navigation.homeReturnID) { _, _ in isExpanded = false }
        .fullScreenCover(isPresented: $isExpanded) {
            StopPhotoViewer(image: image, title: title)
        }
    }
}

struct StopPhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    let image: LoadedImage
    let title: String
    var credit: String? = nil
    @State private var scale: CGFloat = 1
    @State private var offset = CGSize.zero
    @GestureState private var magnification: CGFloat = 1
    @GestureState private var translation = CGSize.zero

    var body: some View {
        VStack(spacing: 0) {
            ScreenReturnBar(onBack: { dismiss() })
                .padding(.horizontal, 24).padding(.top, 8)
            Text("Photo")
                .font(.system(.largeTitle, design: .serif).weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24).padding(.vertical, 12)
            GeometryReader { proxy in
                Image(uiImage: image.image)
                    .resizable().scaledToFit()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .scaleEffect(min(5, max(1, scale * magnification)))
                    .offset(x: offset.width + translation.width, y: offset.height + translation.height)
                    .gesture(MagnificationGesture()
                        .updating($magnification) { value, state, _ in state = value }
                        .onEnded { value in
                            scale = min(5, max(1, scale * value))
                            let maxX = proxy.size.width * (scale - 1) / 2
                            let maxY = proxy.size.height * (scale - 1) / 2
                            offset.width = min(maxX, max(-maxX, offset.width))
                            offset.height = min(maxY, max(-maxY, offset.height))
                        })
                    .simultaneousGesture(DragGesture()
                        .updating($translation) { value, state, _ in
                            if scale > 1 { state = value.translation }
                        }
                        .onEnded { value in
                            if scale > 1 {
                                let maxX = proxy.size.width * (scale - 1) / 2
                                let maxY = proxy.size.height * (scale - 1) / 2
                                offset.width = min(maxX, max(-maxX, offset.width + value.translation.width))
                                offset.height = min(maxY, max(-maxY, offset.height + value.translation.height))
                            }
                        })
                    .onTapGesture(count: 2) { scale = 1; offset = .zero }
                    .accessibilityLabel("\(image.kind == .illustration ? "Illustration" : "Photograph") of \(title)")
                    .accessibilityAction(named: "Reset zoom") { scale = 1; offset = .zero }
            }
            .clipped()
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                if let credit, !credit.isEmpty {
                    Text(credit)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24).padding(.vertical, 16)
            .layoutPriority(1)
            if image.isPlaceholder {
                Text("Placeholder image").font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24).padding(.bottom, 8)
            }
        }
        .foregroundStyle(AppTheme.forest)
        .background(AppTheme.ivory.ignoresSafeArea())
        .preferredColorScheme(.light)
        .dismissOnReturnHome()
        .holdsWalkingContext()
    }
}
