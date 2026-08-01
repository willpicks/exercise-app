import CoreLocation
import Foundation
import HealthKit
import RunTogetherKit

/// Read-only access to workouts your watch already recorded.
///
/// The app never records a workout itself and never asks for write access —
/// the built-in Workout app does a better job of it, and staying read-only
/// keeps this out of the way of whatever either of you already uses.
///
/// The classic query API is used throughout rather than the newer descriptors,
/// because `HKWorkoutRouteQuery` still delivers locations in batches with a
/// `done` flag and the two styles do not mix cleanly.
@MainActor
final class HealthKitReader {

    enum ReaderError: LocalizedError {
        case unavailable

        var errorDescription: String? {
            switch self {
            case .unavailable: return "Health data isn't available on this device."
            }
        }
    }

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private let store = HKHealthStore()
    private var observerQuery: HKObserverQuery?

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]
        types.insert(HKQuantityType(.heartRate))
        types.insert(HKQuantityType(.distanceWalkingRunning))
        return types
    }

    func requestAuthorization() async throws {
        guard Self.isAvailable else { throw ReaderError.unavailable }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    // MARK: Workouts

    func workouts(since start: Date) async throws -> [HKWorkout] {
        guard Self.isAvailable else { throw ReaderError.unavailable }

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: start,
                end: nil,
                options: .strictStartDate
            )
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
                }
            }
            store.execute(query)
        }
    }

    // MARK: Route

    /// The workout's GPS trace, flattened and sorted. Empty when the workout
    /// carries no route, which is normal for a treadmill run.
    func route(for workout: HKWorkout) async throws -> [TrackPoint] {
        var points: [TrackPoint] = []
        for sample in try await routeSamples(for: workout) {
            points.append(contentsOf: try await locations(in: sample))
        }
        return points.sorted { $0.timestamp < $1.timestamp }
    }

    private func routeSamples(for workout: HKWorkout) async throws -> [HKWorkoutRoute] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKSeriesType.workoutRoute(),
                predicate: HKQuery.predicateForObjects(from: workout),
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples as? [HKWorkoutRoute]) ?? [])
                }
            }
            store.execute(query)
        }
    }

    private func locations(in route: HKWorkoutRoute) async throws -> [TrackPoint] {
        try await withCheckedThrowingContinuation { continuation in
            var collected: [TrackPoint] = []
            // The handler fires repeatedly; a continuation may only be resumed
            // once, so guard against a late error arriving after `done`.
            var hasResumed = false

            let query = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                guard !hasResumed else { return }

                if let error {
                    hasResumed = true
                    continuation.resume(throwing: error)
                    return
                }

                if let locations {
                    collected.append(contentsOf: locations.map { location in
                        TrackPoint(
                            timestamp: location.timestamp,
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude
                        )
                    })
                }

                if done {
                    hasResumed = true
                    continuation.resume(returning: collected)
                }
            }
            store.execute(query)
        }
    }

    // MARK: Background delivery

    /// Lets a finished run reach the feed without the app being opened.
    func enableBackgroundDelivery() async throws {
        guard Self.isAvailable else { throw ReaderError.unavailable }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.enableBackgroundDelivery(
                for: HKObjectType.workoutType(),
                frequency: .immediate
            ) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func startObserving(onChange: @escaping @Sendable () -> Void) {
        guard Self.isAvailable, observerQuery == nil else { return }

        let query = HKObserverQuery(
            sampleType: HKObjectType.workoutType(),
            predicate: nil
        ) { _, completionHandler, _ in
            onChange()
            // Must be called or HealthKit escalates to repeated wake-ups.
            completionHandler()
        }
        observerQuery = query
        store.execute(query)
    }

    func stopObserving() {
        if let observerQuery {
            store.stop(observerQuery)
        }
        observerQuery = nil
    }

    // MARK: Statistics

    nonisolated static func distanceMeters(of workout: HKWorkout) -> Double? {
        workout
            .statistics(for: HKQuantityType(.distanceWalkingRunning))?
            .sumQuantity()?
            .doubleValue(for: .meter())
    }

    nonisolated static func averageHeartRate(of workout: HKWorkout) -> Double? {
        workout
            .statistics(for: HKQuantityType(.heartRate))?
            .averageQuantity()?
            .doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
    }
}
