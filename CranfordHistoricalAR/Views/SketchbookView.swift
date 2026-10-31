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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ScreenBackButton { dismiss() }
                Spacer()
                // This presentation deliberately closes back to its tour-stop host.
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 17, weight: .medium))
                        .frame(width: 44, height: 44).background(.white, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close sketchbook")
                .accessibilityHint("Returns to the previous screen; your sketches stay collected")
                .accessibilityIdentifier("sketchbook.close")
            }
            .padding(.horizontal, 24).padding(.top, 8)
            Text("Your sketchbook")
                .font(.system(.largeTitle, design: .serif).weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 24)
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
                pagination
            }
        }
        .padding(.bottom, 12)
        .background(AppTheme.ivory.ignoresSafeArea())
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

    private var pagination: some View {
        VStack(spacing: 6) {
            HStack {
                pageButton("Previous page", symbol: "chevron.left", disabled: currentPageIndex == 0) { pageSelection.wrappedValue = currentPageIndex - 1 }
                Spacer(minLength: 8)
                Text("Page \(currentPageIndex + 1) of \(stops.count)")
                    .font(.system(.headline, design: .serif)).monospacedDigit()
                    .accessibilityIdentifier("sketchbook.pageCount")
                Spacer(minLength: 8)
                pageButton("Next page", symbol: "chevron.right", disabled: currentPageIndex >= stops.count - 1) { pageSelection.wrappedValue = currentPageIndex + 1 }
            }
            Text("\(tour.sketchbookCollectedCount) of \(stops.count) sketches found")
                .font(.subheadline).foregroundStyle(AppTheme.secondaryInk)
                .accessibilityIdentifier("sketchbook.collectionCount")
        }
        .padding(.horizontal, 32)
    }

    private func pageButton(_ title: String, symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.title3.weight(.medium))
                .frame(width: 48, height: 48).background(.white, in: Circle())
        }
        .buttonStyle(.plain).disabled(disabled || isAwaitingSketch)
        .opacity(disabled ? 0.3 : 1)
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
                SketchArtwork(stopID: stop.id, isCollected: collected)
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
                    VStack(spacing: 8) {
                        Label("Not discovered", systemImage: "lock")
                        Text("Find the on-site plaque to unlock this sketch.")
                            .font(.subheadline).foregroundStyle(AppTheme.secondaryInk)
                    }
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 24)
            }
            .padding(.leading, 16).padding(.trailing, 8).padding(.vertical, 24)
            .frame(maxWidth: .infinity, minHeight: max(0, availableHeight - 12))
            .animation(.easeOut(duration: reduceMotion ? 0.2 : 0.9), value: revealSketch)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollContentBackground(.hidden)
        .foregroundStyle(AppTheme.forest)
        .environment(\.colorScheme, .light)
        .background { SketchbookPaper() }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.vertical, 4)
        .shadow(color: AppTheme.forest.opacity(0.12), radius: 3, x: 1, y: 3)
    }
}

/// Shared physical paper surface: the green cloth gutter and worn corners are in the asset.
struct SketchbookPaper: View {
    var body: some View {
        Image("sketchbook-paper").resizable()
            .accessibilityHidden(true)
    }
}

/// Full-bleed interior paper: no front-cover binding, printed edge or baked-in folded corner.
/// UIKit bends this surface itself; an image of a second page edge would expose a pale rim.
struct SketchbookPageBack: View {
    var body: some View {
        GeometryReader { viewport in
            // Use the existing texture's interior, excluding every decorative outer edge.
            SketchbookPaper()
                .frame(width: viewport.size.width / 0.78, height: viewport.size.height / 0.72)
                .offset(x: -viewport.size.width * 0.12 / 0.78,
                        y: -viewport.size.height * 0.10 / 0.72)
                .frame(width: viewport.size.width, height: viewport.size.height, alignment: .topLeading)
                .clipped()
                .scaleEffect(x: -1, y: 1)
        }
        .background(AppTheme.sketchbookPaper)
        .accessibilityHidden(true)
    }
}

/// Original transparent watercolor files, without stamp outlines, frame or image cropping.
/// A future plaque stop can use its existing tour illustration until its sketch is supplied.
struct SketchArtwork: View {
    let stopID: String
    var isCollected = true

    static func assetName(for stopID: String) -> String? {
        switch stopID {
        case "hpab-001": return "sketchbook-mill"
        case "hpab-002": return "sketchbook-greystone"
        default: return nil
        }
    }

    var body: some View {
        Group {
            if let name = Self.assetName(for: stopID) {
                Image(name).renderingMode(.original).resizable().scaledToFit()
            } else {
                StopListIllustration(stopID: stopID)
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
                    SketchArtwork(stopID: stop.id, isCollected: isCollected)
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
        init(_ parent: SketchbookPageCurl) { self.parent = parent }

        func configure(_ controller: UIPageViewController) {
            if controllers.count != parent.pages.count * 2 {
                controllers = parent.pages.flatMap { page -> [UIHostingController<AnyView>] in
                    let front = UIHostingController(rootView: Self.paperBacked(page))
                    front.view.backgroundColor = UIColor(AppTheme.sketchbookPaper)
                    front.view.isOpaque = true
                    let back = UIHostingController(rootView: AnyView(SketchbookPageBack()))
                    back.view.backgroundColor = UIColor(AppTheme.sketchbookPaper)
                    back.view.isOpaque = true
                    back.view.accessibilityElementsHidden = true
                    return [front, back]
                }
                controller.dataSource = self
                controller.delegate = self
                displayedIndex = SketchbookPageIndex.clamped(parent.index, pageCount: parent.pages.count)
                if !controllers.isEmpty { controller.setViewControllers(visibleFront(for: displayedIndex), direction: .forward, animated: false) }
            } else {
                for (index, page) in parent.pages.enumerated() { controllers[SketchbookCurlLayout.frontControllerIndex(logicalPage: index)].rootView = Self.paperBacked(page) }
            }
            guard !transitioning, parent.index != displayedIndex, parent.pages.indices.contains(parent.index) else { return }
            let target = parent.index
            transitioning = true
            controller.setViewControllers(visibleFront(for: target), direction: target > displayedIndex ? .forward : .reverse,
                                          animated: true) { [weak self, weak controller] completed in
                guard let self else { return }
                self.displayedIndex = target
                self.transitioning = false
                // Catch an arrow tap that arrived while the previous curl was finishing.
                if let controller { self.configure(controller) }
            }
        }
        private static func paperBacked(_ page: AnyView) -> AnyView {
            // Rounded front corners, padding and shadows must reveal paper, not host ivory.
            AnyView(page.background { SketchbookPageBack() })
        }

        private func visibleFront(for page: Int) -> [UIViewController] {
            // A .min spine displays ONE front even with isDoubleSided enabled.
            // UIKit requests the parchment reverse from the data source during the curl.
            // Supplying [front, back] here throws NSInvalidArgumentException on iPhone.
            [controllers[SketchbookCurlLayout.frontControllerIndex(logicalPage: page)]]
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
            transitioning = true
        }
        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            if completed, let visible = pageViewController.viewControllers?.first,
               let i = controllers.firstIndex(where: { $0 === visible }) {
                displayedIndex = SketchbookCurlLayout.logicalPage(controllerIndex: i)
                parent.index = displayedIndex
            }
            transitioning = false
        }
    }
}
