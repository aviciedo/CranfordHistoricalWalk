import Foundation

/// Thumbnail beside a stop in the Stops list. Stops 1–3 use supplied artwork. Later stops
/// stay symbolic until their own reference photographs exist.
public enum StopListArtwork: Equatable, Sendable {
    case bundled(name: String)
    case symbolic(isChurch: Bool)

    public static func selection(for stopID: String) -> StopListArtwork {
        switch stopID {
        case "hpab-001":
            return .bundled(name: "mill-map-landmark")
        case "hpab-002":
            return .bundled(name: "greystone-map-landmark")
        case "hpab-003":
            return .bundled(name: "rahway-river-illustration")
        default:
            return .symbolic(isChurch: stopID == "hpab-004")
        }
    }
}
