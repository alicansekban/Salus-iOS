// Ported from Android
// `feature/trends/src/test/kotlin/com/alicansekban/salus/feature/trends/ui/SmokingTrendsModelTest.kt`
// (the integer half; the reduction curve is `ReductionChartModelTests`).

import SalusSmoking
import Testing

@testable import FeatureTrends

/// The UI edge of the smoking insights: plain functions, so the rules are tested off-device.
@Suite("SmokingTrendsModel")
struct SmokingTrendsModelTests {
    // MARK: - Triggers

    @Test("a trigger bar keeps the order it was given and fills in proportion to its share")
    func triggerBarKeepsOrderAndFillsInProportion() {
        let bars = triggerBarsOf([
            TriggerShare(trigger: .coffee, count: 34, permille: 340),
            TriggerShare(trigger: .stress, count: 6, permille: 60)
        ])

        #expect(bars.map(\.trigger) == [.coffee, .stress])
        #expect(abs(bars[0].progress - 0.34) < 0.0001)
        #expect(abs(bars[1].progress - 0.06) < 0.0001)
    }

    @Test("no trigger recorded means no bars")
    func noTriggerMeansNoBars() {
        #expect(triggerBarsOf([]).isEmpty)
    }

    @Test("a share is written as a whole percentage rounded half up")
    func shareIsAWholePercentageRoundedHalfUp() {
        #expect(percentOf(340) == 34)
        #expect(percentOf(344) == 34)
        #expect(percentOf(345) == 35)
        #expect(percentOf(1000) == 100)
        #expect(percentOf(4) == 0)
    }

    // MARK: - Heatmap

    @Test("the heatmap grid is always seven bands by seven weekdays")
    func heatmapGridIsAlwaysSevenBySeven() {
        let grid = heatmapValuesOf([[1, 2], [3]])

        #expect(grid.count == 7)
        #expect(grid.allSatisfy { $0.count == 7 })
        // A short row is padded with empty cells, never shifted: column 1 stays Monday.
        #expect(grid[0] == [1, 2, 0, 0, 0, 0, 0])
        #expect(grid[1] == [3, 0, 0, 0, 0, 0, 0])
        #expect(grid[6] == Array(repeating: 0, count: 7))
    }

    // MARK: - Attempts

    @Test("attempts are numbered from one and measured against the longest")
    func attemptsAreNumberedFromOneAndMeasuredAgainstTheLongest() {
        let bars = attemptBarsOf([
            AttemptDuration(attemptId: "a", durationMs: 9 * dayMs),
            AttemptDuration(attemptId: "b", durationMs: 18 * dayMs),
            AttemptDuration(attemptId: "c", durationMs: 42 * dayMs + 5 * 3_600_000)
        ])

        #expect(bars.map(\.ordinal) == [1, 2, 3])
        // Whole days only: the five hours into day 43 are not a 43rd day yet.
        #expect(bars.map(\.days) == [9, 18, 42])
        #expect(bars[2].progress == 1)
        #expect(abs(bars[0].progress - 9.0 / 42.0) < 0.001)
    }

    @Test("an attempt shorter than a day draws as zero days without dividing by zero")
    func attemptShorterThanADayDrawsAsZeroDays() {
        let bars = attemptBarsOf([AttemptDuration(attemptId: "a", durationMs: 3_600_000)])

        #expect(bars.first?.days == 0)
        #expect(bars.first?.progress == 0)
    }

    @Test("no attempts means no bars")
    func noAttemptsMeansNoBars() {
        #expect(attemptBarsOf([]).isEmpty)
    }

    private let dayMs: Int64 = 86_400_000
}
