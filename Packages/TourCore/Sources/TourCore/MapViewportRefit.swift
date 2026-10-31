import Foundation

/// A bounds fit is tied to the viewport. Guidance text can shrink the map without
/// moving GPS or the route, so that fit is issued again, unanimated. A follow,
/// zoom, or free camera is the visitor's and must stay put. A zero-sized layout
/// pass has no bounds to fit.
public enum MapViewportRefit {
    public enum Camera: Equatable, Sendable {
        case overview, navigation, follow, free
    }

    public enum Fit: Equatable, Sendable {
        /// `fitAll`, `fitUserAndDestination`, and `fitWalkingLeg`.
        case bounds
        /// `follow` and `zoomTo`.
        case positioned
    }

    public static func acceptsSize(width: Double, height: Double) -> Bool {
        width > 0 && height > 0
    }

    public static func shouldReissue(camera: Camera, fit: Fit?, hasRequest: Bool) -> Bool {
        guard hasRequest, camera == .overview || camera == .navigation, fit == .bounds else { return false }
        return true
    }
}
