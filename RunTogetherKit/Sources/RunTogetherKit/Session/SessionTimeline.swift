import Foundation

/// Expands a `PlanStage` into a contiguous list of timed cues.
public enum SessionTimeline {

    public static func track(for stage: PlanStage, runnerID: RunnerID) -> CueTrack {
        CueTrack(runnerID: runnerID, segments: segments(for: stage))
    }

    public static func segments(for stage: PlanStage) -> [Segment] {
        var result: [Segment] = []
        var offset = 0

        if stage.warmupWalkSeconds > 0 {
            result.append(
                Segment(
                    offsetSeconds: offset,
                    durationSeconds: stage.warmupWalkSeconds,
                    activity: .walk,
                    spokenCue: "Warm up. Walk for \(DurationPhrase.spoken(stage.warmupWalkSeconds)).",
                    haptic: .startWalk
                )
            )
            offset += stage.warmupWalkSeconds
        }

        for repetition in 0..<max(0, stage.repeats) {
            let remaining = stage.repeats - repetition - 1

            result.append(
                Segment(
                    offsetSeconds: offset,
                    durationSeconds: stage.runSeconds,
                    activity: .run,
                    spokenCue: "Run for \(DurationPhrase.spoken(stage.runSeconds)).",
                    haptic: .startRun
                )
            )
            offset += stage.runSeconds

            let walkCue: String
            if remaining == 0 {
                walkCue = "Walk for \(DurationPhrase.spoken(stage.walkSeconds)). Last one done."
            } else {
                walkCue = "Walk for \(DurationPhrase.spoken(stage.walkSeconds)). "
                    + "\(remaining) to go."
            }
            result.append(
                Segment(
                    offsetSeconds: offset,
                    durationSeconds: stage.walkSeconds,
                    activity: .walk,
                    spokenCue: walkCue,
                    haptic: .startWalk
                )
            )
            offset += stage.walkSeconds
        }

        if stage.cooldownWalkSeconds > 0 {
            result.append(
                Segment(
                    offsetSeconds: offset,
                    durationSeconds: stage.cooldownWalkSeconds,
                    activity: .walk,
                    spokenCue: "Cool down. Walk for \(DurationPhrase.spoken(stage.cooldownWalkSeconds)).",
                    haptic: .sessionComplete
                )
            )
        }

        return result
    }
}
