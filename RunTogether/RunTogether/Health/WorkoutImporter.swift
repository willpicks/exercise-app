import Foundation
import HealthKit
import Observation
import RunTogetherKit

/// Pulls finished workouts out of HealthKit and attaches them to sessions.
///
/// The matching rule itself lives in `WorkoutMatcher` in the engine, where it
/// is unit-tested. This type is only the plumbing: fetch, convert, hand over,
/// store the result.
@MainActor
@Observable
final class WorkoutImporter {

    enum Status: Equatable {
        case idle
        case needsPermission
        case importing
        case finished(attached: Int)
        case failed(String)
    }

    private(set) var status: Status = .idle

    @ObservationIgnored private let reader = HealthKitReader()
    @ObservationIgnored private var isObserving = false
    @ObservationIgnored private var observedLog: SessionLog?
    @ObservationIgnored private var observedRunnerID: RunnerID?

    var isAvailable: Bool { HealthKitReader.isAvailable }

    func requestAccess() async {
        do {
            try await reader.requestAuthorization()
            try? await reader.enableBackgroundDelivery()
            status = .idle
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// Imports anything recorded since the earliest session still missing a
    /// workout. Safe to call repeatedly — already-imported workouts are skipped
    /// by their HealthKit UUID.
    func importWorkouts(into log: SessionLog, runnerID: RunnerID) async {
        guard isAvailable else {
            status = .failed("Health data isn't available on this device.")
            return
        }

        let pending = log.unmatchedSessions
        guard !pending.isEmpty else {
            status = .finished(attached: 0)
            return
        }

        status = .importing

        // A little margin before the earliest gap, so a watch started early
        // still falls inside the query.
        let earliest = pending.map(\.startedAt).min() ?? Date()
        let searchFrom = earliest.addingTimeInterval(-3_600)

        do {
            let workouts = try await reader.workouts(since: searchFrom)
            let alreadyImported = log.importedWorkoutIDs

            let candidates = workouts
                .filter { !alreadyImported.contains($0.uuid.uuidString) }
                .map {
                    WorkoutCandidate(
                        id: $0.uuid.uuidString,
                        startedAt: $0.startDate,
                        endedAt: $0.endDate
                    )
                }

            let matches = WorkoutMatcher.matchAll(sessions: pending, candidates: candidates)

            var byID: [String: HKWorkout] = [:]
            for workout in workouts {
                byID[workout.uuid.uuidString] = workout
            }

            var attached = 0
            for (sessionID, candidate) in matches {
                guard let workout = byID[candidate.id] else { continue }
                log.attach(
                    CompletedRun(
                        id: candidate.id,
                        runnerID: runnerID,
                        sessionID: sessionID,
                        startedAt: workout.startDate,
                        endedAt: workout.endDate,
                        distanceMeters: HealthKitReader.distanceMeters(of: workout),
                        averageHeartRate: HealthKitReader.averageHeartRate(of: workout)
                    )
                )
                attached += 1
            }

            status = .finished(attached: attached)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// Re-imports whenever HealthKit reports new workout data.
    ///
    /// The observer handler runs off the main actor, so it captures only
    /// `self` — a `@MainActor` type, and therefore `Sendable` — and picks the
    /// log back up once it has hopped over.
    func observeChanges(into log: SessionLog, runnerID: RunnerID) {
        guard !isObserving else { return }
        isObserving = true
        observedLog = log
        observedRunnerID = runnerID

        reader.startObserving {
            Task { @MainActor [weak self] in
                guard let self,
                      let log = self.observedLog,
                      let runnerID = self.observedRunnerID
                else { return }
                await self.importWorkouts(into: log, runnerID: runnerID)
            }
        }
    }
}
