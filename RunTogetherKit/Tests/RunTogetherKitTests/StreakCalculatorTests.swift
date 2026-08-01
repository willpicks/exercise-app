import XCTest
@testable import RunTogetherKit

final class StreakCalculatorTests: XCTestCase {

    private func day(_ offset: Int, _ kind: PlannedDayKind, didRun: Bool) -> PlannedDay {
        PlannedDay(
            date: Date(timeIntervalSince1970: Double(offset) * 86_400),
            kind: kind,
            didRun: didRun
        )
    }

    private func asOf(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: Double(offset) * 86_400)
    }

    func testRestDaysTakenExtendTheStreak() {
        // The whole point: resting when the plan says rest is adherence, and a
        // recovering runner must never be nudged to break it for a counter.
        let days = [
            day(0, .session, didRun: true),
            day(1, .rest, didRun: false),
            day(2, .session, didRun: true),
            day(3, .rest, didRun: false)
        ]

        let result = StreakCalculator.evaluate(days, asOf: asOf(3))

        XCTAssertEqual(result.current, 4)
        XCTAssertEqual(result.longest, 4)
        XCTAssertEqual(result.overshootDays, 0)
    }

    func testRunningOnARestDayBreaksTheStreakAndCountsAsOvershoot() {
        let days = [
            day(0, .session, didRun: true),
            day(1, .rest, didRun: true),
            day(2, .session, didRun: true)
        ]

        let result = StreakCalculator.evaluate(days, asOf: asOf(2))

        XCTAssertEqual(result.current, 1)
        XCTAssertEqual(result.longest, 1)
        XCTAssertEqual(result.overshootDays, 1)
    }

    func testMissingAPlannedSessionBreaksTheStreak() {
        let days = [
            day(0, .session, didRun: true),
            day(1, .rest, didRun: false),
            day(2, .session, didRun: false)
        ]

        let result = StreakCalculator.evaluate(days, asOf: asOf(2))

        XCTAssertEqual(result.current, 0)
        XCTAssertEqual(result.longest, 2)
    }

    func testFutureDaysAreIgnored() {
        // A rest day later in the week must not be counted as honoured before
        // it has actually happened.
        let days = [
            day(0, .session, didRun: true),
            day(1, .rest, didRun: false),
            day(5, .rest, didRun: false)
        ]

        let result = StreakCalculator.evaluate(days, asOf: asOf(1))

        XCTAssertEqual(result.current, 2)
    }

    func testUnorderedInputIsSortedBeforeEvaluation() {
        let days = [
            day(2, .session, didRun: true),
            day(0, .session, didRun: true),
            day(1, .rest, didRun: true)
        ]

        let result = StreakCalculator.evaluate(days, asOf: asOf(2))

        XCTAssertEqual(result.current, 1)
        XCTAssertEqual(result.overshootDays, 1)
    }

    func testEmptyHistory() {
        let result = StreakCalculator.evaluate([], asOf: asOf(0))

        XCTAssertEqual(result.current, 0)
        XCTAssertEqual(result.longest, 0)
        XCTAssertEqual(result.overshootDays, 0)
    }

    func testHonouredRules() {
        XCTAssertTrue(StreakCalculator.isHonoured(day(0, .session, didRun: true)))
        XCTAssertFalse(StreakCalculator.isHonoured(day(0, .session, didRun: false)))
        XCTAssertTrue(StreakCalculator.isHonoured(day(0, .rest, didRun: false)))
        XCTAssertFalse(StreakCalculator.isHonoured(day(0, .rest, didRun: true)))
    }
}
