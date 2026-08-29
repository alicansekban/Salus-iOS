// Ported 1:1 from `feature/cycle/src/test/kotlin/com/alicansekban/salus/feature/cycle/domain/
// usecase/CyclePredictorTest.kt`.
//
// Eleven cases, in the Kotlin order, with the Kotlin inputs and the Kotlin expectations; each
// display name is the backticked Kotlin name verbatim, so a case renamed on one platform and not
// the other is visible in the diff. Each one cites the Kotlin line it comes from.

import SalusModel
import Testing

@testable import FeatureCycle

@Suite("CyclePredictor")
struct CyclePredictorTests {
    private let predictor = CyclePredictor()

    /// `CyclePredictorTest.kt:44-62`.
    @Test("regular 28-day cycles produce HIGH confidence and correct dates")
    func regular28DayCyclesProduceHighConfidenceAndCorrectDates() throws {
        let first = LocalDate(year: 2026, month: 1, day: 1)
        let starts = startsFromLengths(first: first, lengths: Array(repeating: 28, count: 6))
        let last = try #require(starts.last)
        let today = last.plusDays(3)

        let prediction = try #require(predictor(periods(starts: starts), today: today))

        let expectedNext = last.plusDays(28)
        #expect(prediction.nextPeriodStart == expectedNext)
        #expect(prediction.ovulationDate == expectedNext.minusDays(14))
        #expect(prediction.fertileWindowStart == expectedNext.minusDays(19))
        #expect(prediction.fertileWindowEnd == expectedNext.minusDays(13))
        #expect(prediction.averageCycleLength == 28)
        #expect(prediction.confidence == .high)
        #expect(prediction.isIrregular == false)
    }

    /// `CyclePredictorTest.kt:64-77` — lengths 24,28,32,24,28,32: mean 28, sd about 3.27 (above
    /// the HIGH cutoff of 3).
    @Test("six usable cycles with moderate deviation produce MEDIUM confidence")
    func sixUsableCyclesWithModerateDeviationProduceMediumConfidence() throws {
        let starts = startsFromLengths(
            first: LocalDate(year: 2026, month: 1, day: 1),
            lengths: [24, 28, 32, 24, 28, 32]
        )
        let last = try #require(starts.last)
        let today = last.plusDays(1)

        let prediction = try #require(predictor(periods(starts: starts), today: today))

        #expect(prediction.confidence == .medium)
        #expect(prediction.isIrregular == false)
        // Recency-weighted average: (24*1+28*2+32*3+24*4+28*5+32*6)/21 = 28.76 -> 29.
        #expect(prediction.averageCycleLength == 29)
        #expect(prediction.nextPeriodStart == last.plusDays(29))
    }

    /// `CyclePredictorTest.kt:79-89` — lengths 21,45,22,44,23,43: sd is far above 7.
    @Test("high standard deviation is irregular with LOW confidence")
    func highStandardDeviationIsIrregularWithLowConfidence() throws {
        let starts = startsFromLengths(
            first: LocalDate(year: 2026, month: 1, day: 1),
            lengths: [21, 45, 22, 44, 23, 43]
        )
        let last = try #require(starts.last)
        let today = last.plusDays(1)

        let prediction = try #require(predictor(periods(starts: starts), today: today))

        #expect(prediction.confidence == .low)
        #expect(prediction.isIrregular)
    }

    /// `CyclePredictorTest.kt:91-101`.
    @Test("fewer than three usable cycles produce LOW confidence")
    func fewerThanThreeUsableCyclesProduceLowConfidence() throws {
        let starts = startsFromLengths(first: LocalDate(year: 2026, month: 1, day: 1), lengths: [28])
        let last = try #require(starts.last)
        let today = last.plusDays(1)

        let prediction = try #require(predictor(periods(starts: starts), today: today))

        #expect(prediction.confidence == .low)
        #expect(prediction.isIrregular)
        #expect(prediction.nextPeriodStart == last.plusDays(28))
    }

    /// `CyclePredictorTest.kt:103-115` — a 60-day gap is filtered out; the remaining lengths are
    /// all 28.
    @Test("outlier cycle length is excluded from the average")
    func outlierCycleLengthIsExcludedFromTheAverage() throws {
        let starts = startsFromLengths(
            first: LocalDate(year: 2026, month: 1, day: 1),
            lengths: [28, 28, 60, 28, 28]
        )
        let last = try #require(starts.last)
        let today = last.plusDays(1)

        let prediction = try #require(predictor(periods(starts: starts), today: today))

        #expect(prediction.averageCycleLength == 28)
        #expect(prediction.nextPeriodStart == last.plusDays(28))
        // 4 usable cycles remain -> MEDIUM, not HIGH.
        #expect(prediction.confidence == .medium)
    }

    /// `CyclePredictorTest.kt:117-127` — lengths 30,30,30,26,26,26: plain mean 28,
    /// recency-weighted 27.14 -> 27.
    @Test("recent shorter cycles pull the prediction below the plain mean")
    func recentShorterCyclesPullThePredictionBelowThePlainMean() throws {
        let starts = startsFromLengths(
            first: LocalDate(year: 2026, month: 1, day: 1),
            lengths: [30, 30, 30, 26, 26, 26]
        )
        let last = try #require(starts.last)
        let today = last.plusDays(1)

        let prediction = try #require(predictor(periods(starts: starts), today: today))

        #expect(prediction.averageCycleLength == 27)
        #expect(prediction.nextPeriodStart == last.plusDays(27))
    }

    /// `CyclePredictorTest.kt:129-142` — old 40-day cycles fall outside the 6-cycle window; the
    /// remaining lengths are all 28.
    @Test("only the last six cycle lengths are used")
    func onlyTheLastSixCycleLengthsAreUsed() throws {
        let starts = startsFromLengths(
            first: LocalDate(year: 2025, month: 1, day: 1),
            lengths: [40, 40, 28, 28, 28, 28, 28, 28]
        )
        let last = try #require(starts.last)
        let today = last.plusDays(1)

        let prediction = try #require(predictor(periods(starts: starts), today: today))

        #expect(prediction.averageCycleLength == 28)
        #expect(prediction.confidence == .high)
    }

    /// `CyclePredictorTest.kt:144-150`.
    @Test("zero or one recorded period produces no prediction")
    func zeroOrOneRecordedPeriodProducesNoPrediction() {
        let today = LocalDate(year: 2026, month: 3, day: 1)

        #expect(predictor([], today: today) == nil)
        #expect(predictor(periods(starts: [LocalDate(year: 2026, month: 1, day: 1)]), today: today) == nil)
    }

    /// `CyclePredictorTest.kt:152-162`.
    @Test("overdue prediction is returned in the past and not clamped")
    func overduePredictionIsReturnedInThePastAndNotClamped() throws {
        let starts = startsFromLengths(
            first: LocalDate(year: 2025, month: 1, day: 1),
            lengths: Array(repeating: 28, count: 6)
        )
        let last = try #require(starts.last)
        let expectedNext = last.plusDays(28)
        let today = expectedNext.plusDays(20)

        let prediction = try #require(predictor(periods(starts: starts), today: today))

        #expect(prediction.nextPeriodStart == expectedNext)
        #expect(prediction.nextPeriodStart < today)
    }

    /// `CyclePredictorTest.kt:164-172`.
    @Test("future-dated period starts are ignored")
    func futureDatedPeriodStartsAreIgnored() throws {
        let starts = startsFromLengths(
            first: LocalDate(year: 2026, month: 1, day: 1),
            lengths: [28, 28, 28]
        )
        let today = starts[2] // the last recorded start is after today

        let prediction = try #require(predictor(periods(starts: starts), today: today))

        // Only the first three starts count; prediction anchors on starts[2].
        #expect(prediction.nextPeriodStart == starts[2].plusDays(28))
    }

    /// `CyclePredictorTest.kt:174-184`.
    @Test("all lengths filtered as outliers falls back to unfiltered lengths with LOW confidence")
    func allLengthsFilteredAsOutliersFallsBackToUnfilteredLengthsWithLowConfidence() throws {
        let starts = startsFromLengths(first: LocalDate(year: 2026, month: 1, day: 1), lengths: [60, 60])
        let last = try #require(starts.last)
        let today = last.plusDays(1)

        let prediction = try #require(predictor(periods(starts: starts), today: today))

        #expect(prediction.averageCycleLength == 60)
        #expect(prediction.confidence == .low)
        #expect(prediction.isIrregular)
    }
}
