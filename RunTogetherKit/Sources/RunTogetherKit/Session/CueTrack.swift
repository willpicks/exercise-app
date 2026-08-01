import Foundation

public enum Activity: String, Hashable, Sendable, Codable {
    case walk
    case run
}

/// Cue vocabulary. Deliberately tiny — two in-run patterns, learned in one
/// session, distinguishable through a sleeve at the end of a hard interval.
public enum HapticCue: String, Hashable, Sendable, Codable {
    case startRun
    case startWalk
    case sessionComplete
}

/// One instruction on the timeline.
public struct Segment: Hashable, Sendable, Codable {
    /// Seconds from the start of the session.
    public let offsetSeconds: Int
    public let durationSeconds: Int
    public let activity: Activity
    public let spokenCue: String
    public let haptic: HapticCue

    public init(
        offsetSeconds: Int,
        durationSeconds: Int,
        activity: Activity,
        spokenCue: String,
        haptic: HapticCue
    ) {
        self.offsetSeconds = offsetSeconds
        self.durationSeconds = durationSeconds
        self.activity = activity
        self.spokenCue = spokenCue
        self.haptic = haptic
    }

    public var endSeconds: Int {
        offsetSeconds + durationSeconds
    }

    public func contains(elapsedSeconds: Int) -> Bool {
        elapsedSeconds >= offsetSeconds && elapsedSeconds < endSeconds
    }
}

/// The complete instruction timeline for one runner in one session.
///
/// At launch both runners in a paired session receive identical tracks — that
/// is the whole point of the shared lane. The type stays per-runner so that an
/// optional per-runner divergence can be added later without a migration.
public struct CueTrack: Hashable, Sendable, Codable {
    public let runnerID: RunnerID
    public let segments: [Segment]

    public init(runnerID: RunnerID, segments: [Segment]) {
        self.runnerID = runnerID
        self.segments = segments
    }

    public var totalSeconds: Int {
        segments.last?.endSeconds ?? 0
    }

    public func segment(atElapsed elapsedSeconds: Int) -> Segment? {
        segments.first { $0.contains(elapsedSeconds: elapsedSeconds) }
    }

    public func segment(afterElapsed elapsedSeconds: Int) -> Segment? {
        segments.first { $0.offsetSeconds > elapsedSeconds }
    }
}

/// Spoken duration phrasing, e.g. "1 minute 30 seconds".
public enum DurationPhrase {
    public static func spoken(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let minutes = total / 60
        let remainder = total % 60
        switch (minutes, remainder) {
        case (0, _):
            return "\(remainder) \(remainder == 1 ? "second" : "seconds")"
        case (_, 0):
            return "\(minutes) \(minutes == 1 ? "minute" : "minutes")"
        default:
            return "\(minutes) \(minutes == 1 ? "minute" : "minutes") "
                + "\(remainder) \(remainder == 1 ? "second" : "seconds")"
        }
    }
}
