import XCTest
@testable import RunTogetherKit

final class SessionTimelineTests: XCTestCase {

    private let stage = PlanStage(
        index: 0,
        warmupWalkSeconds: 300,
        repeats: 8,
        runSeconds: 60,
        walkSeconds: 120,
        cooldownWalkSeconds: 300
    )

    private var track: CueTrack {
        SessionTimeline.track(for: stage, runnerID: RunnerID("dad"))
    }

    func testSegmentsAreContiguousWithNoGapsOrOverlaps() {
        let segments = track.segments
        XCTAssertFalse(segments.isEmpty)

        for index in 1..<segments.count {
            XCTAssertEqual(
                segments[index - 1].endSeconds,
                segments[index].offsetSeconds,
                "gap or overlap before segment \(index)"
            )
        }
    }

    func testTotalDurationMatchesTheStage() {
        XCTAssertEqual(track.totalSeconds, stage.totalSeconds)
        XCTAssertEqual(track.totalSeconds, 300 + 8 * 180 + 300)
    }

    func testRunSegmentCountMatchesRepeats() {
        let runs = track.segments.filter { $0.activity == .run }
        XCTAssertEqual(runs.count, stage.repeats)
        XCTAssertTrue(runs.allSatisfy { $0.durationSeconds == 60 })
    }

    func testStartsWithWarmupAndEndsWithCooldown() {
        XCTAssertEqual(track.segments.first?.activity, .walk)
        XCTAssertEqual(track.segments.first?.durationSeconds, 300)
        XCTAssertEqual(track.segments.last?.haptic, .sessionComplete)
    }

    func testOmitsWarmupAndCooldownWhenZero() {
        let bare = PlanStage(
            index: 0,
            warmupWalkSeconds: 0,
            repeats: 3,
            runSeconds: 60,
            walkSeconds: 60,
            cooldownWalkSeconds: 0
        )
        let segments = SessionTimeline.segments(for: bare)

        XCTAssertEqual(segments.first?.activity, .run)
        XCTAssertEqual(segments.count, 6)
    }

    func testDurationPhrasing() {
        XCTAssertEqual(DurationPhrase.spoken(45), "45 seconds")
        XCTAssertEqual(DurationPhrase.spoken(60), "1 minute")
        XCTAssertEqual(DurationPhrase.spoken(120), "2 minutes")
        XCTAssertEqual(DurationPhrase.spoken(90), "1 minute 30 seconds")
        XCTAssertEqual(DurationPhrase.spoken(61), "1 minute 1 second")
    }

    // MARK: Absolute-anchor synchronisation

    func testLateJoinerLandsMidTrackRatherThanAtTheStart() {
        // The property the two-device sync design rests on. A phone that gets
        // the push 305 seconds late must resolve to 5 seconds into the first
        // run interval — not to the top of the session.
        let startedAt = Date(timeIntervalSince1970: 1_000_000)
        let progress = SessionProgressCalculator.progress(
            track: track,
            startedAt: startedAt,
            now: startedAt.addingTimeInterval(305)
        )

        XCTAssertEqual(progress.elapsedSeconds, 305)
        XCTAssertEqual(progress.current?.activity, .run)
        XCTAssertEqual(progress.remainingInSegmentSeconds, 55)
        XCTAssertFalse(progress.isPending)
        XCTAssertFalse(progress.isComplete)
    }

    func testProgressDuringWarmup() {
        let startedAt = Date(timeIntervalSince1970: 1_000_000)
        let progress = SessionProgressCalculator.progress(
            track: track,
            startedAt: startedAt,
            now: startedAt.addingTimeInterval(8)
        )

        XCTAssertEqual(progress.current?.activity, .walk)
        XCTAssertEqual(progress.remainingInSegmentSeconds, 292)
        XCTAssertEqual(progress.next?.activity, .run)
    }

    func testSessionScheduledInTheFutureIsPending() {
        let startedAt = Date(timeIntervalSince1970: 1_000_000)
        let progress = SessionProgressCalculator.progress(
            track: track,
            startedAt: startedAt,
            now: startedAt.addingTimeInterval(-5)
        )

        XCTAssertTrue(progress.isPending)
        XCTAssertNil(progress.current)
        XCTAssertEqual(progress.next, track.segments.first)
    }

    func testSessionPastItsEndIsComplete() {
        let startedAt = Date(timeIntervalSince1970: 1_000_000)
        let progress = SessionProgressCalculator.progress(
            track: track,
            startedAt: startedAt,
            now: startedAt.addingTimeInterval(Double(track.totalSeconds))
        )

        XCTAssertTrue(progress.isComplete)
        XCTAssertNil(progress.current)
    }

    func testWholeSessionWalkedThroughWithAManualClock() {
        // A 34-minute session exercised end to end without sleeping.
        let startedAt = Date(timeIntervalSince1970: 1_000_000)
        let clock = ManualSessionClock(start: startedAt)
        var observed: [Activity] = []
        var lastSegment: Segment?

        for _ in 0...track.totalSeconds {
            let progress = SessionProgressCalculator.progress(
                track: track, startedAt: startedAt, clock: clock
            )
            if let current = progress.current, current != lastSegment {
                observed.append(current.activity)
                lastSegment = current
            }
            clock.advance(by: 1)
        }

        XCTAssertEqual(observed.first, .walk)
        XCTAssertEqual(observed.filter { $0 == .run }.count, stage.repeats)
        XCTAssertEqual(observed.count, track.segments.count)
    }
}
