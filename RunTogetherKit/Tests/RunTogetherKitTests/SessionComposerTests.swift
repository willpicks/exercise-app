import XCTest
@testable import RunTogetherKit

final class SessionComposerTests: XCTestCase {

    private func stage(
        index: Int = 0,
        repeats: Int,
        run: Int,
        walk: Int,
        warmup: Int = 0,
        cooldown: Int = 0
    ) -> PlanStage {
        PlanStage(
            index: index,
            warmupWalkSeconds: warmup,
            repeats: repeats,
            runSeconds: run,
            walkSeconds: walk,
            cooldownWalkSeconds: cooldown
        )
    }

    /// The case that rules out "pick whichever stage is gentler overall".
    ///
    /// 1 x 5:00 has less total running than 10 x 1:00, so an overall-gentler
    /// rule would select it — and hand the other runner a five-minute
    /// continuous interval when their own ladder says one minute.
    func testDoesNotHandOutAnIntervalLongerThanEitherRunnersOwn() {
        let manyShort = stage(repeats: 10, run: 60, walk: 60)
        let oneLong = stage(repeats: 1, run: 300, walk: 60)

        let composed = SessionComposer.compose(manyShort, oneLong)

        XCTAssertEqual(composed.runSeconds, 60, "must not exceed the shorter interval")
        XCTAssertLessThanOrEqual(composed.totalRunSeconds, 300)
    }

    func testNeverExceedsEitherStageOnAnyAxis() {
        // The core safety invariant, swept across two full realistic ladders
        // including the case where one runner is far ahead of the other.
        let physio = PlanSpec.physioProtocol(
            source: "Physio",
            recordedOn: Date(timeIntervalSince1970: 1_770_000_000)
        )
        let beginner = PlanSpec.beginner()

        let dadLadder = LadderGenerator.stages(for: physio)
        let mineLadder = LadderGenerator.stages(for: beginner)

        for dad in dadLadder {
            for mine in mineLadder {
                let composed = SessionComposer.compose(dad, mine)

                XCTAssertLessThanOrEqual(
                    composed.runSeconds, min(dad.runSeconds, mine.runSeconds),
                    "interval exceeded a runner's own at \(dad.index)/\(mine.index)"
                )
                XCTAssertLessThanOrEqual(
                    composed.totalRunSeconds,
                    min(dad.totalRunSeconds, mine.totalRunSeconds),
                    "volume exceeded a runner's own at \(dad.index)/\(mine.index)"
                )
                XCTAssertGreaterThanOrEqual(
                    composed.walkSeconds, max(dad.walkSeconds, mine.walkSeconds),
                    "recovery was shortened at \(dad.index)/\(mine.index)"
                )
                XCTAssertGreaterThanOrEqual(composed.repeats, 1)
            }
        }
    }

    func testIdenticalStagesComposeToThemselves() {
        // Early on the two ladders will be close, so this is the common path.
        let both = stage(repeats: 8, run: 60, walk: 120, warmup: 300, cooldown: 300)
        let composed = SessionComposer.compose(both, both)

        XCTAssertEqual(composed.runSeconds, both.runSeconds)
        XCTAssertEqual(composed.walkSeconds, both.walkSeconds)
        XCTAssertEqual(composed.repeats, both.repeats)
        XCTAssertEqual(composed.totalRunSeconds, both.totalRunSeconds)
    }

    func testTakesTheLongerRecoveryAndWarmup() {
        let a = stage(repeats: 6, run: 60, walk: 90, warmup: 180, cooldown: 120)
        let b = stage(repeats: 6, run: 60, walk: 150, warmup: 300, cooldown: 300)

        let composed = SessionComposer.compose(a, b)

        XCTAssertEqual(composed.walkSeconds, 150)
        XCTAssertEqual(composed.warmupWalkSeconds, 300)
        XCTAssertEqual(composed.cooldownWalkSeconds, 300)
    }

    func testPairedPlanIssuesAnIdenticalTrackToBothRunners() {
        let dad = Runner(
            id: RunnerID("dad"),
            displayName: "Dad",
            role: .recovering,
            spec: .physioProtocol(
                source: "Physio",
                recordedOn: Date(timeIntervalSince1970: 1_770_000_000)
            ),
            currentStageIndex: 2
        )
        let me = Runner(
            id: RunnerID("me"),
            displayName: "Me",
            role: .building,
            spec: .beginner(),
            currentStageIndex: 7
        )

        let plan = SessionComposer.pairedPlan(for: (dad, me))

        XCTAssertEqual(plan.tracks.count, 2)
        let dadTrack = plan.track(for: dad.id)
        let myTrack = plan.track(for: me.id)
        XCTAssertNotNil(dadTrack)
        XCTAssertNotNil(myTrack)

        // Same lane: the instructions differ only by whose track it is.
        XCTAssertEqual(dadTrack?.segments, myTrack?.segments)
    }

    func testSoloPlanUsesTheRunnersOwnStageUncomposed() {
        let me = Runner(
            id: RunnerID("me"),
            displayName: "Me",
            role: .building,
            spec: .beginner(),
            currentStageIndex: 7
        )

        let plan = SessionComposer.soloPlan(for: me)

        XCTAssertEqual(plan.tracks.count, 1)
        XCTAssertEqual(plan.stage, me.currentStage)
    }
}
