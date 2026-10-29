import Foundation

/// One real GPS fix considered for the session-local walked trail.
public struct WalkedTrailFix: Equatable, Sendable {
    public var coordinate: GeoCoordinate
    public var timestamp: Date
    public var horizontalAccuracy: Double
    public var speed: Double?
    public var isSimulated: Bool

    public init(coordinate: GeoCoordinate, timestamp: Date, horizontalAccuracy: Double,
                speed: Double? = nil, isSimulated: Bool = false) {
        self.coordinate = coordinate
        self.timestamp = timestamp
        self.horizontalAccuracy = horizontalAccuracy
        self.speed = speed
        self.isSimulated = isSimulated
    }
}

/// Segments already accepted, plus the last fix used for gap and speed checks.
public struct WalkedTrailState: Equatable, Sendable {
    public var segments: [[GeoCoordinate]]
    public var lastFix: WalkedTrailFix?

    public init(segments: [[GeoCoordinate]] = [], lastFix: WalkedTrailFix? = nil) {
        self.segments = segments
        self.lastFix = lastFix
    }
}

/// Which real walking fixes are drawn, and where a gap must break the line.
/// The map never invents a connector across a pause, a stale fix, or a GPS jump.
public enum WalkedTrailPolicy {
    public static let maximumAccuracyMeters: Double = 25
    public static let maximumGapSeconds: TimeInterval = 10
    public static let maximumSpeedMetersPerSecond: Double = 4
    public static let minimumPointSeparationMeters: Double = 2
    public static let maximumStoredPoints: Int = 6000

    public static func accepts(_ fix: WalkedTrailFix, isWalking: Bool, isAuthorized: Bool,
                               isPracticeSource: Bool, now: Date) -> Bool {
        isWalking && isAuthorized && !fix.isSimulated && !isPracticeSource
            && fix.coordinate.isValid
            && StopActivationPolicy.isFresh(fix.timestamp, now: now)
            && fix.horizontalAccuracy.isFinite
            && (0...maximumAccuracyMeters).contains(fix.horizontalAccuracy)
            && (fix.speed.map { $0.isFinite && $0 <= maximumSpeedMetersPerSecond } ?? true)
    }

    /// Inclusive on both edges: 10 s still continues, and 4 m/s still continues.
    public static func continues(elapsed: TimeInterval, meters: Double) -> Bool {
        elapsed <= maximumGapSeconds && meters / elapsed <= maximumSpeedMetersPerSecond
    }

    /// Inclusive: a fix exactly 2 m from the last drawn point is kept.
    public static func keepsDrawnPoint(metersFromLastDrawn: Double) -> Bool {
        metersFromLastDrawn >= minimumPointSeparationMeters
    }

    public static func record(_ fix: WalkedTrailFix, into state: inout WalkedTrailState,
                              isWalking: Bool, isAuthorized: Bool, isPracticeSource: Bool, now: Date) {
        guard accepts(fix, isWalking: isWalking, isAuthorized: isAuthorized,
                      isPracticeSource: isPracticeSource, now: now) else {
            state.lastFix = nil
            return
        }
        // A repeated or reordered sample must not erase the anchor or add a point.
        if let previous = state.lastFix, fix.timestamp <= previous.timestamp { return }
        let previous = state.lastFix
        state.lastFix = fix
        let joins: Bool
        if let previous {
            let elapsed = fix.timestamp.timeIntervalSince(previous.timestamp)
            joins = continues(elapsed: elapsed, meters: GeoMath.distance(from: previous.coordinate, to: fix.coordinate))
        } else {
            joins = false
        }
        if joins, let last = state.segments.last?.last {
            if keepsDrawnPoint(metersFromLastDrawn: GeoMath.distance(from: last, to: fix.coordinate)) {
                state.segments[state.segments.count - 1].append(fix.coordinate)
            }
        } else if state.segments.last?.count == 1 {
            // A lone point cannot be drawn. Replace it so a later gap cannot bridge back to it.
            state.segments[state.segments.count - 1] = [fix.coordinate]
        } else {
            state.segments.append([fix.coordinate])
        }
        trim(&state.segments)
    }

    /// Hide a segment until it has two finite coordinates. Do not join the pieces that remain.
    public static func drawableSegments(_ segments: [[GeoCoordinate]]) -> [[GeoCoordinate]] {
        segments.filter { $0.count >= 2 && $0.allSatisfy(\.isValid) }
    }

    private static func trim(_ segments: inout [[GeoCoordinate]]) {
        while segments.reduce(0, { $0 + $1.count }) > maximumStoredPoints {
            if segments[0].count > 2 { segments[0].removeFirst() }
            else { segments.removeFirst() }
        }
    }
}
