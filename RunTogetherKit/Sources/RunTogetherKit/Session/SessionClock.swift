import Foundation

/// Abstracted so a thirty-minute session can be exercised in a millisecond.
public protocol SessionClock {
    var now: Date { get }
}

public struct SystemSessionClock: SessionClock {
    public init() {}
    public var now: Date { Date() }
}

/// Test clock. Advance it by hand; nothing sleeps.
public final class ManualSessionClock: SessionClock {
    private var current: Date

    public init(start: Date = Date(timeIntervalSince1970: 0)) {
        self.current = start
    }

    public var now: Date { current }

    public func advance(by seconds: TimeInterval) {
        current = current.addingTimeInterval(seconds)
    }

    public func set(_ date: Date) {
        current = date
    }
}

/// Where a runner is in a session right now.
public struct SessionProgress: Hashable, Sendable {
    public let elapsedSeconds: Int
    public let current: Segment?
    public let next: Segment?
    public let remainingInSegmentSeconds: Int
    public let isComplete: Bool
    public let isPending: Bool

    public init(
        elapsedSeconds: Int,
        current: Segment?,
        next: Segment?,
        remainingInSegmentSeconds: Int,
        isComplete: Bool,
        isPending: Bool
    ) {
        self.elapsedSeconds = elapsedSeconds
        self.current = current
        self.next = next
        self.remainingInSegmentSeconds = remainingInSegmentSeconds
        self.isComplete = isComplete
        self.isPending = isPending
    }
}

/// Resolves session position from an **absolute** start timestamp.
///
/// This is what makes two-device synchronisation trivial. The host writes the
/// session's `startedAt` as wall-clock time; both devices compute their
/// position from that same anchor. A device that receives the push eight
/// seconds late does not start eight seconds behind — it starts eight seconds
/// *in*, correctly aligned. Push latency therefore cannot accumulate as drift,
/// and nothing has to be streamed during the run.
public enum SessionProgressCalculator {

    public static func progress(
        track: CueTrack,
        startedAt: Date,
        now: Date
    ) -> SessionProgress {
        let rawElapsed = now.timeIntervalSince(startedAt)

        // A session scheduled to begin shortly is pending, not running.
        if rawElapsed < 0 {
            return SessionProgress(
                elapsedSeconds: Int(rawElapsed.rounded(.down)),
                current: nil,
                next: track.segments.first,
                remainingInSegmentSeconds: 0,
                isComplete: false,
                isPending: true
            )
        }

        let elapsed = Int(rawElapsed)
        guard elapsed < track.totalSeconds else {
            return SessionProgress(
                elapsedSeconds: elapsed,
                current: nil,
                next: nil,
                remainingInSegmentSeconds: 0,
                isComplete: true,
                isPending: false
            )
        }

        let current = track.segment(atElapsed: elapsed)
        let remaining = current.map { $0.endSeconds - elapsed } ?? 0

        return SessionProgress(
            elapsedSeconds: elapsed,
            current: current,
            next: track.segment(afterElapsed: elapsed),
            remainingInSegmentSeconds: remaining,
            isComplete: false,
            isPending: false
        )
    }

    public static func progress(
        track: CueTrack,
        startedAt: Date,
        clock: SessionClock
    ) -> SessionProgress {
        progress(track: track, startedAt: startedAt, now: clock.now)
    }
}
