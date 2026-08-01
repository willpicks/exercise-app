import Foundation

/// A recorded workout reduced to the only thing matching needs: its window.
/// Kept free of HealthKit so the matching rule stays testable.
public struct WorkoutCandidate: Identifiable, Hashable, Sendable {
    /// The `HKWorkout` UUID string.
    public let id: String
    public let startedAt: Date
    public let endedAt: Date

    public init(id: String, startedAt: Date, endedAt: Date) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    public var interval: DateInterval {
        DateInterval(start: startedAt, end: max(endedAt, startedAt))
    }
}

/// Decides which recorded workout belongs to which session.
///
/// Scored by intersection over union rather than by how much of the session the
/// workout covers. The asymmetric version looks reasonable and misbehaves: a
/// workout that ran all afternoon fully contains a twenty-minute session and
/// would score a perfect 1.0. Intersection over union penalises a candidate for
/// being too long just as much as for being too short, so only a workout that
/// genuinely lines up scores well.
///
/// Worked examples against a one-hour session, at the default threshold:
///
/// - workout offset by five minutes → 0.85, matched
/// - workout twice as long          → 0.50, rejected
/// - workout starting halfway       → 0.33, rejected
public enum WorkoutMatcher {

    public static let defaultMinimumOverlap = 0.6

    /// 0 when the two do not overlap at all, 1 when they coincide exactly.
    public static func overlapScore(session: SessionRecord, workout: WorkoutCandidate) -> Double {
        score(session.window, workout.interval)
    }

    public static func score(_ a: DateInterval, _ b: DateInterval) -> Double {
        guard let intersection = a.intersection(with: b) else { return 0 }
        let union = max(a.end, b.end).timeIntervalSince(min(a.start, b.start))
        guard union > 0 else { return 0 }
        return intersection.duration / union
    }

    /// The best-scoring candidate above the threshold, or nil when nothing
    /// lines up well enough. Returning nil is the correct outcome for a run
    /// that was never recorded — the app offers manual attachment instead of
    /// guessing.
    public static func bestMatch(
        for session: SessionRecord,
        among candidates: [WorkoutCandidate],
        minimumOverlap: Double = defaultMinimumOverlap
    ) -> WorkoutCandidate? {
        candidates
            .map { ($0, overlapScore(session: session, workout: $0)) }
            .filter { $0.1 >= minimumOverlap }
            .max { $0.1 < $1.1 }?
            .0
    }

    /// Matches a batch, never handing the same workout to two sessions.
    /// Sessions are considered strongest-match-first so a clear winner claims
    /// its workout before a weaker overlap can take it.
    public static func matchAll(
        sessions: [SessionRecord],
        candidates: [WorkoutCandidate],
        minimumOverlap: Double = defaultMinimumOverlap
    ) -> [UUID: WorkoutCandidate] {
        var pairs: [(session: SessionRecord, candidate: WorkoutCandidate, score: Double)] = []
        for session in sessions {
            for candidate in candidates {
                let score = overlapScore(session: session, workout: candidate)
                if score >= minimumOverlap {
                    pairs.append((session, candidate, score))
                }
            }
        }

        pairs.sort { $0.score > $1.score }

        var result: [UUID: WorkoutCandidate] = [:]
        var claimed: Set<String> = []
        for pair in pairs {
            guard result[pair.session.id] == nil, !claimed.contains(pair.candidate.id) else { continue }
            result[pair.session.id] = pair.candidate
            claimed.insert(pair.candidate.id)
        }
        return result
    }
}
