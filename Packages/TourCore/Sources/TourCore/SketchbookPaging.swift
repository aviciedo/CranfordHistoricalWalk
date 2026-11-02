import Foundation

/// Sketchbook pages follow plaque-stop identity. Unlock order and a hard-coded
/// tour slot must not choose the page.
public enum SketchbookPageIndex {
    public static func initial(stopID: String, pageStopIDs: [String]) -> Int {
        pageStopIDs.firstIndex(of: stopID) ?? 0
    }

    /// A shrinking catalog keeps the stored index on a real page.
    public static func clamped(_ index: Int, pageCount: Int) -> Int {
        max(0, min(index, max(0, pageCount - 1)))
    }
}

/// Each logical sketch occupies a front and a parchment back. Animated curls
/// need both physical faces; the back is not another logical page.
public enum SketchbookCurlLayout {
    public static func frontControllerIndex(logicalPage: Int) -> Int {
        logicalPage * 2
    }

    public static func logicalPage(controllerIndex: Int) -> Int {
        controllerIndex / 2
    }

    /// Opening a book shows one front. Every animated turn, including a return to the
    /// previous sketch, supplies that front and its parchment back, in that order.
    public static func presentedControllerIndices(logicalPage: Int, animated: Bool) -> [Int] {
        let front = frontControllerIndex(logicalPage: logicalPage)
        if animated { return [front, front + 1] }
        return [front]
    }

    /// An interrupted curl keeps the face UIKit actually left visible when the request
    /// is still the one that started the turn. A finished turn, and a page chosen while
    /// the animation was in flight, stay on the parent index.
    public static func indexAfterAnimatedCurl(requested: Int, visible: Int,
                                              animationCompleted: Bool, parentIndex: Int) -> Int {
        if !animationCompleted, parentIndex == requested, visible != requested {
            return visible
        }
        return parentIndex
    }
}
