import Foundation

/// Camera-relative guidance, independent of GPS north alignment and Apple rendering APIs.
public enum ARWalkingGuidance {
    public enum Direction: String, Equatable, Sendable {
        case ahead, left, right, bearLeft, bearRight, turnAround

        public var symbolName: String {
            switch self {
            case .ahead: return "arrow.up"
            case .left: return "arrow.left"
            case .right: return "arrow.right"
            case .bearLeft: return "arrow.up.left"
            case .bearRight: return "arrow.up.right"
            case .turnAround: return "arrow.uturn.down"
            }
        }

        public var instruction: String {
            switch self {
            case .ahead: return "Walk ahead"
            case .left: return "Turn left"
            case .right: return "Turn right"
            case .bearLeft: return "Bear left"
            case .bearRight: return "Bear right"
            case .turnAround: return "Turn around"
            }
        }
    }

    /// The next maneuver starts at the *next* step's start, not the current step's end instruction.
    public struct RouteCue: Equatable, Sendable {
        public var direction: Direction
        public var streetName: String?
        public var distanceMeters: Double
        public var coordinate: GeoCoordinate?
        public var stepIndex: Int
        public var isUpcomingTurn: Bool
        public var isTowardStreet: Bool

        public var distanceText: String { ARWalkingGuidance.feet(meters: distanceMeters) }
        public var streetLabel: String {
            guard let streetName else { return isUpcomingTurn ? "Next turn" : "Follow the walking route" }
            return isTowardStreet ? "Toward \(streetName)" : streetName
        }
        public var isNearTurn: Bool { isUpcomingTurn && distanceMeters <= 45 }
        public var instruction: String {
            guard isUpcomingTurn else { return "Continue for \(distanceText)" }
            return distanceMeters <= 3 ? "\(direction.instruction) now" : "\(direction.instruction) in \(distanceText)"
        }
    }

    /// Entry guidance settles only after sustained alignment. Different show/hide angles
    /// prevent GPS/compass noise from flashing the large arrow near a boundary.
    public struct OrientationState: Sendable {
        public private(set) var isPresented = true
        private var startedAt: TimeInterval?
        private var alignedSince: TimeInterval?

        public init() {}

        @discardableResult
        public mutating func update(relativeBearing: Double?, timestamp: TimeInterval, isAtStop: Bool) -> Bool {
            if isAtStop {
                isPresented = false
                alignedSince = nil
                return isPresented
            }
            guard let bearing = relativeBearing, bearing.isFinite, timestamp.isFinite else {
                isPresented = true
                startedAt = nil
                alignedSince = nil
                return isPresented
            }
            if startedAt == nil || timestamp < (startedAt ?? timestamp) { startedAt = timestamp; alignedSince = nil }
            if abs(bearing) > 50 {
                isPresented = true
                alignedSince = nil
            } else if abs(bearing) < 22 {
                if alignedSince == nil { alignedSince = timestamp }
                if timestamp - (alignedSince ?? timestamp) >= 1.2,
                   timestamp - (startedAt ?? timestamp) >= 2.5 { isPresented = false }
            } else {
                alignedSince = nil
            }
            return isPresented
        }
    }

    /// Positive means turn right. A near-vertical camera has no usable horizontal facing.
    public static func relativeBearing(directionX: Double, directionZ: Double, cameraForwardX: Double, cameraForwardZ: Double) -> Double? {
        let values = [directionX, directionZ, cameraForwardX, cameraForwardZ]
        guard values.allSatisfy(\.isFinite),
              hypot(directionX, directionZ) > 0.001,
              hypot(cameraForwardX, cameraForwardZ) > 0.15 else { return nil }
        let targetYaw = atan2(directionX, -directionZ) * 180 / .pi
        let cameraYaw = atan2(cameraForwardX, -cameraForwardZ) * 180 / .pi
        return GeoMath.relativeBearing(heading: cameraYaw, bearing: targetYaw)
    }

    public static func instruction(for relativeBearing: Double?) -> String {
        guard let bearing = relativeBearing, bearing.isFinite else { return "Hold your phone up and look around" }
        return direction(for: bearing).instruction
    }

    public static func direction(for bearing: Double) -> Direction {
        guard bearing.isFinite else { return .ahead }
        switch abs(bearing) {
        case ..<20: return .ahead
        case ..<65: return bearing > 0 ? .bearRight : .bearLeft
        case ..<135: return bearing > 0 ? .right : .left
        default: return .turnAround
        }
    }

    /// Always feet for the AR maneuver, independent of the map's miles/feet formatting.
    public static func feet(meters: Double) -> String {
        guard meters.isFinite, meters >= 0, meters < 1_000_000 else { return "—" }
        let rounded = Int((GeoMath.feet(fromMeters: meters) / 10).rounded()) * 10
        return "\(meters > 0 ? max(10, rounded) : 0) ft"
    }

    /// Time-based filtering takes the short path across ±180° rather than spinning 358°.
    public static func smoothAngle(from previous: Double?, to target: Double, elapsed: TimeInterval, response: TimeInterval = 0.22) -> Double? {
        guard target.isFinite else { return nil }
        guard let previous, previous.isFinite else { return GeoMath.relativeBearing(heading: 0, bearing: target) }
        guard elapsed.isFinite, elapsed > 0, response.isFinite, response > 0 else { return previous }
        let alpha = 1 - exp(-min(elapsed, 0.5) / response)
        let change = GeoMath.relativeBearing(heading: previous, bearing: target)
        return GeoMath.relativeBearing(heading: 0, bearing: previous + change * alpha)
    }

    /// Near a route vertex, use the approach segment's direction instead of a tiny
    /// GPS-to-vertex vector that can reverse as the fix drifts across the corner.
    /// Off-route fixes need a refreshed walking route, not a direct shortcut to the stop.
    public static func walkingBearing(route: WalkingRoute, progress: RouteProgress, user: GeoCoordinate) -> Double? {
        guard route.source != .straightLineEstimate, user.isValid,
              progress.distanceFromRoute.isFinite, progress.distanceFromRoute <= 35,
              progress.distanceFromRoute >= 0,
              route.routeCoordinates.indices.contains(progress.segmentIndex),
              route.routeCoordinates.indices.contains(progress.segmentIndex + 1) else { return nil }
        let start = route.routeCoordinates[progress.segmentIndex]
        let end = route.routeCoordinates[progress.segmentIndex + 1]
        guard start.isValid, end.isValid, GeoMath.distance(from: start, to: end) > 0.1 else { return nil }
        if GeoMath.distance(from: progress.snappedCoordinate, to: end) <= 3 {
            return GeoMath.bearing(from: start, to: end)
        }
        return GeoMath.bearing(from: user, to: end)
    }

    public static func routeCue(route: WalkingRoute, progress: RouteProgress) -> RouteCue? {
        guard route.source != .straightLineEstimate, progress.distanceFromRoute.isFinite,
              progress.distanceFromRoute <= 35, progress.fractionComplete.isFinite,
              let index = progress.currentStepIndex, route.routeSteps.indices.contains(index) else { return nil }
        let steps = route.routeSteps
        let lengths = steps.map { $0.distanceMeters.isFinite ? max(0, $0.distanceMeters) : 0 }
        let total = lengths.reduce(0, +)
        guard total > 0 else { return nil }
        let traveled = min(1, max(0, progress.fractionComplete)) * total
        var boundary = lengths.prefix(index + 1).reduce(0, +)
        // Skip non-turn instructions (e.g. "Continue") but retain their walking distance.
        for next in steps.indices.dropFirst(index + 1) {
            if let direction = maneuverDirection(steps[next]) {
                let street = street(in: steps[next].instruction)
                return RouteCue(direction: direction, streetName: street?.name,
                                distanceMeters: max(0, boundary - traveled),
                                coordinate: steps[next].startCoordinate.isValid ? steps[next].startCoordinate : nil,
                                stepIndex: next, isUpcomingTurn: true, isTowardStreet: street?.toward ?? false)
            }
            boundary += lengths[next]
        }
        let street = street(in: steps[index].instruction)
        return RouteCue(direction: .ahead, streetName: street?.name,
                        distanceMeters: max(0, progress.remainingMeters), coordinate: nil,
                        stepIndex: index, isUpcomingTurn: false, isTowardStreet: street?.toward ?? false)
    }

    public static func currentStreetLabel(route: WalkingRoute, progress: RouteProgress) -> String? {
        guard route.source != .straightLineEstimate, let index = progress.currentStepIndex,
              route.routeSteps.indices.contains(index), let street = street(in: route.routeSteps[index].instruction) else { return nil }
        return street.toward ? "Toward \(street.name)" : street.name
    }

    private static func maneuverDirection(_ step: RouteStep) -> Direction? {
        let maneuver = (step.maneuver ?? "").replacingOccurrences(of: "-", with: "_").uppercased()
        if maneuver.contains("UTURN") || maneuver.contains("U_TURN") { return .turnAround }
        if maneuver.contains("LEFT") { return maneuver.contains("SLIGHT") ? .bearLeft : .left }
        if maneuver.contains("RIGHT") { return maneuver.contains("SLIGHT") ? .bearRight : .right }
        // Legacy routes may omit the maneuver but still supply an English instruction.
        let text = (step.instruction ?? "").lowercased()
        if text.hasPrefix("turn left") || text.hasPrefix("keep left") { return .left }
        if text.hasPrefix("turn right") || text.hasPrefix("keep right") { return .right }
        if text.hasPrefix("bear left") { return .bearLeft }
        if text.hasPrefix("bear right") { return .bearRight }
        return nil
    }

    /// Routes are requested in en-US. Never infer a street from the historical stop's address.
    private static func street(in instruction: String?) -> (name: String, toward: Bool)? {
        guard let instruction else { return nil }
        let pattern = #"\b(onto|on|towards?)\s+(.+?)(?=\s+towards?\s+|\n|\s+Destination\b|\s+Pass by\b|$)"#
        guard let match = instruction.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { return nil }
        let phrase = String(instruction[match]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let space = phrase.firstIndex(of: " ") else { return nil }
        let name = String(phrase[phrase.index(after: space)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !["the left", "the right", "your left", "your right"].contains(name.lowercased()) else { return nil }
        return (name, phrase.lowercased().hasPrefix("toward"))
    }
}
