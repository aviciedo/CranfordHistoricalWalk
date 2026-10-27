import SwiftUI
import UIKit
import TourCore

struct PassportPresentation: Identifiable {
    let id = UUID()
    let stopID: String
    let animated: Bool
}

/// The saved bonus ledger is the collection. There is no second award store to drift out of sync.
struct PassportView: View {
    @Environment(TourViewModel.self) private var tour
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let initialStopID: String
    var animatedStampStopID: String? = nil
    @State private var selection = PassportPageSelection()
    @State private var hasStamped = false
    @State private var bonusStop: HistoricalStop?

    private var stops: [HistoricalStop] { tour.passportStops }
    private var currentPageIndex: Int {
        selection.currentIndex(stopIDs: stops.map(\.id), initialStopID: initialStopID)
    }
    private var pageSelection: Binding<Int> {
        Binding(get: { currentPageIndex }, set: { selection.choose($0) })
    }
    private var isAwaitingStamp: Bool {
        PassportPageSelection.isAwaitingStampReveal(
            animatedStopID: animatedStampStopID,
            bonusIsSaved: animatedStampStopID.map { tour.activities[$0].bonusFoundAt != nil } ?? false,
            hasStamped: hasStamped)
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
            if stops.isEmpty {
                ContentUnavailableView("No on-site stamps yet", systemImage: "book.closed",
                                       description: Text("Plaque discoveries will appear here when they become available."))
            } else {
                GeometryReader { viewport in
                    let pages = stops.map { stop in
                        AnyView(PassportLeaf(stop: stop,
                            collected: tour.activities[stop.id].bonusFoundAt != nil,
                            revealStamp: PassportPageSelection.shouldRevealStamp(
                                stopID: stop.id, animatedStopID: animatedStampStopID, hasStamped: hasStamped),
                            reduceMotion: reduceMotion,
                            availableHeight: viewport.size.height,
                            onOpenBonus: { bonusStop = stop })
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
        .sheet(item: $bonusStop) { OnSiteBonusPreview(stop: $0) }
        .onAppear { selectInitialPage() }
        .onChange(of: stops.map(\.id)) { _, ids in
            selection.clampStoredIndex(stopCount: ids.count)
        }
        .task(id: scenePhase) {
            guard scenePhase == .active, !hasStamped, let id = animatedStampStopID,
                  tour.activities[id].bonusFoundAt != nil else { return }
            selectInitialPage()
            do { try await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 350)) }
            catch { return }
            withAnimation(reduceMotion ? .easeIn(duration: 0.2) : .spring(response: 0.48, dampingFraction: 0.66)) {
                hasStamped = true
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            UIAccessibility.post(notification: .announcement,
                                 argument: "Passport stamped. \(tour.stop(withID: id)?.name ?? "Stamp") collected.")
        }
        .accessibilityIdentifier("passport.screen")
    }

    private func selectInitialPage() {
        selection.selectInitialPage(stopIDs: stops.map(\.id), initialStopID: initialStopID)
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
            if !reduceMotion {
                Text("Swipe to turn pages").font(.footnote).foregroundStyle(AppTheme.secondaryInk)
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
    let onOpenBonus: () -> Void
    @ScaledMetric(relativeTo: .title) private var titleSize: CGFloat = 28

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 24)
                Button(action: onOpenBonus) {
                    PassportStampArtwork(stopID: stop.id)
                        .opacity(collected ? (revealStamp ? 1 : 0) : 0.18)
                        .scaleEffect(collected && !revealStamp && !reduceMotion ? 1.45 : 1)
                        .rotationEffect(.degrees(collected && !revealStamp && !reduceMotion ? -9 : 0))
                        .padding(.horizontal, 20)
                }
                .buttonStyle(.plain).disabled(!collected || !revealStamp)
                .accessibilityLabel("\(stop.name) stamp, \(collected ? "collected" : "not collected")")
                .accessibilityHint(collected ? "Opens the on-site bonus" : "Find the plaque with AR to collect this stamp")
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

struct PassportStampArtwork: View {
    let stopID: String
    private var assetName: String? { PassportPageSelection.stampAssetName(for: stopID) }
    var body: some View {
        Group {
            if let assetName {
                Image(assetName).renderingMode(.original).resizable().scaledToFit()
            } else {
                // New plaque-enabled stops get pages immediately; custom stamp art can follow.
                Image(systemName: "seal").resizable().scaledToFit()
                    .foregroundStyle(AppTheme.forest).padding(24)
            }
        }
        .aspectRatio(1.4, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

struct PassportStampRow: View {
    let stop: HistoricalStop
    let collectedCount: Int
    let totalCount: Int
    let action: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: action) {
                HStack(spacing: 12) {
                    PassportStampArtwork(stopID: stop.id).frame(width: 88, height: 68)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Passport stamped").font(.system(.title3, design: .serif).weight(.semibold))
                        Text("\(stop.name) · \(collectedCount) of \(totalCount) discoveries")
                            .font(.subheadline).foregroundStyle(AppTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right").font(.subheadline)
                }
                .padding(.vertical, 12).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens your passport at this collected stamp")
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
