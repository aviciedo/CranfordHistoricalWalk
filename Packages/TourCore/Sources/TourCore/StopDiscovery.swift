import Foundation

/// Story and physical discovery are distinct. Reading/listening never verifies a plaque.
public struct StopDiscovery: Equatable, Sendable {
    public enum Stage: String, Equatable, Sendable {
        case approaching, story, listening, readyForDiscovery, searching, unlocked
    }
    public private(set) var stage: Stage = .approaching
    public private(set) var hasArrived = false
    public private(set) var hasOfferedArrivalStory = false
    public private(set) var hasFinishedStory = false
    public private(set) var hasVerifiedPlaque = false
    public private(set) var isPracticeUnlock = false

    public init() {}

    /// One arrival offer per walk; GPS jitter must not repeatedly interrupt the visitor.
    @discardableResult
    public mutating func arrive() -> Bool {
        hasArrived = true
        guard !hasOfferedArrivalStory else { return false }
        hasOfferedArrivalStory = true
        if stage == .approaching { stage = hasFinishedStory ? .readyForDiscovery : .story }
        return true
    }

    public mutating func openStory() {
        guard stage != .unlocked else { return }
        stage = hasFinishedStory ? .readyForDiscovery : .story
    }

    public mutating func narrationStarted() {
        guard stage != .searching, stage != .unlocked else { return }
        stage = .listening
    }

    /// Also used by an explicit "I've read the story" action; audio is optional.
    public mutating func finishStory() {
        hasFinishedStory = true
        if stage != .unlocked && stage != .searching { stage = .readyForDiscovery }
    }

    @discardableResult
    public mutating func beginDiscovery() -> Bool {
        guard hasFinishedStory else { return false }
        hasOfferedArrivalStory = true
        if stage != .unlocked { stage = .searching }
        return true
    }

    /// Must be called from an active discovery AR session with a currently tracked match.
    /// Repeated frame callbacks never duplicate the celebration or saved visit.
    @discardableResult
    public mutating func recognizePlaque(isMatching: Bool, trackingReady: Bool, isSimulated: Bool) -> Bool {
        guard stage == .searching, isMatching, trackingReady, !hasVerifiedPlaque else { return false }
        hasArrived = true
        hasVerifiedPlaque = true
        isPracticeUnlock = isSimulated
        stage = .unlocked
        return true
    }

    public var canContinue: Bool { hasFinishedStory }
    public var canOfferDiscovery: Bool { hasFinishedStory && !hasVerifiedPlaque }
}

/// Estimated bounds of the TWO glass panes in the mill's red doors, measured in plaque widths.
/// This is a plaque-relative placement, not independent window recognition or surveyed geometry.
/// Developer calibration refines the four ratios on site; the actual plaque width is unmeasured.
public struct WindowBonusLayout: Equatable, Sendable {
    public var right: Double
    public var up: Double
    public var width: Double
    public var height: Double

    public init(right: Double = 3.4, up: Double = 0.55, width: Double = 4.6, height: Double = 3.0) {
        self.right = right
        self.up = up
        self.width = width
        self.height = height
    }

    public func dimensions(plaqueWidthMeters: Double) -> (width: Double, height: Double)? {
        guard plaqueWidthMeters.isFinite, plaqueWidthMeters > 0,
              [right, up, width, height].allSatisfy(\.isFinite),
              width > 0, height > 0 else { return nil }
        return (width * plaqueWidthMeters, height * plaqueWidthMeters)
    }

    /// ARKit image anchors lie in XZ: +X right, +Y out of the plaque, -Z up the facade.
    public func translation(plaqueWidthMeters: Double) -> (x: Double, y: Double, z: Double)? {
        guard dimensions(plaqueWidthMeters: plaqueWidthMeters) != nil else { return nil }
        return (right * plaqueWidthMeters, 0.035, -up * plaqueWidthMeters)
    }
}
