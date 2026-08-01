import XCTest
@testable import RunTogetherKit

final class WorkoutMatcherTests: XCTestCase {

    private let epoch = Date(timeIntervalSince1970: 1_770_000_000)

    private let stage = PlanStage(
        index: 0,
        warmupWalkSeconds: 300,
        repeats: 8,
        runSeconds: 60,
        walkSeconds: 120,
        cooldownWalkSeconds: 300
    )

    /// 2040 seconds long.
    private func session(offset: TimeInterval = 0, duration: TimeInterval? = nil) -> SessionRecord {
        let start = epoch.addingTimeInterval(offset)
        return SessionRecord(
            kind: .solo,
            stage: stage,
            participantIDs: [RunnerID("me")],
            startedAt: start,
            endedAt: duration.map { start.addingTimeInterval($0) },
            ranToCompletion: true
        )
    }

    private func workout(
        _ id: String,
        offset: TimeInterval,
        duration: TimeInterval
    ) -> WorkoutCandidate {
        WorkoutCandidate(
            id: id,
            startedAt: epoch.addingTimeInterval(offset),
            endedAt: epoch.addingTimeInterval(offset + duration)
        )
    }

    func testIdenticalWindowsScorePerfectly() {
        let score = WorkoutMatcher.overlapScore(
            session: session(duration: 2_040),
            workout: workout("a", offset: 0, duration: 2_040)
        )
        XCTAssertEqual(score, 1.0, accuracy: 0.001)
    }

    func testWatchStartedSlightlyLateStillMatches() {
        // The common real case: you tap the app, then fumble the watch.
        let score = WorkoutMatcher.overlapScore(
            session: session(duration: 2_040),
            workout: workout("a", offset: 20, duration: 2_040)
        )
        XCTAssertGreaterThan(score, WorkoutMatcher.defaultMinimumOverlap)
    }

    func testWorkoutTwiceAsLongIsRejected() {
        // Would score a perfect 1.0 under an asymmetric rule, and be wrong.
        let score = WorkoutMatcher.overlapScore(
            session: session(duration: 2_040),
            workout: workout("a", offset: 0, duration: 4_080)
        )
        XCTAssertEqual(score, 0.5, accuracy: 0.001)
        XCTAssertNil(
            WorkoutMatcher.bestMatch(
                for: session(duration: 2_040),
                among: [workout("a", offset: 0, duration: 4_080)]
            )
        )
    }

    func testWorkoutStartingHalfwayThroughIsRejected() {
        let score = WorkoutMatcher.overlapScore(
            session: session(duration: 2_040),
            workout: workout("a", offset: 1_020, duration: 2_040)
        )
        XCTAssertEqual(score, 1.0 / 3.0, accuracy: 0.01)
    }

    func testNoOverlapScoresZero() {
        let score = WorkoutMatcher.overlapScore(
            session: session(duration: 2_040),
            workout: workout("a", offset: 10_000, duration: 2_040)
        )
        XCTAssertEqual(score, 0)
    }

    func testBestMatchPicksTheClosestCandidate() {
        let candidates = [
            workout("loose", offset: 400, duration: 2_040),
            workout("tight", offset: 15, duration: 2_030),
            workout("elsewhere", offset: 50_000, duration: 2_040)
        ]

        let match = WorkoutMatcher.bestMatch(for: session(duration: 2_040), among: candidates)

        XCTAssertEqual(match?.id, "tight")
    }

    func testUnrecordedSessionMatchesNothing() {
        // Correct outcome for a run nobody recorded — better than guessing.
        XCTAssertNil(
            WorkoutMatcher.bestMatch(for: session(duration: 2_040), among: [])
        )
    }

    func testInProgressSessionFallsBackToPlannedLength() {
        // endedAt is nil, so the window comes from the stage: 2040 seconds.
        let live = session(duration: nil)
        XCTAssertEqual(live.window.duration, 2_040, accuracy: 0.001)
    }

    func testOneWorkoutIsNeverClaimedByTwoSessions() {
        // Two sessions overlapping one recording: the better fit wins and the
        // other is left unmatched rather than both pointing at the same run.
        let first = session(offset: 0, duration: 2_040)
        let second = session(offset: 60, duration: 2_040)
        let only = workout("single", offset: 55, duration: 2_040)

        let matches = WorkoutMatcher.matchAll(
            sessions: [first, second],
            candidates: [only]
        )

        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[second.id]?.id, "single")
        XCTAssertNil(matches[first.id])
    }

    func testBatchMatchingPairsEachSessionWithItsOwnWorkout() {
        let morning = session(offset: 0, duration: 2_040)
        let evening = session(offset: 40_000, duration: 2_040)
        let candidates = [
            workout("evening-run", offset: 40_010, duration: 2_030),
            workout("morning-run", offset: 10, duration: 2_030)
        ]

        let matches = WorkoutMatcher.matchAll(
            sessions: [morning, evening],
            candidates: candidates
        )

        XCTAssertEqual(matches[morning.id]?.id, "morning-run")
        XCTAssertEqual(matches[evening.id]?.id, "evening-run")
    }
}
