import Foundation

/// Where the AR marker/story card should live. Arrival uses the proximity state machine;
/// recorded visits require the separate `StopActivationPolicy` and an explicit activation.
public enum SignPlacementMode: String, Sendable, Equatable {
    /// No card. Arrows/HUD stay as they are.
    case hidden
    /// At the stop (or looking around) and the plate has not been recognized yet.
    case searchingForPlaque
    /// Card is locked to the recognized plate.
    case plaqueAnchored
    /// Simulator, missing reference, timeout, or lost tracking — existing geo sign.
    case geoFallback
}

/// Inputs for `SignPlacementPolicy`. Kept as a value type so the decision can be unit-tested
/// without ARKit or SwiftUI.
public struct SignPlacementInput: Equatable, Sendable {
    public var proximity: StopProximityState?
    /// `TourViewModel.presentedSignStopID != nil` — the state machine asked for a sign.
    public var isSignRequested: Bool
    public var hasManuallyDismissed: Bool
    public var stopHasPlaqueReference: Bool
    public var imageTrackingAvailable: Bool
    public var plaqueDetected: Bool
    public var searchElapsed: TimeInterval
    public var searchTimeout: TimeInterval

    public init(
        proximity: StopProximityState?,
        isSignRequested: Bool,
        hasManuallyDismissed: Bool,
        stopHasPlaqueReference: Bool,
        imageTrackingAvailable: Bool,
        plaqueDetected: Bool,
        searchElapsed: TimeInterval,
        searchTimeout: TimeInterval = SignPlacementPolicy.searchTimeout
    ) {
        self.proximity = proximity
        self.isSignRequested = isSignRequested
        self.hasManuallyDismissed = hasManuallyDismissed
        self.stopHasPlaqueReference = stopHasPlaqueReference
        self.imageTrackingAvailable = imageTrackingAvailable
        self.plaqueDetected = plaqueDetected
        self.searchElapsed = searchElapsed
        self.searchTimeout = searchTimeout
    }
}

/// Pure placement rules for the Droescher's Mill door plaque (and any future plate).
public enum SignPlacementPolicy {
    /// Give the camera a few seconds to lock the plate before using the geo sign.
    public static let searchTimeout: TimeInterval = 8
    public static let millPlaqueHint = "Look for the mill plaque on the door"

    /// Unmeasured initial reference-image width, retained until a physical measurement is supplied.
    /// ARKit automatic image-scale estimation corrects translation when it can estimate the size.
    public static let assumedPlaqueWidthMeters: Double = 0.18

    /// ARKit resource group and reference-image name for stop 1.
    public static let resourceGroupName = "PlaqueAnchors"
    public static let millReferenceImageName = "droeschers-mill-plaque"

    public static let parkReferenceImageName = "greystone-cranford-park-plaque"
    /// The original photograph includes stone around the plaque. This is the estimated
    /// width of that entire reference frame, NOT a measured plaque width.
    public static let assumedParkReferenceWidthMeters: Double = 0.75

    public static func discoveryHint(referenceImageName: String?) -> String {
        switch referenceImageName {
        case millReferenceImageName: return "Find the plaque beside the red double doors"
        case parkReferenceImageName: return "Find the black Cranford Park plaque on the stone wall"
        default: return "Find this stop’s plaque"
        }
    }

    /// Resolve physical site identity before comparing against the guided destination.
    /// Unknown or ambiguous reference names must never unlock a different stop.
    public static func recognizedStop(imageName: String?, isTracked: Bool,
                                      trackingReady: Bool, stops: [HistoricalStop]) -> HistoricalStop? {
        guard isTracked, trackingReady, let imageName, !imageName.isEmpty else { return nil }
        let matches = stops.filter { $0.hasPlaqueReference && $0.plaque?.referenceImageName == imageName }
        return matches.count == 1 ? matches[0] : nil
    }

    public static func matchesReference(_ detectedName: String?, expectedName: String?) -> Bool {
        guard let expectedName, !expectedName.isEmpty else { return false }
        return detectedName == expectedName
    }

    public static func mode(_ input: SignPlacementInput) -> SignPlacementMode {
        // Dismissed this visit: do not re-show from a later image-track. Leave and
        // re-enter the 50 m departure radius (existing hysteresis) to re-arm.
        if input.hasManuallyDismissed { return .hidden }
        switch input.proximity {
        case .signDismissed, .completed, .none:
            return .hidden
        case .approaching, .nearby, .signPresented:
            break
        }

        guard input.isSignRequested else { return .hidden }

        guard input.stopHasPlaqueReference else { return .geoFallback }
        guard input.imageTrackingAvailable else { return .geoFallback }

        if input.plaqueDetected { return .plaqueAnchored }
        if input.searchElapsed >= input.searchTimeout { return .geoFallback }
        return .searchingForPlaque
    }

    /// Restrained HUD line while the plate is still being looked for.
    public static func plaqueHint(mode: SignPlacementMode, stopHasPlaqueReference: Bool, proximity: StopProximityState?) -> String? {
        guard stopHasPlaqueReference else { return nil }
        switch proximity {
        case .signDismissed, .completed, .none:
            return nil
        case .approaching, .nearby, .signPresented:
            break
        }
        switch mode {
        case .plaqueAnchored:
            return "Plaque recognized — the historical sign is just above it"
        case .geoFallback:
            return nil
        case .hidden, .searchingForPlaque:
            return millPlaqueHint
        }
    }

    /// Keep the existing AR arrows while hunting for the plate, even inside the arrival radius.
    public static func shouldKeepNavigationArrows(mode: SignPlacementMode, insideArrivalRadius: Bool) -> Bool {
        if mode == .searchingForPlaque { return true }
        return !insideArrivalRadius
    }
}

/// Local-space offset of the tour card from the recognized plate.
///
/// ARKit image-anchor convention (Apple): the image lies in the **X–Z plane**,
/// **+X** is right along the plate, **+Y** points out of the plate toward the camera,
/// **+Z** points down the wall. “Up the facade” is therefore **−Z**.
///
/// Keep the card just above the plaque so it remains reachable in the camera view.
public struct PlaqueCardOffset: Equatable, Sendable {
    public var rightMeters: Double
    /// Toward the camera, off the door.
    public var outMeters: Double
    /// Up the wall (stored positive; applied as −Z in image space).
    public var upMeters: Double

    public init(rightMeters: Double, outMeters: Double, upMeters: Double) {
        self.rightMeters = rightMeters
        self.outMeters = outMeters
        self.upMeters = upMeters
    }

    /// Default: centered above the plate, slightly off the wall, within the visitor's view.
    public static let abovePlaque = PlaqueCardOffset(rightMeters: 0, outMeters: 0.08, upMeters: 0.25)

    /// Image-anchor local translation: (right, out, down) = (X, Y, −up).
    public var imageLocalTranslation: (x: Double, y: Double, z: Double) {
        (rightMeters, outMeters, -upMeters)
    }
}
