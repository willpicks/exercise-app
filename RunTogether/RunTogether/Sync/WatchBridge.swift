import Foundation
import RunTogetherKit
import WatchConnectivity

/// Sends a starting session to the Watch, once.
///
/// Two delivery routes, deliberately both: `sendMessage` for immediacy when the
/// Watch is reachable, and `updateApplicationContext` so a Watch that is asleep
/// or out of range still finds the session waiting when it wakes. Application
/// context is latest-value-wins, which is exactly right here — a stale session
/// is never worth delivering.
@MainActor
final class WatchBridge: NSObject {

    static let shared = WatchBridge()

    private override init() {
        super.init()
        activate()
    }

    private func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func send(_ handoff: SessionHandoff) {
        guard let data = try? JSONEncoder().encode(handoff) else { return }
        deliver(["session": data])
    }

    func sendStop(sessionID: UUID) {
        deliver(["stop": sessionID.uuidString])
    }

    private func deliver(_ payload: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { _ in
                // Delivery is best-effort; application context below is the
                // fallback and needs no error handling here.
            }
        }
        try? session.updateApplicationContext(payload)
    }
}

extension WatchBridge: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate so the bridge survives the user switching watches.
        WCSession.default.activate()
    }
}
