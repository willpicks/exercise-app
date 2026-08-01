import Foundation

/// A session both runners will do together, plus the per-runner cue tracks.
public struct PairedPlan: Hashable, Sendable {
    /// The shared lane. Both runners do exactly this.
    public let stage: PlanStage
    public let tracks: [CueTrack]

    public init(stage: PlanStage, tracks: [CueTrack]) {
        self.stage = stage
        self.tracks = tracks
    }

    public func track(for runnerID: RunnerID) -> CueTrack? {
        tracks.first { $0.runnerID == runnerID }
    }
}

/// Builds the shared lane for a paired run.
public enum SessionComposer {

    /// Composes two stages into one that is safe for both runners.
    ///
    /// The merge is **conservative on each axis independently**, which is
    /// stricter than picking whichever stage is "gentler overall" — and the
    /// difference matters. Consider 10 x 1:00 against 1 x 5:00. The second has
    /// less total running, so an overall-gentler rule would select it and hand
    /// the first runner a five-minute continuous interval when their own ladder
    /// says one minute. Taking the minimum of each axis separately cannot make
    /// that mistake:
    ///
    /// - run interval → the shorter of the two
    /// - running volume → the smaller of the two
    /// - walk recovery → the **longer** of the two (more recovery is gentler)
    /// - warmup and cooldown → the longer of each
    ///
    /// The result is therefore never harder than either input on any dimension.
    public static func compose(_ a: PlanStage, _ b: PlanStage) -> PlanStage {
        let volumeCap = min(a.totalRunSeconds, b.totalRunSeconds)

        // A single interval can never exceed the shared volume allowance.
        var runSeconds = min(a.runSeconds, b.runSeconds)
        runSeconds = min(runSeconds, volumeCap)
        runSeconds = max(runSeconds, 1)

        // Integer division floors, so repeats can never push volume over the cap.
        let repeats = max(1, volumeCap / runSeconds)

        return PlanStage(
            index: min(a.index, b.index),
            warmupWalkSeconds: max(a.warmupWalkSeconds, b.warmupWalkSeconds),
            repeats: repeats,
            runSeconds: runSeconds,
            walkSeconds: max(a.walkSeconds, b.walkSeconds),
            cooldownWalkSeconds: max(a.cooldownWalkSeconds, b.cooldownWalkSeconds)
        )
    }

    /// The shared lane for two runners at their current stages, with an
    /// identical cue track issued to each.
    public static func pairedPlan(for runners: (Runner, Runner)) -> PairedPlan {
        let (first, second) = runners
        let shared = compose(first.currentStage, second.currentStage)
        return PairedPlan(
            stage: shared,
            tracks: [
                SessionTimeline.track(for: shared, runnerID: first.id),
                SessionTimeline.track(for: shared, runnerID: second.id)
            ]
        )
    }

    /// A solo session straight off one runner's own ladder — uncomposed,
    /// because there is nobody to stay level with.
    public static func soloPlan(for runner: Runner) -> PairedPlan {
        let stage = runner.currentStage
        return PairedPlan(
            stage: stage,
            tracks: [SessionTimeline.track(for: stage, runnerID: runner.id)]
        )
    }
}
