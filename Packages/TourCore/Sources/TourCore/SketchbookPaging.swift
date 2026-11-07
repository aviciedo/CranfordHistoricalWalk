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
}

/// Front-paper crop for the sketchbook scan. The reverse face stays full bleed.
public enum SketchbookPaperFraming {
    /// Pale exterior past the scan's right edge, as a fraction of the source.
    private static let trailingMargin: Double = 0.015
    /// Pale exterior past the scan's bottom edge, as a fraction of the source.
    private static let bottomMargin: Double = 0.008

    public struct SourceFrame: Equatable, Sendable {
        public var x: Double
        public var y: Double
        public var width: Double
        public var height: Double
    }

    /// Top-leading source rect. Clipping the overflow removes only the pale
    /// exterior, so the cloth gutter on the leading edge stays in frame.
    public static func sourceFrame(viewportWidth: Double, viewportHeight: Double) -> SourceFrame? {
        guard viewportWidth.isFinite, viewportHeight.isFinite,
              viewportWidth > 0, viewportHeight > 0,
              trailingMargin > 0, trailingMargin < 1,
              bottomMargin > 0, bottomMargin < 1 else { return nil }
        return SourceFrame(x: 0, y: 0,
                           width: viewportWidth / (1 - trailingMargin),
                           height: viewportHeight / (1 - bottomMargin))
    }
}
