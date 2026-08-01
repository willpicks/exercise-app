import Foundation

/// Stable identity for a runner. A plain string rather than a UUID so that the
/// two known runners can be referred to by constant in tests and in the app.
public struct RunnerID: Hashable, Sendable, Codable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

/// Why a runner is going slowly. This does not change the shape of the ladder —
/// both roles use the same generator — but it does change how the app talks
/// about progress, and which check-in it asks for after a run.
public enum RunnerRole: String, Hashable, Sendable, Codable {
    /// Returning from injury under a clinician's protocol.
    case recovering
    /// Building a base from low fitness.
    case building
}

public struct Runner: Identifiable, Hashable, Sendable, Codable {
    public let id: RunnerID
    public var displayName: String
    public var role: RunnerRole
    public var spec: PlanSpec
    /// Index into the generated ladder. Advancing this is always an explicit
    /// user action for protocol-governed runners — never a side effect.
    public var currentStageIndex: Int

    public init(
        id: RunnerID,
        displayName: String,
        role: RunnerRole,
        spec: PlanSpec,
        currentStageIndex: Int = 0
    ) {
        self.id = id
        self.displayName = displayName
        self.role = role
        self.spec = spec
        self.currentStageIndex = currentStageIndex
    }

    /// The full ladder for this runner.
    public var ladder: [PlanStage] {
        LadderGenerator.stages(for: spec)
    }

    /// The stage this runner is currently on, clamped into the ladder's range.
    public var currentStage: PlanStage {
        let all = ladder
        guard !all.isEmpty else {
            return LadderGenerator.stage(spec: spec, index: 0)
        }
        let clamped = min(max(currentStageIndex, 0), all.count - 1)
        return all[clamped]
    }
}
