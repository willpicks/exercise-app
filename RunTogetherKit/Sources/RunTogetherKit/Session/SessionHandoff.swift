import Foundation

/// Everything the Watch needs to run a session on its own.
///
/// The phone sends this once, at the moment a session starts, and then says
/// nothing more. The Watch computes its own position from `startedAt` using the
/// same `SessionProgressCalculator` the phone uses, so the two stay in step
/// without a live connection — which matters, because a wrist and a pocket lose
/// sight of each other constantly mid-run.
///
/// This is the same absolute-anchor idea that makes two-phone sync work in
/// Phase 5, applied one device closer in.
public struct SessionHandoff: Codable, Hashable, Sendable {
    public let sessionID: UUID
    public let startedAt: Date
    public let stage: PlanStage
    public let track: CueTrack

    public init(sessionID: UUID, startedAt: Date, stage: PlanStage, track: CueTrack) {
        self.sessionID = sessionID
        self.startedAt = startedAt
        self.stage = stage
        self.track = track
    }
}
