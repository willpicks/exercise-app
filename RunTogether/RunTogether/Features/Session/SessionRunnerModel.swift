import Foundation
import Observation
import RunTogetherKit

/// Drives a live session.
///
/// All position comes from `SessionProgressCalculator` against an absolute
/// `startedAt`, never from an accumulating counter. That means a dropped timer
/// tick, a backgrounded app, or a phone that locks mid-interval all resolve
/// correctly the moment the next tick lands — and it is the same code path the
/// two-device sync will use in Phase 5, where the anchor arrives over CloudKit
/// instead of being created locally.
@MainActor
@Observable
final class SessionRunnerModel {

    let stage: PlanStage
    let track: CueTrack

    private(set) var progress: SessionProgress?
    private(set) var isRunning = false

    /// Debug acceleration. At 60 a 34-minute session plays out in 34 seconds,
    /// which is how the cue sequence gets checked without going outside.
    private let speedMultiplier: Double

    @ObservationIgnored private let cues = SpokenCueEngine()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var anchor: Date?
    @ObservationIgnored private var wallClockStart: Date?
    @ObservationIgnored private var lastSpokenOffset: Int?
    @ObservationIgnored private var hasAnnouncedCompletion = false

    init(plan: PairedPlan, runnerID: RunnerID, speedMultiplier: Double = 1) {
        self.stage = plan.stage
        self.track = plan.track(for: runnerID)
            ?? CueTrack(runnerID: runnerID, segments: SessionTimeline.segments(for: plan.stage))
        self.speedMultiplier = max(1, speedMultiplier)
    }

    // MARK: Lifecycle

    func start() {
        guard !isRunning else { return }
        let now = Date()
        anchor = now
        wallClockStart = now
        lastSpokenOffset = nil
        hasAnnouncedCompletion = false
        isRunning = true

        cues.activate()

        // Fine enough that accelerated runs don't skip past whole segments.
        let interval = min(0.25, 1.0 / speedMultiplier)
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        cues.deactivate()
    }

    // MARK: Tick

    private func tick() {
        guard let anchor, let wallClockStart else { return }

        let realElapsed = Date().timeIntervalSince(wallClockStart)
        let virtualNow = anchor.addingTimeInterval(realElapsed * speedMultiplier)

        let current = SessionProgressCalculator.progress(
            track: track,
            startedAt: anchor,
            now: virtualNow
        )
        progress = current

        if let segment = current.current, segment.offsetSeconds != lastSpokenOffset {
            lastSpokenOffset = segment.offsetSeconds
            cues.speak(segment.spokenCue)
        }

        if current.isComplete && !hasAnnouncedCompletion {
            hasAnnouncedCompletion = true
            cues.speak("Session complete. Well done.")
            timer?.invalidate()
            timer = nil
            isRunning = false
            // Audio session is left active briefly so the final cue finishes.
        }
    }

    // MARK: Display helpers

    var currentActivityTitle: String {
        guard let progress else { return "Ready" }
        if progress.isComplete { return "Done" }
        if progress.isPending { return "Starting" }
        switch progress.current?.activity {
        case .run: return "Run"
        case .walk: return "Walk"
        case nil: return "Ready"
        }
    }

    var countdownText: String {
        guard let progress, progress.current != nil else { return "--:--" }
        return Self.clock(progress.remainingInSegmentSeconds)
    }

    var nextUpText: String? {
        guard let next = progress?.next else { return nil }
        return "\(next.activity == .run ? "Run" : "Walk") \(Self.clock(next.durationSeconds))"
    }

    var elapsedText: String {
        Self.clock(max(0, progress?.elapsedSeconds ?? 0))
    }

    var totalText: String {
        Self.clock(track.totalSeconds)
    }

    /// 0...1 through the whole session.
    var fractionComplete: Double {
        guard track.totalSeconds > 0, let progress else { return 0 }
        if progress.isComplete { return 1 }
        return min(1, max(0, Double(progress.elapsedSeconds) / Double(track.totalSeconds)))
    }

    static func clock(_ seconds: Int) -> String {
        let safe = max(0, seconds)
        return String(format: "%d:%02d", safe / 60, safe % 60)
    }
}
