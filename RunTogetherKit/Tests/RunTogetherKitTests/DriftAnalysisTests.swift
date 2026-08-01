import XCTest
@testable import RunTogetherKit

final class DriftAnalysisTests: XCTestCase {

    private let epoch = Date(timeIntervalSince1970: 1_770_000_000)

    /// A straight northward walk from a fixed origin, one sample per second.
    private func trace(
        count: Int,
        startOffset: TimeInterval = 0,
        latitude: Double = 51.5007,
        longitude: Double = -0.1246,
        latitudeStep: Double = 0
    ) -> [TrackPoint] {
        (0..<count).map { index in
            TrackPoint(
                timestamp: epoch.addingTimeInterval(startOffset + Double(index)),
                latitude: latitude + latitudeStep * Double(index),
                longitude: longitude
            )
        }
    }

    func testIdenticalTracksShowNoDrift() {
        let a = trace(count: 30, latitudeStep: 0.00001)
        let report = DriftAnalysis.compare(a, a)

        XCTAssertEqual(report.sampleCount, 30)
        XCTAssertEqual(report.maxGapMeters, 0, accuracy: 0.001)
        XCTAssertEqual(report.meanGapMeters, 0, accuracy: 0.001)
        XCTAssertEqual(report.fractionWithinThreshold, 1.0, accuracy: 0.001)
    }

    func testKnownLatitudeOffsetProducesTheExpectedDistance() {
        // 0.001 degrees of latitude is ~111.2 m on a 6371 km sphere.
        let a = trace(count: 20)
        let b = trace(count: 20, latitude: 51.5007 + 0.001)

        let report = DriftAnalysis.compare(a, b, thresholdMeters: 20)

        XCTAssertEqual(report.maxGapMeters, 111.19, accuracy: 1.0)
        XCTAssertEqual(report.meanGapMeters, 111.19, accuracy: 1.0)
        XCTAssertEqual(report.fractionWithinThreshold, 0.0, accuracy: 0.001)
    }

    func testReportsWhenTheGapOpened() {
        // Together for the first half, then one runner stops moving — the shape
        // of a runner who has run out of legs mid-session.
        var a = trace(count: 60, latitudeStep: 0.0001)
        let b = a
        for index in 30..<60 {
            a[index] = TrackPoint(
                timestamp: a[index].timestamp,
                latitude: a[29].latitude,
                longitude: a[29].longitude
            )
        }

        let report = DriftAnalysis.compare(a, b, thresholdMeters: 20)

        XCTAssertGreaterThan(report.maxGapMeters, 100)
        guard let worst = report.timeOfMaxGap else {
            return XCTFail("expected a timestamp for the worst gap")
        }
        // The gap is widest at the very end, not at the moment it opened.
        XCTAssertEqual(worst.timeIntervalSince(epoch), 59, accuracy: 1.5)
        XCTAssertGreaterThan(report.fractionWithinThreshold, 0.4)
        XCTAssertLessThan(report.fractionWithinThreshold, 0.75)
    }

    func testNonOverlappingRecordingsProduceNothing() {
        let a = trace(count: 10)
        let b = trace(count: 10, startOffset: 500)

        let report = DriftAnalysis.compare(a, b)

        XCTAssertEqual(report.sampleCount, 0)
        XCTAssertEqual(report.maxGapMeters, 0)
        XCTAssertNil(report.timeOfMaxGap)
    }

    func testOnlyTheOverlappingWindowIsCompared() {
        // One of you starts your watch late. Only the shared window counts.
        let a = trace(count: 60)
        let b = trace(count: 60, startOffset: 30)

        let report = DriftAnalysis.compare(a, b)

        XCTAssertEqual(report.sampleCount, 30)
    }

    func testEmptyInputIsHandled() {
        XCTAssertEqual(DriftAnalysis.compare([], trace(count: 5)).sampleCount, 0)
        XCTAssertEqual(DriftAnalysis.compare(trace(count: 5), []).sampleCount, 0)
    }

    func testInterpolationBetweenSamples() {
        let points = [
            TrackPoint(timestamp: epoch, latitude: 0, longitude: 0),
            TrackPoint(timestamp: epoch.addingTimeInterval(10), latitude: 1, longitude: 2)
        ]

        let midpoint = DriftAnalysis.interpolate(points, at: epoch.addingTimeInterval(5))

        XCTAssertEqual(midpoint?.latitude ?? .nan, 0.5, accuracy: 0.0001)
        XCTAssertEqual(midpoint?.longitude ?? .nan, 1.0, accuracy: 0.0001)
    }

    func testInterpolationClampsOutsideTheRange() {
        let points = trace(count: 5)

        let before = DriftAnalysis.interpolate(points, at: epoch.addingTimeInterval(-100))
        let after = DriftAnalysis.interpolate(points, at: epoch.addingTimeInterval(100))

        XCTAssertEqual(before?.timestamp, points.first?.timestamp)
        XCTAssertEqual(after?.timestamp, points.last?.timestamp)
    }
}
