import Foundation
import Observation
import RunTogetherKit

/// Sessions that were started, and the recorded workouts matched to them.
@Observable
final class SessionLog {

    private static let storageKey = "sessionLog.v1"

    private(set) var sessions: [SessionRecord] = []
    private(set) var runs: [CompletedRun] = []

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(Persisted.self, from: data) {
            self.sessions = saved.sessions
            self.runs = saved.runs
        }
    }

    // MARK: Sessions

    func begin(_ record: SessionRecord) {
        sessions.append(record)
        save()
    }

    /// Closes a session's window. Called on natural completion *and* on an
    /// early stop, because an abandoned four-minute session must not go
    /// looking for a thirty-minute workout to claim.
    func finish(id: UUID, at endedAt: Date, ranToCompletion: Bool) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].endedAt = endedAt
        sessions[index].ranToCompletion = ranToCompletion
        save()
    }

    var sessionsNewestFirst: [SessionRecord] {
        sessions.sorted { $0.startedAt > $1.startedAt }
    }

    /// Finished sessions with no workout attached yet — the import targets.
    var unmatchedSessions: [SessionRecord] {
        let matched = Set(runs.compactMap(\.sessionID))
        return sessions.filter { $0.endedAt != nil && !matched.contains($0.id) }
    }

    // MARK: Runs

    func attach(_ run: CompletedRun) {
        if let index = runs.firstIndex(where: { $0.id == run.id }) {
            runs[index] = run
        } else {
            runs.append(run)
        }
        save()
    }

    func run(forSession sessionID: UUID) -> CompletedRun? {
        runs.first { $0.sessionID == sessionID }
    }

    var importedWorkoutIDs: Set<String> {
        Set(runs.map(\.id))
    }

    // MARK: Storage

    func save() {
        guard let data = try? JSONEncoder().encode(Persisted(sessions: sessions, runs: runs)) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private struct Persisted: Codable {
        var sessions: [SessionRecord]
        var runs: [CompletedRun]
    }
}
