import Foundation

public enum PlannedDayKind: String, Hashable, Sendable, Codable {
    case session
    case rest
}

public struct PlannedDay: Hashable, Sendable, Codable {
    /// Start of the calendar day this refers to.
    public let date: Date
    public let kind: PlannedDayKind
    public let didRun: Bool

    public init(date: Date, kind: PlannedDayKind, didRun: Bool) {
        self.date = date
        self.kind = kind
        self.didRun = didRun
    }
}

public struct StreakResult: Hashable, Sendable {
    public let current: Int
    public let longest: Int
    /// Rest days that were run anyway.
    public let overshootDays: Int

    public init(current: Int, longest: Int, overshootDays: Int) {
        self.current = current
        self.longest = longest
        self.overshootDays = overshootDays
    }
}

/// Adherence streak.
///
/// The inversion here is deliberate and is the reason this isn't a stock streak
/// counter. A conventional "consecutive days run" mechanic rewards exactly the
/// behaviour that a repaired meniscus cannot tolerate, and it would quietly
/// push a recovering runner to train on days their protocol prescribes off.
///
/// So a **rest day taken is a day honoured** — it extends the streak just as a
/// completed session does. Running on a prescribed rest day breaks the streak
/// and is counted as an overshoot, because that is what it is.
public enum StreakCalculator {

    public static func isHonoured(_ day: PlannedDay) -> Bool {
        switch day.kind {
        case .session: return day.didRun
        case .rest: return !day.didRun
        }
    }

    /// - Parameter asOf: days after this are ignored, so a rest day later in
    ///   the week is not counted as honoured before it has happened.
    public static func evaluate(_ days: [PlannedDay], asOf: Date) -> StreakResult {
        let elapsed = days
            .filter { $0.date <= asOf }
            .sorted { $0.date < $1.date }

        guard !elapsed.isEmpty else {
            return StreakResult(current: 0, longest: 0, overshootDays: 0)
        }

        var longest = 0
        var running = 0
        for day in elapsed {
            if isHonoured(day) {
                running += 1
                longest = max(longest, running)
            } else {
                running = 0
            }
        }

        var current = 0
        for day in elapsed.reversed() {
            guard isHonoured(day) else { break }
            current += 1
        }

        let overshoot = elapsed.filter { $0.kind == .rest && $0.didRun }.count

        return StreakResult(current: current, longest: longest, overshootDays: overshoot)
    }
}
