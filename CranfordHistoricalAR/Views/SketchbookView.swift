import SwiftUI
import UIKit
import TourCore

struct SketchbookPresentation: Identifiable {
    let id = UUID()
    let stopID: String
    let animated: Bool
}

/// The saved plaque-unlock ledger is the collection. There is no second award store to drift out of sync.
struct SketchbookView: View {
    @Environment(TourViewModel.self) private var tour
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let initialStopID: String
    var animatedSketchStopID: String? = nil
    @State private var pageIndex = 0
    @State private var hasSelectedInitialPage = false
    @State private var hasRevealedSketch = false

    private var stops: [HistoricalStop] { tour.sketchbookStops }
    private var currentPageIndex: Int {
        hasSelectedInitialPage ? SketchbookPageIndex.clamped(pageIndex, pageCount: stops.count) : Self.initialPageIndex(stopID: initialStopID, pageStopIDs: stops.map(\.id))
    }
    private var pageSelection: Binding<Int> {
        Binding(get: { currentPageIndex }, set: { pageIndex = $0; hasSelectedInitialPage = true })
    }
    private var isAwaitingSketch: Bool {
        guard let id = animatedSketchStopID else { return false }
        return tour.activities[id].plaqueUnlockedAt != nil && !hasRevealedSketch
    }

    var body: some View {
        SketchbookScreenLayout {
            SketchbookHeader(collected: tour.sketchbookCollectedCount, total: stops.count,
                             onDismiss: { dismiss() })
        } pages: {
            if stops.isEmpty {
                ContentUnavailableView("No on-site sketches yet", systemImage: "book.closed",
                                       description: Text("Plaque discoveries will appear here when they become available."))
            } else {
                GeometryReader { viewport in
                    let pages = stops.map { stop in
                        AnyView(SketchbookLeaf(stop: stop,
                            collected: tour.activities[stop.id].plaqueUnlockedAt != nil,
                            revealSketch: stop.id != animatedSketchStopID || hasRevealedSketch,
                            reduceMotion: reduceMotion,
                            availableHeight: viewport.size.height)
                            .environment(\.dynamicTypeSize, dynamicTypeSize))
                    }
                    if reduceMotion {
                        pages[currentPageIndex]
                    } else {
                        SketchbookPageCurl(pages: pages, index: pageSelection, enabled: !isAwaitingSketch)
                    }
                }
                .padding(.horizontal, 4)
                .accessibilityIdentifier("sketchbook.pages")
            }
        } footer: {
            if !stops.isEmpty {
                SketchbookPagination(page: currentPageIndex + 1, total: stops.count,
                                     enabled: !isAwaitingSketch,
                                     onPrevious: { pageSelection.wrappedValue = currentPageIndex - 1 },
                                     onNext: { pageSelection.wrappedValue = currentPageIndex + 1 })
            }
        }
        .foregroundStyle(AppTheme.forest)
        .preferredColorScheme(.light)
        .environment(\.colorScheme, .light)
        .holdsWalkingContext()
        .dismissOnReturnHome()
        .interactiveDismissDisabled(isAwaitingSketch)
        .onAppear { selectInitialPage() }
        .onChange(of: stops.map(\.id)) { _, _ in
            pageIndex = SketchbookPageIndex.clamped(pageIndex, pageCount: stops.count)
        }
        .task(id: scenePhase) {
            guard scenePhase == .active, !hasRevealedSketch, let id = animatedSketchStopID,
                  tour.activities[id].plaqueUnlockedAt != nil else { return }
            selectInitialPage()
            do { try await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 350)) }
            catch { return }
            withAnimation(.easeOut(duration: reduceMotion ? 0.2 : 0.9)) {
                hasRevealedSketch = true
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            UIAccessibility.post(notification: .announcement,
                                 argument: "Sketch unlocked. \(tour.stop(withID: id)?.name ?? "Sketch") added to your sketchbook.")
        }
        .accessibilityIdentifier("sketchbook.screen")
    }

    /// Resolve by stable stop identity, never by unlock order or a hard-coded tour index.
    static func initialPageIndex(stopID: String, pageStopIDs: [String]) -> Int {
        SketchbookPageIndex.initial(stopID: stopID, pageStopIDs: pageStopIDs)
    }

    private func selectInitialPage() {
        guard !hasSelectedInitialPage, !stops.isEmpty else { return }
        pageIndex = Self.initialPageIndex(stopID: initialStopID, pageStopIDs: stops.map(\.id))
        hasSelectedInitialPage = true
    }

}

/// Header and pagination receive their natural heights; the physical notebook owns
/// every remaining point. The compact bottom gap matches the main app's footer.
struct SketchbookScreenLayout<Header: View, Pages: View, Footer: View>: View {
    private let header: Header
    private let pages: Pages
    private let footer: Footer

    init(@ViewBuilder header: () -> Header, @ViewBuilder pages: () -> Pages,
         @ViewBuilder footer: () -> Footer) {
        self.header = header()
        self.pages = pages()
        self.footer = footer()
    }

    var body: some View {
        GeometryReader { viewport in
            VStack(spacing: 8) {
                header.fixedSize(horizontal: false, vertical: true)
                pages.frame(maxWidth: .infinity, maxHeight: .infinity)
                footer.fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, CGFloat(AppFooterSizing.bottomClearance(safeAreaBottom: Double(viewport.safeAreaInsets.bottom))))
            .background {
                AppTheme.ivory.overlay { SketchbookPageBack().opacity(0.25) }
                    .ignoresSafeArea()
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}

struct SketchbookHeader: View {
    let collected: Int
    let total: Int
    let onDismiss: () -> Void
    @ScaledMetric(relativeTo: .title) private var headingSize: CGFloat = 30

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ScreenBackButton(action: onDismiss)
                Spacer(minLength: 12)
                Button(action: onDismiss) {
                    Image(systemName: "xmark").font(.system(size: 17, weight: .medium))
                        .frame(width: 44, height: 44).background(.white, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close sketchbook")
                .accessibilityHint("Returns to the previous screen; your sketches stay collected")
                .accessibilityIdentifier("sketchbook.close")
            }
            HStack(alignment: .center, spacing: 12) {
                Text("Your sketchbook")
                    .font(.system(size: min(headingSize, 40), weight: .semibold, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                if total > 0 {
                    SketchbookCollectionCounter(collected: collected, total: total)
                        .fixedSize()
                }
            }
        }
        .padding(.horizontal, 16).padding(.top, 8)
        .foregroundStyle(AppTheme.forest)
    }
}

struct SketchbookCollectionCounter: View {
    let collected: Int
    let total: Int
    private var value: String { "\(max(0, min(collected, total))) of \(max(0, total))" }

    var body: some View {
        Text(value)
            .font(.footnote.weight(.medium)).monospacedDigit()
            .padding(.horizontal, 10).padding(.vertical, 4)
            .foregroundStyle(AppTheme.forest)
            .background(AppTheme.sketchbookPaper.opacity(0.8), in: Capsule())
            .overlay { Capsule().strokeBorder(AppTheme.forest.opacity(0.3), lineWidth: 1) }
            .accessibilityLabel("Sketches collected")
            .accessibilityValue(value)
            .accessibilityIdentifier("sketchbook.collectionCount")
    }
}

struct SketchbookPagination: View {
    let page: Int
    let total: Int
    let enabled: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            pageButton("Previous page", symbol: "chevron.left", disabled: page <= 1, action: onPrevious)
            Text("Page \(page) of \(total)")
                .font(.footnote).monospacedDigit()
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("sketchbook.pageCount")
            pageButton("Next page", symbol: "chevron.right", disabled: page >= total, action: onNext)
        }
        .foregroundStyle(AppTheme.secondaryInk)
        .padding(.horizontal, 32)
    }

    private func pageButton(_ title: String, symbol: String, disabled: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.body.weight(.regular))
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(disabled || !enabled)
        .opacity(disabled ? 0.35 : 1)
        .accessibilityLabel(title)
    }
}

private struct SketchbookLeaf: View {
    let stop: HistoricalStop
    let collected: Bool
    let revealSketch: Bool
    let reduceMotion: Bool
    let availableHeight: CGFloat
    @ScaledMetric(relativeTo: .title) private var titleSize: CGFloat = 28

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 24)
                SketchArtwork(stopID: stop.id, isCollected: collected, artwork: stop.artwork)
                    .opacity(collected && !revealSketch ? 0 : 1)
                    .mask(alignment: .leading) {
                        Rectangle().scaleEffect(x: collected && !revealSketch && !reduceMotion ? 0 : 1,
                                                y: 1, anchor: .leading)
                    }
                    .padding(.horizontal, 16)
                Text(stop.name)
                    .font(.system(size: titleSize, weight: .semibold, design: .serif))
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if collected {
                    Label("Added to your sketchbook", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        .opacity(revealSketch ? 1 : 0)
                } else {
                    SketchbookCollectInstruction()
                        .padding(.horizontal, 12)
                }
                Spacer(minLength: 24)
            }
            .padding(.leading, 16).padding(.trailing, 8).padding(.vertical, 24)
            .frame(maxWidth: .infinity, minHeight: max(0, availableHeight))
            .animation(.easeOut(duration: reduceMotion ? 0.2 : 0.9), value: revealSketch)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollContentBackground(.hidden)
        .foregroundStyle(AppTheme.forest)
        .environment(\.colorScheme, .light)
        .background { SketchbookPaper() }
        // Keep the snapshot rectangular and opaque to its last pixel. A rounded
        // mask reveals the hosting background at the bottom of a moving leaf.
    }
}

struct SketchbookCollectInstruction: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock")
                .font(.title2.weight(.light)).accessibilityHidden(true)
            Text("Scan this stop’s plaque\nto collect the sketch.")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(AppTheme.forest)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Scan this stop’s plaque to collect the sketch.")
        .accessibilityIdentifier("sketchbook.collectInstruction")
    }
}

/// Shared physical paper surface: the green cloth gutter and worn corners are in the asset.
struct SketchbookPaper: View {
    var body: some View {
        GeometryReader { viewport in
            // Exclude the source scan's pale exterior beyond the right/bottom
            // paper edge. Keep the cloth gutter and the worn paper itself.
            Image("sketchbook-paper").resizable()
                .frame(width: viewport.size.width / 0.985,
                       height: viewport.size.height / 0.992)
                .frame(width: viewport.size.width, height: viewport.size.height, alignment: .topLeading)
                .clipped()
        }
        .background(AppTheme.sketchbookPaper)
        .accessibilityHidden(true)
    }
}

/// Flat, blank, full-bleed reverse with subtle handling wear at its actual edges.
/// UIKit supplies the bend and shadow; no lettering or baked-in curl belongs here.
struct SketchbookPageBack: View {
    var body: some View {
        Image("sketchbook-paper-reverse").resizable()
            .background(AppTheme.sketchbookPaper)
            .accessibilityHidden(true)
    }
}

/// Original transparent watercolor files, without stamp outlines, frame or image cropping.
/// A future plaque stop can use its existing tour illustration until its sketch is supplied.
struct SketchArtwork: View {
    let stopID: String
    var isCollected = true

    var artwork: StopArtwork? = nil
    static func assetName(for stopID: String, artwork: StopArtwork? = nil) -> String? {
        BundledStopArtwork.resolve(stopID: stopID, override: artwork)?.watercolor
    }

    var body: some View {
        Group {
            if let name = Self.assetName(for: stopID, artwork: artwork) {
                Image(name).renderingMode(.original).resizable().scaledToFit()
            } else {
                StopListIllustration(stopID: stopID, artwork: artwork)
            }
        }
        .aspectRatio(1.5, contentMode: .fit)
        .saturation(isCollected ? 1 : 0)
        .opacity(isCollected ? 1 : 0.22)
        .accessibilityHidden(true)
    }
}

struct SketchCollectionRow: View {
    let stop: HistoricalStop
    let isCollected: Bool
    let action: () -> Void
    @ScaledMetric(relativeTo: .title2) private var sketchWidth: CGFloat = 88

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: action) {
                HStack(spacing: 12) {
                    SketchArtwork(stopID: stop.id, isCollected: isCollected, artwork: stop.artwork)
                        .frame(width: min(sketchWidth, 112))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isCollected ? "Sketch unlocked" : "Discover this sketch")
                            .font(.system(.title2, design: .serif).weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(isCollected
                             ? stop.name
                             : "Find the on-site plaque")
                            .font(.subheadline).foregroundStyle(AppTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right").font(.subheadline)
                }
                .foregroundStyle(isCollected ? AppTheme.forest : AppTheme.secondaryInk)
                .padding(.vertical, 12).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isCollected ? "Sketch unlocked" : "Not discovered")
            .accessibilityHint(isCollected
                ? "Opens your sketchbook at this collected sketch"
                : "Opens this sketch’s locked page. Recognize the on-site plaque to unlock it.")
            .accessibilityIdentifier("stop.sketchAdded")
            Divider()
        }
    }
}

/// Native single-leaf book turning. Controllers are refreshed when a sketch appears,
/// without resetting the page the user is viewing. Arrow taps and swipes share one index.
struct SketchbookPageCurl: UIViewControllerRepresentable {
    let pages: [AnyView]
    @Binding var index: Int
    let enabled: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    static func makePageController() -> UIPageViewController {
        let controller = UIPageViewController(transitionStyle: .pageCurl, navigationOrientation: .horizontal,
                                            options: [.spineLocation: UIPageViewController.SpineLocation.min.rawValue])
        controller.loadViewIfNeeded()
        controller.isDoubleSided = true
        controller.view.backgroundColor = UIColor(AppTheme.sketchbookPaper)
        controller.view.isOpaque = true
        controller.view.clipsToBounds = true
        return controller
    }
    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller = Self.makePageController()
        context.coordinator.configure(controller)
        return controller
    }
    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        context.coordinator.configure(controller)
        controller.view.isUserInteractionEnabled = enabled
    }

    @MainActor
    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: SketchbookPageCurl
        var controllers: [UIHostingController<AnyView>] = []
        var displayedIndex = 0
        var transitioning = false
        private var interactiveStartIndex: Int?
        init(_ parent: SketchbookPageCurl) { self.parent = parent }

        func configure(_ controller: UIPageViewController) {
            // SwiftUI may update during an interactive curl. Never replace a controller
            // or its rendered face while UIKit is using it in an animation.
            guard !transitioning else { return }
            if controllers.count != parent.pages.count * 2 {
                controllers = parent.pages.flatMap { page in
                    [Self.host(Self.paperBacked(page)), Self.host(AnyView(SketchbookPageBack().ignoresSafeArea()), back: true)]
                }
                controller.dataSource = self
                controller.delegate = self
                displayedIndex = SketchbookPageIndex.clamped(parent.index, pageCount: parent.pages.count)
                if !controllers.isEmpty {
                    controller.setViewControllers(faces(for: displayedIndex, animated: false),
                                                  direction: .forward, animated: false)
                }
            } else {
                for (index, page) in parent.pages.enumerated() {
                    controllers[SketchbookCurlLayout.frontControllerIndex(logicalPage: index)].rootView = Self.paperBacked(page)
                }
            }
            guard parent.index != displayedIndex, parent.pages.indices.contains(parent.index) else { return }
            let target = parent.index
            transitioning = true
            let direction: UIPageViewController.NavigationDirection = target > displayedIndex ? .forward : .reverse
            controller.setViewControllers(faces(for: target, animated: true), direction: direction,
                                          animated: true) { [weak self, weak controller] completed in
                guard let self, let controller else { return }
                // Defer until UIKit has unwound its transition completion. Reentrant
                // setViewControllers calls here can invalidate the curl's controller count.
                DispatchQueue.main.async { [weak self, weak controller] in
                    guard let self, let controller else { return }
                    // `completed` describes the animation, not whether UIKit installed
                    // the destination. Interrupted/offscreen turns can return false
                    // with the new page already visible. Reconcile the actual face.
                    if let visible = controller.viewControllers?.first,
                       let physical = self.controllers.firstIndex(where: { $0 === visible }) {
                        self.displayedIndex = SketchbookCurlLayout.logicalPage(controllerIndex: physical)
                    }
                    if !completed, self.parent.index == target, self.displayedIndex != target {
                        self.parent.index = self.displayedIndex
                    }
                    self.transitioning = false
                    self.configure(controller)
                }
            }
        }

        private static func host(_ page: AnyView, back: Bool = false) -> UIHostingController<AnyView> {
            let host = UIHostingController(rootView: page)
            // A curl snapshots the entire hosting view, including its safe-area margins.
            host.safeAreaRegions = []
            host.view.backgroundColor = UIColor(AppTheme.sketchbookPaper)
            host.view.isOpaque = true
            host.view.accessibilityElementsHidden = back
            return host
        }

        private static func paperBacked(_ page: AnyView) -> AnyView {
            AnyView(page.background { SketchbookPageBack().ignoresSafeArea() }.ignoresSafeArea())
        }

        private func faces(for page: Int, animated: Bool) -> [UIViewController] {
            let front = SketchbookCurlLayout.frontControllerIndex(logicalPage: page)
            // Bootstrap a minimum-spine book with one front. Once animating,
            // double-sided UIKit turns require both front and parchment reverse
            // in either direction. A universal one- or two-face rule can throw.
            if animated {
                return [controllers[front], controllers[front + 1]]
            }
            return [controllers[front]]
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                spineLocationFor orientation: UIInterfaceOrientation) -> UIPageViewController.SpineLocation {
            .min
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let i = controllers.firstIndex(where: { $0 === viewController }), i > 0 else { return nil }
            return controllers[i - 1]
        }
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let i = controllers.firstIndex(where: { $0 === viewController }), i + 1 < controllers.count else { return nil }
            return controllers[i + 1]
        }
        func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
            interactiveStartIndex = parent.index
            transitioning = true
        }
        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            if completed, let visible = pageViewController.viewControllers?.first,
               let i = controllers.firstIndex(where: { $0 === visible }) {
                displayedIndex = SketchbookCurlLayout.logicalPage(controllerIndex: i)
                if interactiveStartIndex == nil || parent.index == interactiveStartIndex { parent.index = displayedIndex }
            }
            interactiveStartIndex = nil
            // Swipes use the same deferred queue as arrow taps, including cancellation.
            DispatchQueue.main.async { [weak self, weak pageViewController] in
                guard let self, let pageViewController else { return }
                self.transitioning = false
                self.configure(pageViewController)
            }
        }
    }
}
