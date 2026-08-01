import Foundation
import RunTogetherKit
import WatchKit

/// Wrist cues.
///
/// Three patterns, because a person mid-interval on a road can reliably tell
/// apart about three things. Run is a double tap so it reads as "go, go";
/// walk is a single stop; the end is the success pattern, which is distinct
/// enough that nobody checks their wrist to confirm.
///
/// These are the first thing to tune after a real run — they are chosen from
/// what the system offers, not from what has been felt at effort.
@MainActor
final class HapticCueEngine {

    func play(_ cue: HapticCue) {
        let device = WKInterfaceDevice.current()
        switch cue {
        case .startRun:
            device.play(.start)
            // Second tap shortly after, so run never feels like walk.
            Task {
                try? await Task.sleep(for: .milliseconds(180))
                device.play(.start)
            }
        case .startWalk:
            device.play(.stop)
        case .sessionComplete:
            device.play(.success)
        }
    }
}
