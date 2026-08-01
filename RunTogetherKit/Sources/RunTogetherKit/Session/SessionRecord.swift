import Foundation

public enum SessionKind: String, Hashable, Sendable, Codable {
    case solo
    case paired
}

/// A session that was actually started, as opposed to one that was planned.
///
/// The window this describes is what a recorded workout gets matched against,
/// so it is written when the session starts and closed when it ends — including
/// when it ends early. A session abandoned after four minutes should not go
/// looking for a thirty-minute workout to claim.
public struct SessionRecord: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public let kind: SessionKind
    public let stage: PlanStage
    public let participantIDs: [RunnerID]
    public let startedAt: Date
    public var endedAt: Date?
    /// Whether the timeline ran to its end rather than being stopped early.
    public var ranToCompletion: Bool

    public init(
        id: UUID = UUID(),
        kind: SessionKind,
        stage: PlanStage,
        participantIDs: [RunnerID],
        startedAt: Date,
        endedAt: Date? = nil,
        ranToCompletion: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.stage = stage
        self.participantIDs = participantIDs
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.ranToCompletion = ranToCompletion
    }

    /// The time span to match workouts against. Falls back to the stage's
    /// planned length while a session is still in progress.
    public var window: DateInterval {
        let end = endedAt ?? startedAt.addingTimeInterval(TimeInterval(stage.totalSeconds))
        return DateInterval(start: startedAt, end: max(end, startedAt))
    }
}

/// A workout that was recorded and matched to a session.
public struct CompletedRun: Identifiable, Hashable, Sendable, Codable {
    /// The `HKWorkout` UUID string, so a workout is never imported twice.
    public let id: String
    public let runnerID: RunnerID
    public let sessionID: UUID?
    public let startedAt: Date
    public let endedAt: Date
    public let distanceMeters: Double?
    public let averageHeartRate: Double?

    public init(
        id: String,
        runnerID: RunnerID,
        sessionID: UUID?,
        startedAt: Date,
        endedAt: Date,
        distanceMeters: Double? = nil,
        averageHeartRate: Double? = nil
    ) {
        self.id = id
        self.runnerID = runnerID
        self.sessionID = sessionID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.distanceMeters = distanceMeters
        self.averageHeartRate = averageHeartRate
    }

    public var duration: TimeInterval {
        endedAt.timeIntervalSince(startedAt)
    }
}
