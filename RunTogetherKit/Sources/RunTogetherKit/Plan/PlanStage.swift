import Foundation

/// One rung of a ladder: a complete prescription for a single session.
///
/// The structure is warmup walk, then `repeats` of (run, walk), then a cooldown
/// walk. The final repeat keeps its walk interval before the cooldown begins —
/// that makes the arithmetic uniform, and erring toward more walking at the end
/// of a session is the right direction to err in.
public struct PlanStage: Hashable, Sendable, Codable {
    public let index: Int
    public let warmupWalkSeconds: Int
    public let repeats: Int
    public let runSeconds: Int
    public let walkSeconds: Int
    public let cooldownWalkSeconds: Int

    public init(
        index: Int,
        warmupWalkSeconds: Int,
        repeats: Int,
        runSeconds: Int,
        walkSeconds: Int,
        cooldownWalkSeconds: Int
    ) {
        self.index = index
        self.warmupWalkSeconds = warmupWalkSeconds
        self.repeats = repeats
        self.runSeconds = runSeconds
        self.walkSeconds = walkSeconds
        self.cooldownWalkSeconds = cooldownWalkSeconds
    }

    /// Total time spent running. This is the number that matters for load.
    public var totalRunSeconds: Int {
        repeats * runSeconds
    }

    public var totalWalkSeconds: Int {
        warmupWalkSeconds + (repeats * walkSeconds) + cooldownWalkSeconds
    }

    public var totalSeconds: Int {
        totalRunSeconds + totalWalkSeconds
    }

    /// Short human-readable shape, e.g. "8 x (1:00 run / 2:00 walk)".
    public var summary: String {
        "\(repeats) x (\(Self.clock(runSeconds)) run / \(Self.clock(walkSeconds)) walk)"
    }

    private static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
