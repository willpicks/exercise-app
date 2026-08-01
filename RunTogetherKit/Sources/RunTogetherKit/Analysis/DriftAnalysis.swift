import Foundation

/// A single GPS sample. Deliberately not `CLLocation` — keeping this a plain
/// value type is what allows the drift maths to be tested without CoreLocation
/// and on any platform.
public struct TrackPoint: Hashable, Sendable {
    public let timestamp: Date
    public let latitude: Double
    public let longitude: Double

    public init(timestamp: Date, latitude: Double, longitude: Double) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct DriftReport: Hashable, Sendable {
    public let sampleCount: Int
    public let maxGapMeters: Double
    public let timeOfMaxGap: Date?
    public let meanGapMeters: Double
    public let fractionWithinThreshold: Double
    public let thresholdMeters: Double

    public init(
        sampleCount: Int,
        maxGapMeters: Double,
        timeOfMaxGap: Date?,
        meanGapMeters: Double,
        fractionWithinThreshold: Double,
        thresholdMeters: Double
    ) {
        self.sampleCount = sampleCount
        self.maxGapMeters = maxGapMeters
        self.timeOfMaxGap = timeOfMaxGap
        self.meanGapMeters = meanGapMeters
        self.fractionWithinThreshold = fractionWithinThreshold
        self.thresholdMeters = thresholdMeters
    }

    public static let empty = DriftReport(
        sampleCount: 0,
        maxGapMeters: 0,
        timeOfMaxGap: nil,
        meanGapMeters: 0,
        fractionWithinThreshold: 0,
        thresholdMeters: 0
    )
}

/// How far apart were the two of you, and when was it worst.
///
/// Now that paired runs share one lane this is a diagnostic rather than a
/// score. A gap opening in the back half of a session means somebody is
/// struggling, and the timestamp says which interval it started on — usually
/// the earliest warning available that a stage was advanced too soon.
public enum DriftAnalysis {

    public static func compare(
        _ a: [TrackPoint],
        _ b: [TrackPoint],
        thresholdMeters: Double = 20,
        sampleInterval: TimeInterval = 1
    ) -> DriftReport {
        guard sampleInterval > 0, !a.isEmpty, !b.isEmpty else { return .empty }

        let first = a.sorted { $0.timestamp < $1.timestamp }
        let second = b.sorted { $0.timestamp < $1.timestamp }

        // Only the window both runners were recording can be compared.
        let windowStart = max(first[0].timestamp, second[0].timestamp)
        let windowEnd = min(
            first[first.count - 1].timestamp,
            second[second.count - 1].timestamp
        )
        guard windowEnd > windowStart else { return .empty }

        var gaps: [(Date, Double)] = []
        var offset: TimeInterval = 0
        let span = windowEnd.timeIntervalSince(windowStart)

        while offset <= span {
            let instant = windowStart.addingTimeInterval(offset)
            if let p = interpolate(first, at: instant), let q = interpolate(second, at: instant) {
                gaps.append((instant, haversineMeters(p, q)))
            }
            offset += sampleInterval
        }

        guard !gaps.isEmpty else { return .empty }

        var maxGap = 0.0
        var maxAt: Date?
        var total = 0.0
        var within = 0

        for (instant, gap) in gaps {
            total += gap
            if gap > maxGap {
                maxGap = gap
                maxAt = instant
            }
            if gap <= thresholdMeters { within += 1 }
        }

        return DriftReport(
            sampleCount: gaps.count,
            maxGapMeters: maxGap,
            timeOfMaxGap: maxAt,
            meanGapMeters: total / Double(gaps.count),
            fractionWithinThreshold: Double(within) / Double(gaps.count),
            thresholdMeters: thresholdMeters
        )
    }

    // MARK: Internals

    /// Linear interpolation between the two samples bracketing `instant`.
    /// Expects `points` sorted ascending by timestamp.
    static func interpolate(_ points: [TrackPoint], at instant: Date) -> TrackPoint? {
        guard let low = points.first, let high = points.last else { return nil }
        if instant <= low.timestamp { return low }
        if instant >= high.timestamp { return high }

        var index = 1
        while index < points.count && points[index].timestamp < instant {
            index += 1
        }
        guard index < points.count else { return high }

        let before = points[index - 1]
        let after = points[index]
        let span = after.timestamp.timeIntervalSince(before.timestamp)
        guard span > 0 else { return before }

        let ratio = instant.timeIntervalSince(before.timestamp) / span
        return TrackPoint(
            timestamp: instant,
            latitude: before.latitude + (after.latitude - before.latitude) * ratio,
            longitude: before.longitude + (after.longitude - before.longitude) * ratio
        )
    }

    static func haversineMeters(_ a: TrackPoint, _ b: TrackPoint) -> Double {
        let earthRadius = 6_371_000.0
        let degreesToRadians = Double.pi / 180

        let lat1 = a.latitude * degreesToRadians
        let lat2 = b.latitude * degreesToRadians
        let deltaLat = (b.latitude - a.latitude) * degreesToRadians
        let deltaLon = (b.longitude - a.longitude) * degreesToRadians

        let h = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)

        return 2 * earthRadius * atan2(sqrt(h), sqrt(max(0, 1 - h)))
    }
}
