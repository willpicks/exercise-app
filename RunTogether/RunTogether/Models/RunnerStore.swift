import Foundation
import Observation
import RunTogetherKit

/// Holds the two runners and their plans.
///
/// Deliberately backed by `UserDefaults` rather than SwiftData. There are two
/// records and they change a few times a month; a persistence stack would be
/// scaffolding around nothing. SwiftData arrives in Phase 5 when CloudKit sync
/// gives it a reason to exist.
@Observable
final class RunnerStore {

    private static let storageKey = "runners.v1"

    var dad: Runner
    var me: Runner

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(Persisted.self, from: data) {
            self.dad = saved.dad
            self.me = saved.me
        } else {
            self.dad = Self.defaultDad
            self.me = Self.defaultMe
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    func save() {
        guard let data = try? JSONEncoder().encode(Persisted(dad: dad, me: me)) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    /// Advance a runner one rung, clamped to the end of their ladder.
    ///
    /// Nothing calls this automatically. For a protocol-governed runner that is
    /// the point — the app proposes, a person confirms.
    func advance(_ runnerID: RunnerID) {
        if runnerID == dad.id {
            dad.currentStageIndex = min(dad.currentStageIndex + 1, max(0, dad.spec.stageCount - 1))
        } else if runnerID == me.id {
            me.currentStageIndex = min(me.currentStageIndex + 1, max(0, me.spec.stageCount - 1))
        }
        save()
    }

    func stepBack(_ runnerID: RunnerID) {
        if runnerID == dad.id {
            dad.currentStageIndex = max(dad.currentStageIndex - 1, 0)
        } else if runnerID == me.id {
            me.currentStageIndex = max(me.currentStageIndex - 1, 0)
        }
        save()
    }

    // MARK: Defaults

    /// Placeholder protocol values. These must be replaced with what the physio
    /// actually prescribed before the app is used in anger — the caps here are
    /// a guess, and a guess is not a prescription.
    static var defaultDad: Runner {
        Runner(
            id: RunnerID("dad"),
            displayName: "Dad",
            role: .recovering,
            spec: .physioProtocol(source: "Physio", recordedOn: Date()),
            currentStageIndex: 0
        )
    }

    static var defaultMe: Runner {
        Runner(
            id: RunnerID("me"),
            displayName: "Me",
            role: .building,
            spec: .beginner(),
            currentStageIndex: 0
        )
    }

    private struct Persisted: Codable {
        var dad: Runner
        var me: Runner
    }
}
