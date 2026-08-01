import Foundation
import Observation
import RunTogetherKit
import WatchConnectivity

/// Runs the session on the wrist.
///
/// The phone hands over the whole timeline once and then goes quiet. Everything
/// after that is computed locally from the shared `startedAt`, so a connection
/// that drops mid-run costs nothing — the next tick still resolves to the right
/// place in the session.
@MainActor
@Observable
final class WatchSessionModel {

    private(set) var handoff: SessionHandoff?
    private(set) var progress: SessionProgress?

    @ObservationIgnored private let haptics = HapticCueEngine()
    @ObservationIgnored private let receiver = WatchConnectivityReceiver()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var lastPlayedOffset: Int?
    @ObservationIgnored private var hasPlayedCompletion = false

    func activate() {
        receiver.onSession = { [weak self] handoff in
            Task { @MainActor in self?.begin(handoff) }
        }
        receiver.onStop = { [weak self] in
            Task { @MainActor in self?.end() }
        }
        receiver.activate()
    }

    // MARK: Session

    private func begin(_ handoff: SessionHandoff) {
        // A repeated context delivery for a session already running must not
        // restart it and re-fire its cues.
        guard handoff.sessionID != self.handoff?.sessionID else { return }

        self.handoff = handoff
        lastPlayedOffset = nil
        hasPlayedCompletion = false

        timer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        tick()
    }

    private func end() {
        timer?.invalidate()
        timer = nil
        handoff = nil
        progress = nil
    }

    private func tick() {
        guard let handoff else { return }

        let current = SessionProgressCalculator.progress(
            track: handoff.track,
            startedAt: handoff.startedAt,
            now: Date()
        )
        progress = current

        if let segment = current.current, segment.offsetSeconds != lastPlayedOffset {
            lastPlayedOffset = segment.offsetSeconds
            haptics.play(segment.haptic)
        }

        if current.isComplete && !hasPlayedCompletion {
            hasPlayedCompletion = true
            haptics.play(.sessionComplete)
            timer?.invalidate()
            timer = nil
        }
    }

    // MARK: Display

    var activityTitle: String {
        guard let progress else { return "Waiting" }
        if progress.isComplete { return "Done" }
        switch progress.current?.activity {
        case .run: return "RUN"
        case .walk: return "WALK"
        case nil: return "Ready"
        }
    }

    var countdown: String {
        guard let progress, progress.current != nil else { return "--:--" }
        let seconds = max(0, progress.remainingInSegmentSeconds)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    var isRunning: Bool {
        progress?.current?.activity == .run
    }
}

/// Thin `NSObject` shim, kept separate so the model itself need not inherit
/// from `NSObject`.
///
/// Explicitly `nonisolated` because the target defaults to `MainActor`
/// isolation and these delegate callbacks arrive on a background queue. The
/// handlers hop to the main actor themselves.
private nonisolated final class WatchConnectivityReceiver: NSObject, WCSessionDelegate {

    var onSession: (@Sendable (SessionHandoff) -> Void)?
    var onStop: (@Sendable () -> Void)?

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        // A session may already be waiting from before the app was opened.
        handle(session.receivedApplicationContext)
    }

    private func handle(_ payload: [String: Any]) {
        if payload["stop"] is String {
            onStop?()
            return
        }
        guard let data = payload["session"] as? Data,
              let handoff = try? JSONDecoder().decode(SessionHandoff.self, from: data)
        else { return }
        onSession?(handoff)
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handle(applicationContext)
    }
}
