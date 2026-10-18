import SwiftUI

/// A photograph opens in place; dismissing it never changes tour or navigation state.
struct ExpandableStopImage: View {
    let image: LoadedImage
    let title: String
    var cornerRadius: CGFloat = 14
    @State private var isExpanded = false

    var body: some View {
        Button { isExpanded = true } label: {
            SignImage(image: image, cornerRadius: cornerRadius)
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Enlarge image of \(title)")
        .accessibilityHint("Opens a full-screen image with zoom and a Close button")
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
            HStack(spacing: 16) {
                Text(title).font(.headline).lineLimit(2)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.headline)
                        .frame(width: 48, height: 48)
                        .background(.white.opacity(0.14), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close photo")
            }
            .padding(.horizontal, 20).padding(.vertical, 8)
            if let credit {
                Text(credit).font(.caption).padding(.horizontal, 20).padding(.bottom, 8)
            }
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
            }
            .clipped()
            HStack {
                if image.isPlaceholder { Text("Placeholder image").font(.footnote) }
                Spacer()
                Button("Reset zoom") { scale = 1; offset = .zero }
                    .frame(minHeight: 44)
            }
            .font(.subheadline).padding(.horizontal, 24)
        }
        .foregroundStyle(.white).background(.black)
        .preferredColorScheme(.dark)
    }
}
