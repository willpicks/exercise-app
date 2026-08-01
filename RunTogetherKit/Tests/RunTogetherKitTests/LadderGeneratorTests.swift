import XCTest
@testable import RunTogetherKit

final class LadderGeneratorTests: XCTestCase {

    private let recordedOn = Date(timeIntervalSince1970: 1_770_000_000)

    func testStageZeroReproducesTheSpecExactly() {
        // Whatever the physio wrote down must come back out unchanged at the
        // first rung. If this drifts, the app is quietly editing a prescription.
        let spec = PlanSpec.physioProtocol(
            source: "Physio",
            recordedOn: recordedOn,
            startRunSeconds: 60,
            startWalkSeconds: 120,
            startRepeats: 6
        )
        let stage = LadderGenerator.stage(spec: spec, index: 0)

        XCTAssertEqual(stage.runSeconds, 60)
        XCTAssertEqual(stage.walkSeconds, 120)
        XCTAssertEqual(stage.repeats, 6)
        XCTAssertEqual(stage.totalRunSeconds, 360)
    }

    func testRunIntervalNeverExceedsTheCap() {
        let spec = PlanSpec(
            governance: .physioProtocol(source: "Physio", recordedOn: recordedOn),
            startRunSeconds: 60,
            startWalkSeconds: 120,
            startRepeats: 4,
            stageCount: 24,
            runGrowthPerStage: 0.15,
            maxRunIntervalSeconds: 120,
            maxSessionRunSeconds: 1_800
        )

        for stage in LadderGenerator.stages(for: spec) {
            XCTAssertLessThanOrEqual(
                stage.runSeconds, 120,
                "stage \(stage.index) breached the continuous-run cap"
            )
        }
    }

    func testSessionVolumeNeverExceedsTheCap() {
        // Rounding must not be able to push a stage over the ceiling, which is
        // why the generator floors the repeat count.
        let spec = PlanSpec(
            governance: .physioProtocol(source: "Physio", recordedOn: recordedOn),
            startRunSeconds: 70,
            startWalkSeconds: 120,
            startRepeats: 5,
            stageCount: 30,
            runGrowthPerStage: 0.13,
            maxRunIntervalSeconds: 300,
            maxSessionRunSeconds: 900
        )

        for stage in LadderGenerator.stages(for: spec) {
            XCTAssertLessThanOrEqual(
                stage.totalRunSeconds, 900,
                "stage \(stage.index) breached the session volume cap"
            )
        }
    }

    func testVolumeKeepsGrowingOnceTheIntervalIsCapped() {
        // The property that makes a capped ladder still a ladder: when the
        // interval can no longer lengthen, progression continues via repeats.
        let spec = PlanSpec(
            governance: .physioProtocol(source: "Physio", recordedOn: recordedOn),
            startRunSeconds: 60,
            startWalkSeconds: 120,
            startRepeats: 4,
            stageCount: 20,
            runGrowthPerStage: 0.10,
            maxRunIntervalSeconds: 90,
            maxSessionRunSeconds: 1_800
        )
        let stages = LadderGenerator.stages(for: spec)

        let capped = stages.filter { $0.runSeconds == 90 }
        XCTAssertGreaterThan(capped.count, 1, "expected the interval cap to bind")

        guard let firstCapped = capped.first, let lastCapped = capped.last else {
            return XCTFail("no capped stages generated")
        }
        XCTAssertGreaterThan(
            lastCapped.repeats, firstCapped.repeats,
            "repeats should climb once the interval is pinned"
        )
        XCTAssertGreaterThan(
            stages[stages.count - 1].totalRunSeconds, stages[0].totalRunSeconds
        )
    }

    func testWalkRecoveryNeverDropsBelowTheFloor() {
        let spec = PlanSpec(
            governance: .selfDirected,
            startRunSeconds: 60,
            startWalkSeconds: 120,
            startRepeats: 6,
            stageCount: 40,
            walkDecayPerStage: 0.20,
            minWalkSeconds: 45
        )

        for stage in LadderGenerator.stages(for: spec) {
            XCTAssertGreaterThanOrEqual(stage.walkSeconds, 45)
        }
    }

    func testUncappedLadderStillGrows() {
        let spec = PlanSpec.beginner()
        let stages = LadderGenerator.stages(for: spec)

        XCTAssertEqual(stages.count, spec.stageCount)
        XCTAssertGreaterThan(
            stages[stages.count - 1].runSeconds, stages[0].runSeconds
        )
    }

    func testWeeklyCapDetection() {
        var spec = PlanSpec.physioProtocol(
            source: "Physio",
            recordedOn: recordedOn,
            maxWeeklyRunMinutes: 30
        )
        spec.sessionsPerWeek = 3

        // 6 x 60s = 360s per session, three times a week = 1080s = 18 min.
        let early = LadderGenerator.stage(spec: spec, index: 0)
        XCTAssertEqual(LadderGenerator.weeklyRunSeconds(stage: early, spec: spec), 1_080)
        XCTAssertFalse(LadderGenerator.exceedsWeeklyCap(stage: early, spec: spec))

        let later = LadderGenerator.stage(spec: spec, index: 10)
        XCTAssertTrue(
            LadderGenerator.exceedsWeeklyCap(stage: later, spec: spec),
            "a much later stage at 3x/week should breach a 30 min weekly cap"
        )
    }

    func testEmptyLadderWhenStageCountIsZero() {
        var spec = PlanSpec.beginner()
        spec.stageCount = 0
        XCTAssertTrue(LadderGenerator.stages(for: spec).isEmpty)
    }

    func testRoundingSnapsToFiveSeconds() {
        XCTAssertEqual(LadderGenerator.roundToStep(62.0, step: 5), 60)
        XCTAssertEqual(LadderGenerator.roundToStep(63.0, step: 5), 65)
        XCTAssertEqual(LadderGenerator.roundToStep(0.0, step: 5), 0)
    }
}
