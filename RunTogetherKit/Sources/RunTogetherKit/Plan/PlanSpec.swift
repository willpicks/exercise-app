import Foundation

/// The parameters a ladder is generated from.
///
/// For a protocol-governed runner every field here should be transcribed from
/// what the clinician actually wrote down. The generator will not exceed the
/// caps, so if a cap is unknown it is safer to set it low and raise it later
/// than to leave it `nil`.
public struct PlanSpec: Hashable, Sendable, Codable {
    public var governance: Governance

    // MARK: Stage 0 shape

    /// Length of a single continuous run interval at stage 0.
    public var startRunSeconds: Int
    /// Length of the walking recovery between run intervals at stage 0.
    public var startWalkSeconds: Int
    /// Number of run/walk repeats at stage 0.
    public var startRepeats: Int
    public var warmupWalkSeconds: Int
    public var cooldownWalkSeconds: Int

    // MARK: Progression

    /// How many rungs to generate.
    public var stageCount: Int
    /// Fractional growth of the run interval per stage. `0.10` is +10%.
    public var runGrowthPerStage: Double
    /// Fractional shrink of the walk interval per stage. `0.05` is -5%.
    public var walkDecayPerStage: Double
    /// Walk recovery never drops below this, regardless of decay.
    public var minWalkSeconds: Int

    // MARK: Caps — `nil` means uncapped

    /// Longest single continuous run interval this runner may ever do.
    public var maxRunIntervalSeconds: Int?
    /// Most total running (excluding walk) in one session.
    public var maxSessionRunSeconds: Int?
    /// Most total running across a week. Not used to shape stages — used to
    /// warn when `sessionsPerWeek` at the current stage would breach it.
    public var maxWeeklyRunMinutes: Int?

    // MARK: Scheduling

    public var sessionsPerWeek: Int
    public var minRestDaysBetweenRuns: Int

    // MARK: Symptoms

    /// Pain rating (0...10) at or above which the app proposes repeating or
    /// dropping back a stage instead of advancing.
    public var painCeiling: Int?

    public init(
        governance: Governance,
        startRunSeconds: Int,
        startWalkSeconds: Int,
        startRepeats: Int,
        warmupWalkSeconds: Int = 300,
        cooldownWalkSeconds: Int = 300,
        stageCount: Int = 12,
        runGrowthPerStage: Double = 0.10,
        walkDecayPerStage: Double = 0.05,
        minWalkSeconds: Int = 30,
        maxRunIntervalSeconds: Int? = nil,
        maxSessionRunSeconds: Int? = nil,
        maxWeeklyRunMinutes: Int? = nil,
        sessionsPerWeek: Int = 3,
        minRestDaysBetweenRuns: Int = 1,
        painCeiling: Int? = nil
    ) {
        self.governance = governance
        self.startRunSeconds = startRunSeconds
        self.startWalkSeconds = startWalkSeconds
        self.startRepeats = startRepeats
        self.warmupWalkSeconds = warmupWalkSeconds
        self.cooldownWalkSeconds = cooldownWalkSeconds
        self.stageCount = stageCount
        self.runGrowthPerStage = runGrowthPerStage
        self.walkDecayPerStage = walkDecayPerStage
        self.minWalkSeconds = minWalkSeconds
        self.maxRunIntervalSeconds = maxRunIntervalSeconds
        self.maxSessionRunSeconds = maxSessionRunSeconds
        self.maxWeeklyRunMinutes = maxWeeklyRunMinutes
        self.sessionsPerWeek = sessionsPerWeek
        self.minRestDaysBetweenRuns = minRestDaysBetweenRuns
        self.painCeiling = painCeiling
    }
}

public extension PlanSpec {
    /// A conservative starting point for a knee rehab return-to-run, to be
    /// overwritten field by field with the clinician's actual numbers. The
    /// defaults here are deliberately cautious: short intervals, long recovery,
    /// hard caps set rather than left open.
    static func physioProtocol(
        source: String,
        recordedOn: Date,
        startRunSeconds: Int = 60,
        startWalkSeconds: Int = 120,
        startRepeats: Int = 6,
        maxRunIntervalSeconds: Int? = 600,
        maxSessionRunSeconds: Int? = 1_800,
        maxWeeklyRunMinutes: Int? = 90,
        sessionsPerWeek: Int = 3,
        minRestDaysBetweenRuns: Int = 1,
        painCeiling: Int? = 3
    ) -> PlanSpec {
        PlanSpec(
            governance: .physioProtocol(source: source, recordedOn: recordedOn),
            startRunSeconds: startRunSeconds,
            startWalkSeconds: startWalkSeconds,
            startRepeats: startRepeats,
            runGrowthPerStage: 0.10,
            walkDecayPerStage: 0.05,
            minWalkSeconds: 60,
            maxRunIntervalSeconds: maxRunIntervalSeconds,
            maxSessionRunSeconds: maxSessionRunSeconds,
            maxWeeklyRunMinutes: maxWeeklyRunMinutes,
            sessionsPerWeek: sessionsPerWeek,
            minRestDaysBetweenRuns: minRestDaysBetweenRuns,
            painCeiling: painCeiling
        )
    }

    /// An ordinary beginner walk/run build for someone starting from low
    /// fitness with no injury constraint.
    static func beginner(
        startRunSeconds: Int = 60,
        startWalkSeconds: Int = 90,
        startRepeats: Int = 8,
        sessionsPerWeek: Int = 3
    ) -> PlanSpec {
        PlanSpec(
            governance: .selfDirected,
            startRunSeconds: startRunSeconds,
            startWalkSeconds: startWalkSeconds,
            startRepeats: startRepeats,
            stageCount: 16,
            runGrowthPerStage: 0.15,
            walkDecayPerStage: 0.08,
            minWalkSeconds: 30,
            maxRunIntervalSeconds: nil,
            maxSessionRunSeconds: 2_400,
            maxWeeklyRunMinutes: nil,
            sessionsPerWeek: sessionsPerWeek,
            minRestDaysBetweenRuns: 1,
            painCeiling: nil
        )
    }
}
