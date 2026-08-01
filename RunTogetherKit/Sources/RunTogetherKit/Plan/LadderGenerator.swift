import Foundation

/// Turns a `PlanSpec` into a concrete ladder of sessions.
///
/// One implementation serves both runners. The difference between a rehab
/// ladder and a beginner ladder is entirely in the spec's caps and growth
/// rates, not in the algorithm.
///
/// Two properties are load-bearing and are covered by tests:
///
/// 1. **Caps are never exceeded.** Not by the run interval, not by session
///    running volume. Where rounding could push a stage over a cap, it rounds
///    down. In this domain the conservative direction is the correct one.
/// 2. **Volume keeps growing after the interval caps out.** Once the run
///    interval hits `maxRunIntervalSeconds`, further stages add repeats rather
///    than lengthening the interval, so progression continues without ever
///    breaching the clinician's ceiling on continuous running.
public enum LadderGenerator {

    public static func stages(for spec: PlanSpec) -> [PlanStage] {
        guard spec.stageCount > 0 else { return [] }
        return (0..<spec.stageCount).map { stage(spec: spec, index: $0) }
    }

    public static func stage(spec: PlanSpec, index: Int) -> PlanStage {
        let step = max(0, index)
        let growth = pow(1.0 + spec.runGrowthPerStage, Double(step))
        let decay = pow(1.0 - spec.walkDecayPerStage, Double(step))

        // Run interval: grow, then clamp to every cap that applies. A single
        // interval can never exceed the whole session's running allowance.
        var runSeconds = roundToStep(Double(spec.startRunSeconds) * growth, step: 5)
        if let cap = spec.maxRunIntervalSeconds {
            runSeconds = min(runSeconds, cap)
        }
        if let sessionCap = spec.maxSessionRunSeconds {
            runSeconds = min(runSeconds, sessionCap)
        }
        runSeconds = max(runSeconds, 5)

        // Walk recovery: shrink toward, but never below, the floor.
        var walkSeconds = roundToStep(Double(spec.startWalkSeconds) * decay, step: 5)
        walkSeconds = max(walkSeconds, spec.minWalkSeconds)

        // Target running volume grows at the same rate as the interval. Once
        // the interval is capped this is what keeps the ladder climbing.
        var targetVolume = Double(spec.startRepeats * spec.startRunSeconds) * growth
        if let sessionCap = spec.maxSessionRunSeconds {
            targetVolume = min(targetVolume, Double(sessionCap))
        }

        // Floor rather than round: rounding up here could breach the session
        // cap by up to half an interval.
        let repeats = max(1, Int(targetVolume / Double(runSeconds)))

        return PlanStage(
            index: step,
            warmupWalkSeconds: spec.warmupWalkSeconds,
            repeats: repeats,
            runSeconds: runSeconds,
            walkSeconds: walkSeconds,
            cooldownWalkSeconds: spec.cooldownWalkSeconds
        )
    }

    // MARK: Weekly load

    /// Total running across a week if this stage is run `sessionsPerWeek` times.
    public static func weeklyRunSeconds(stage: PlanStage, spec: PlanSpec) -> Int {
        stage.totalRunSeconds * max(0, spec.sessionsPerWeek)
    }

    /// Whether running this stage at the spec's weekly frequency would breach
    /// the weekly cap. The generator does not silently shrink stages to avoid
    /// this — it surfaces it, because the right fix is usually to drop a
    /// session that week, which is a decision for the runner and their physio.
    public static func exceedsWeeklyCap(stage: PlanStage, spec: PlanSpec) -> Bool {
        guard let capMinutes = spec.maxWeeklyRunMinutes else { return false }
        return weeklyRunSeconds(stage: stage, spec: spec) > capMinutes * 60
    }

    // MARK: Helpers

    /// Rounds to the nearest `step` seconds so cues land on times a person can
    /// actually hold in their head.
    static func roundToStep(_ value: Double, step: Int) -> Int {
        guard step > 0 else { return Int(value.rounded()) }
        return Int((value / Double(step)).rounded()) * step
    }
}
