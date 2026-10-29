import SwiftUI
import UIKit
import TourCore

struct PassportPresentation: Identifiable {
    let id = UUID()
    let stopID: String
    let animated: Bool
}

/// The saved plaque-unlock ledger is the collection. There is no second award store to drift out of sync.
struct PassportView: View {
    @Environment(TourViewModel.self) private var tour
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let initialStopID: String
    var animatedStampStopID: String? = nil
    @State private var pageIndex = 0
    @State private var hasSelectedInitialPage = false
    @State private var hasStamped = false

    private var stops: [HistoricalStop] { tour.passportStops }
    private var currentPageIndex: Int {
        hasSelectedInitialPage ? min(pageIndex, max(0, stops.count - 1)) : (stops.firstIndex { $0.id == initialStopID } ?? 0)
    }
    private var pageSelection: Binding<Int> {
        Binding(get: { currentPageIndex }, set: { pageIndex = $0; hasSelectedInitialPage = true })
    }
    private var isAwaitingStamp: Bool {
        guard let id = animatedStampStopID else { return false }
        return tour.activities[id].plaqueUnlockedAt != nil && !hasStamped
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
                .accessibilityLabel("Close passport")
                .accessibilityHint("Returns to the previous screen; your stamps stay collected")
                .accessibilityIdentifier("passport.close")
            }
            .padding(.horizontal, 24).padding(.top, 8)
            Text("Your passport")
                .font(.system(.largeTitle, design: .serif).weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 24)
            if animatedStampStopID != nil && hasStamped {
                Label("Passport stamp unlocked", systemImage: "checkmark.seal.fill")
                    .font(.headline).padding(.horizontal, 24)
                    .accessibilityIdentifier("passport.stampUnlocked")
            }
            if stops.isEmpty {
                ContentUnavailableView("No on-site stamps yet", systemImage: "book.closed",
                                       description: Text("Plaque discoveries will appear here when they become available."))
            } else {
                GeometryReader { viewport in
                    let pages = stops.map { stop in
                        AnyView(PassportLeaf(stop: stop,
                            collected: tour.activities[stop.id].plaqueUnlockedAt != nil,
                            revealStamp: stop.id != animatedStampStopID || hasStamped,
                            reduceMotion: reduceMotion,
                            availableHeight: viewport.size.height)
                            .environment(\.dynamicTypeSize, dynamicTypeSize))
                    }
                    if reduceMotion {
                        pages[currentPageIndex]
                    } else {
                        PassportPageCurl(pages: pages, index: pageSelection, enabled: !isAwaitingStamp)
                    }
                }
                .padding(.horizontal, 12)
                .accessibilityIdentifier("passport.pages")
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
        .interactiveDismissDisabled(isAwaitingStamp)
        .onAppear { selectInitialPage() }
        .onChange(of: stops.map(\.id)) { _, _ in
            pageIndex = min(pageIndex, max(0, stops.count - 1))
        }
        .task(id: scenePhase) {
            guard scenePhase == .active, !hasStamped, let id = animatedStampStopID,
                  tour.activities[id].plaqueUnlockedAt != nil else { return }
            selectInitialPage()
            do { try await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 350)) }
            catch { return }
            withAnimation(reduceMotion ? .easeIn(duration: 0.2) : .spring(response: 0.48, dampingFraction: 0.66)) {
                hasStamped = true
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            UIAccessibility.post(notification: .announcement,
                                 argument: "Passport stamp unlocked. \(tour.stop(withID: id)?.name ?? "Stamp") collected.")
        }
        .accessibilityIdentifier("passport.screen")
    }

    private func selectInitialPage() {
        guard !hasSelectedInitialPage, !stops.isEmpty else { return }
        pageIndex = stops.firstIndex { $0.id == initialStopID } ?? 0
        hasSelectedInitialPage = true
    }

    private var pagination: some View {
        VStack(spacing: 6) {
            HStack {
                pageButton("Previous page", symbol: "chevron.left", disabled: currentPageIndex == 0) { pageSelection.wrappedValue = currentPageIndex - 1 }
                Spacer(minLength: 8)
                Text("Page \(currentPageIndex + 1) of \(stops.count)")
                    .font(.system(.headline, design: .serif)).monospacedDigit()
                    .accessibilityIdentifier("passport.pageCount")
                Spacer(minLength: 8)
                pageButton("Next page", symbol: "chevron.right", disabled: currentPageIndex >= stops.count - 1) { pageSelection.wrappedValue = currentPageIndex + 1 }
            }
            Text("\(tour.passportCollectedCount) of \(stops.count) stamps collected")
                .font(.subheadline).foregroundStyle(AppTheme.secondaryInk)
                .accessibilityIdentifier("passport.collectionCount")
        }
        .padding(.horizontal, 32)
    }

    private func pageButton(_ title: String, symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.title3.weight(.medium))
                .frame(width: 48, height: 48).background(.white, in: Circle())
        }
        .buttonStyle(.plain).disabled(disabled || isAwaitingStamp)
        .opacity(disabled ? 0.3 : 1)
        .accessibilityLabel(title)
    }
}

private struct PassportLeaf: View {
    let stop: HistoricalStop
    let collected: Bool
    let revealStamp: Bool
    let reduceMotion: Bool
    let availableHeight: CGFloat
    @ScaledMetric(relativeTo: .title) private var titleSize: CGFloat = 28

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 24)
                PassportStampArtwork(stopID: stop.id, isCollected: collected)
                    .opacity(collected && !revealStamp ? 0 : 1)
                    .scaleEffect(collected && !revealStamp && !reduceMotion ? 1.45 : 1)
                    .rotationEffect(.degrees(collected && !revealStamp && !reduceMotion ? -9 : 0))
                    .padding(.horizontal, 20)
                Text(stop.name)
                    .font(.system(size: titleSize, weight: .semibold, design: .serif))
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if collected {
                    Label("Collected", systemImage: "checkmark.circle.fill")
                        .font(.system(.title3, design: .serif))
                        .opacity(revealStamp ? 1 : 0)
                } else {
                    VStack(spacing: 8) {
                        Label("Not collected", systemImage: "circle")
                        Text("Find the on-site plaque with AR to add this stamp.")
                            .font(.subheadline).foregroundStyle(AppTheme.secondaryInk)
                    }
                    .multilineTextAlignment(.center)
                }
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 8).padding(.vertical, 20)
            .frame(maxWidth: .infinity, minHeight: max(0, availableHeight - 12))
            .animation(reduceMotion ? .easeIn(duration: 0.2) : .spring(response: 0.48, dampingFraction: 0.66), value: revealStamp)
        }
        .scrollBounceBehavior(.basedOnSize)
        // UIKit hosting controllers do not inherit the parent SwiftUI environment.
        .foregroundStyle(AppTheme.forest)
        .environment(\.colorScheme, .light)
        .background {
            Image("passport-paper").resizable().scaledToFill()
                .accessibilityHidden(true)
        }
        .background(AppTheme.ivory)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AppTheme.sand.opacity(0.65), lineWidth: 1))
        .padding(4)
        .shadow(color: AppTheme.forest.opacity(0.12), radius: 3, x: 1, y: 3)
    }
}

/// One frame for the passport, tour-stop row and recognition celebration. The existing
/// engraved PNGs stay untouched; a source window excludes only their old postage borders.
struct PassportStampArtwork: View {
    let stopID: String
    var isCollected = true

    private var source: (name: String, window: CGRect)? {
        switch stopID {
        case "hpab-001":
            return ("passport-stamp-mill", CGRect(x: 88, y: 131, width: 1308, height: 811))
        case "hpab-002":
            return ("passport-stamp-greystone", CGRect(x: 96, y: 129, width: 1293, height: 800))
        default: return nil
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            // Opening measured from the reusable frame asset, relative to its paper bounds.
            let opening = CGRect(x: size.width * 77 / 1466, y: size.height * 70 / 855,
                                 width: size.width * 1308 / 1466, height: size.height * 704 / 855)
            ZStack(alignment: .topLeading) {
                Image("passport-paper").resizable()
                    .frame(width: opening.width, height: opening.height)
                    .position(x: opening.midX, y: opening.midY)
                if let source {
                    PassportImageWindow(asset: source.name, canvas: CGSize(width: 1484, height: 1060),
                                        window: source.window)
                        // Preserve the complete original illustration and its proportions.
                        .aspectRatio(source.window.width / source.window.height, contentMode: .fit)
                        .frame(width: opening.width, height: opening.height)
                        .position(x: opening.midX, y: opening.midY)
                } else {
                    // Future plaque stops share the same paper frame before custom art arrives.
                    Image(systemName: "seal").resizable().scaledToFit()
                        .foregroundStyle(AppTheme.forest)
                        .frame(width: opening.height * 0.5, height: opening.height * 0.5)
                        .position(x: opening.midX, y: opening.midY)
                }
                PassportImageWindow(asset: "passport-vintage-frame", canvas: CGSize(width: 1561, height: 1008),
                                    window: CGRect(x: 49, y: 82, width: 1466, height: 855))
                    .frame(width: size.width, height: size.height)
            }
        }
        .aspectRatio(1.5, contentMode: .fit)
        .saturation(isCollected ? 1 : 0)
        .opacity(isCollected ? 1 : 0.35)
        .accessibilityHidden(true)
    }
}

/// Displays a source-image rectangle without rewriting, regenerating or stretching the art.
/// The decorative paper frame can size to its container; illustration callers fix their ratio.
private struct PassportImageWindow: View {
    let asset: String
    let canvas: CGSize
    let window: CGRect

    var body: some View {
        GeometryReader { geometry in
            let sx = geometry.size.width / window.width
            let sy = geometry.size.height / window.height
            Image(asset).renderingMode(.original).resizable()
                .frame(width: canvas.width * sx, height: canvas.height * sy)
                .offset(x: -window.minX * sx, y: -window.minY * sy)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                .clipped()
        }
    }
}

struct PassportStampRow: View {
    let stop: HistoricalStop
    let isCollected: Bool
    let collectedCount: Int
    let totalCount: Int
    let action: () -> Void
    @ScaledMetric(relativeTo: .title2) private var stampWidth: CGFloat = 88

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: action) {
                HStack(spacing: 12) {
                    PassportStampArtwork(stopID: stop.id, isCollected: isCollected)
                        .frame(width: min(stampWidth, 112))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isCollected ? "Passport stamped" : "Stamp your passport")
                            .font(.system(.title2, design: .serif).weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(isCollected
                             ? "\(stop.name) · \(collectedCount) of \(totalCount) discoveries"
                             : "Find the on-site plaque with AR")
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
            .accessibilityValue(isCollected ? "Collected" : "Not collected")
            .accessibilityHint(isCollected
                ? "Opens your passport at this collected stamp"
                : "Opens your passport at this locked stamp. Recognize the on-site plaque with AR to collect it.")
            .accessibilityIdentifier("stop.passportStamped")
            Divider()
        }
    }
}

/// Native single-leaf book turning. Controllers are refreshed when a stamp animates,
/// without resetting the page the user is viewing. Arrow taps and swipes share one index.
private struct PassportPageCurl: UIViewControllerRepresentable {
    let pages: [AnyView]
    @Binding var index: Int
    let enabled: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller = UIPageViewController(transitionStyle: .pageCurl, navigationOrientation: .horizontal,
                                            options: [.spineLocation: UIPageViewController.SpineLocation.min.rawValue])
        controller.isDoubleSided = false
        controller.view.backgroundColor = UIColor(AppTheme.ivory)
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
        var parent: PassportPageCurl
        var controllers: [UIHostingController<AnyView>] = []
        var displayedIndex = 0
        var transitioning = false
        init(_ parent: PassportPageCurl) { self.parent = parent }

        func configure(_ controller: UIPageViewController) {
            if controllers.count != parent.pages.count {
                controllers = parent.pages.map {
                    let host = UIHostingController(rootView: $0)
                    host.view.backgroundColor = UIColor(AppTheme.ivory)
                    return host
                }
                controller.dataSource = self
                controller.delegate = self
                displayedIndex = min(parent.index, max(0, controllers.count - 1))
                if !controllers.isEmpty { controller.setViewControllers([controllers[displayedIndex]], direction: .forward, animated: false) }
            } else {
                for (host, page) in zip(controllers, parent.pages) { host.rootView = page }
            }
            guard !transitioning, parent.index != displayedIndex, controllers.indices.contains(parent.index) else { return }
            let target = parent.index
            transitioning = true
            controller.setViewControllers([controllers[target]], direction: target > displayedIndex ? .forward : .reverse,
                                          animated: true) { [weak self, weak controller] completed in
                guard let self else { return }
                self.displayedIndex = target
                self.transitioning = false
                // Catch an arrow tap that arrived while the previous curl was finishing.
                if let controller { self.configure(controller) }
            }
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
                displayedIndex = i
                parent.index = i
            }
            transitioning = false
        }
    }
}
