import Foundation

/// Sketchbook pages follow plaque-stop identity. Unlock order and a hard-coded
/// tour slot must not choose the page.
public enum SketchbookPageIndex {
    public static func initial(stopID: String, pageStopIDs: [String]) -> Int {
        pageStopIDs.firstIndex(of: stopID) ?? 0
    }

    /// A shrinking catalog keeps the stored index on a real page.
    public static func clamped(_ index: Int, pageCount: Int) -> Int {
        min(index, max(0, pageCount - 1))
    }
}

/// A minimum page-curl spine shows one front. Each logical sketch occupies a
/// front and a parchment back; the back is not another page.
public enum SketchbookCurlLayout {
    public static func frontControllerIndex(logicalPage: Int) -> Int {
        logicalPage * 2
    }

    public static func logicalPage(controllerIndex: Int) -> Int {
        controllerIndex / 2
    }
}
