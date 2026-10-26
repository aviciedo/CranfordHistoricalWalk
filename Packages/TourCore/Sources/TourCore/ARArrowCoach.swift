import Foundation

/// Copy and visibility gates for walking arrows. A hidden sign must say why, except while
/// ground scanning, which already has its own coach, and after the stop is activated.
public enum ARArrowCoach {
    public static let trackingNotReady = "AR tracking is not ready. Hold still and slowly scan your surroundings."
    public static let needsRoute = "Walking arrows need a walking route and a fresh location. Use the map or retry directions."
    public static let waitingForAlignment = "Waiting for accurate location and compass alignment. Use the map while AR aligns."
    public static let noDirection = "No walking direction is available. Return to the map to check your route."
    public static let arrowsCouldNotLoad = "The AR arrows could not load. Return to the map for directions."
    public static let noRoutePosition = "No nearby route position is available. Check your location on the map."
    public static let unableToPlace = "Unable to place walking arrows. Scan the pavement or return to the map."
    public static let walkFarther = "Walk a little farther along the route to bring the arrows into view."
    public static let turnRight = "Turn your phone to the right to see the arrows."
    public static let turnLeft = "Turn your phone to the left to see the arrows."
    public static let raiseOrTilt = "Raise or tilt your phone toward the route to see the arrows."

    /// Once a pose is pinned, the renderer may hide it outside this horizontal range
    /// without forgetting the pose. New placements still use the tighter 3...14 m gate.
    public static let pinnedSignRange = 2.0...20.0
    public static let offScreenBearingDegrees = 35.0

    public static func trackingNotice(hasActivatedStop: Bool) -> String? {
        hasActivatedStop ? nil : trackingNotReady
    }

    /// `canProjectPlacement` is false when the sign has no world position or no view to project into.
    /// On-screen requires the sign to be in front as well; a large bearing behind the phone still turns.
    public static func screenNotice(canProjectPlacement: Bool, isInFront: Bool, isOnScreen: Bool,
                                    relativeBearing: Double?) -> String? {
        guard canProjectPlacement else { return walkFarther }
        if isInFront && isOnScreen { return nil }
        if let relativeBearing, abs(relativeBearing) > offScreenBearingDegrees {
            return relativeBearing > 0 ? turnRight : turnLeft
        }
        return raiseOrTilt
    }

    public static func keepsPinnedSignVisible(position: SIMD3<Double>, camera: SIMD3<Double>) -> Bool {
        guard [position.x, position.z, camera.x, camera.z].allSatisfy(\.isFinite) else { return false }
        return pinnedSignRange.contains(hypot(position.x - camera.x, position.z - camera.z))
    }
}
