import Testing

@testable import SalusModel

/// Covers the pure metric statistics helpers. They hold no dependency on where the readings came
/// from, so no database or platform machinery is involved here.
///
/// A one-for-one port of Android's `MetricStatsTest.kt` — same eight cases, same names, same
/// literals. Where Kotlin uses `assertEquals(expected, actual, TOLERANCE)`, this compares against
/// the same tolerance explicitly.
@Suite("MetricStats (MetricStatsTest.kt parity)")
struct MetricStatsTests {
    /// `MetricStatsTest.kt:74`.
    static let tolerance = 1e-9

    // --- metricStatsOf -------------------------------------------------------------------

    @Test("metricStatsOf returns null for an empty series")
    func metricStatsOfReturnsNullForAnEmptySeries() {
        #expect(metricStatsOf([]) == nil)
    }

    @Test("metricStatsOf of a single value collapses average min and max and stays stable")
    func metricStatsOfOfASingleValueCollapsesAverageMinAndMaxAndStaysStable() throws {
        let stats = try #require(metricStatsOf([72.5]))

        #expect(stats.count == 1)
        #expect(abs(stats.average - 72.5) < Self.tolerance)
        #expect(abs(stats.min - 72.5) < Self.tolerance)
        #expect(abs(stats.max - 72.5) < Self.tolerance)
        #expect(stats.trend == .stable)
    }

    @Test("metricStatsOf reports the extremes of an unsorted series")
    func metricStatsOfReportsTheExtremesOfAnUnsortedSeries() throws {
        let stats = try #require(metricStatsOf([120.0, 100.0, 140.0, 130.0]))

        #expect(stats.count == 4)
        #expect(abs(stats.average - 122.5) < Self.tolerance)
        #expect(abs(stats.min - 100.0) < Self.tolerance)
        #expect(abs(stats.max - 140.0) < Self.tolerance)
    }

    // --- trendOf -------------------------------------------------------------------------

    @Test("trendOf stays stable below four samples")
    func trendOfStaysStableBelowFourSamples() {
        #expect(trendOf([]) == .stable)
        #expect(trendOf([10.0]) == .stable)
        #expect(trendOf([10.0, 100.0]) == .stable)
        #expect(trendOf([10.0, 100.0, 1000.0]) == .stable)
    }

    @Test("trendOf detects a rising series")
    func trendOfDetectsARisingSeries() {
        #expect(trendOf([100.0, 102.0, 130.0, 140.0]) == .rising)
    }

    @Test("trendOf detects a falling series")
    func trendOfDetectsAFallingSeries() {
        #expect(trendOf([140.0, 130.0, 102.0, 100.0]) == .falling)
    }

    @Test("trendOf treats movement within five percent as stable")
    func trendOfTreatsMovementWithinFivePercentAsStable() {
        // Halves average 100.5 and 104.0: a 3.5% rise, below the 5% band.
        #expect(trendOf([100.0, 101.0, 103.0, 105.0]) == .stable)
    }

    @Test("trendOf compares symmetric halves and ignores the middle sample of an odd series")
    func trendOfComparesSymmetricHalvesAndIgnoresTheMiddleSampleOfAnOddSeries() {
        // Middle sample is an extreme outlier; the two halves are identical, so nothing moved.
        #expect(trendOf([100.0, 100.0, 900.0, 100.0, 100.0]) == .stable)
    }
}
