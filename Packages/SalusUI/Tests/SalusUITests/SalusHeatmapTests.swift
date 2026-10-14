import Testing

@testable import SalusUI

/// The pure half of `SalusHeatmap` (iOS-M17 Task 8, design review R1/R2): which of the five accent
/// steps a cell value lands on. The grid itself is a plain `Grid` of rounded squares and is only
/// a `#Preview` build, like every other component suite here.
@Suite("SalusHeatmap.bucket")
struct SalusHeatmapTests {
    @Test("zero and negative values are the empty step, whatever the maximum")
    func zeroIsTheEmptyStep() {
        #expect(SalusHeatmap.bucket(for: 0, max: 6) == 0)
        #expect(SalusHeatmap.bucket(for: -3, max: 6) == 0)
        #expect(SalusHeatmap.bucket(for: 0, max: 0) == 0)
    }

    @Test("a grid with no positive maximum draws every cell empty")
    func noMaximumMeansEmpty() {
        #expect(SalusHeatmap.bucket(for: 4, max: 0) == 0)
        #expect(SalusHeatmap.bucket(for: 4, max: -1) == 0)
    }

    @Test("the maximum is always the strongest step")
    func maximumIsStepFive() {
        #expect(SalusHeatmap.bucket(for: 6, max: 6) == 5)
        #expect(SalusHeatmap.bucket(for: 1, max: 1) == 5)
        #expect(SalusHeatmap.bucket(for: 100, max: 100) == 5)
    }

    @Test("any non-zero value is at least step one, even a tiny share of a large maximum")
    func smallestNonZeroIsStepOne() {
        #expect(SalusHeatmap.bucket(for: 1, max: 6) == 1)
        #expect(SalusHeatmap.bucket(for: 1, max: 100) == 1)
    }

    @Test("steps rise in fifths of the maximum, rounding up")
    func fifthsOfTheMaximum() {
        // max 10: 1-2 -> 1, 3-4 -> 2, 5-6 -> 3, 7-8 -> 4, 9-10 -> 5.
        let expected = [0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5]
        let actual = (0 ... 10).map { SalusHeatmap.bucket(for: $0, max: 10) }
        #expect(actual == expected)
    }

    @Test("a value above the stated maximum clamps to the strongest step")
    func aboveMaximumClamps() {
        #expect(SalusHeatmap.bucket(for: 9, max: 6) == 5)
    }

    @Test("the maximum of a grid is the largest cell, 0 when the grid is empty or ragged-empty")
    func gridMaximum() {
        #expect(SalusHeatmap.maxValue(in: [[1, 2, 0], [0, 6, 3]]) == 6)
        #expect(SalusHeatmap.maxValue(in: []) == 0)
        #expect(SalusHeatmap.maxValue(in: [[], []]) == 0)
        #expect(SalusHeatmap.maxValue(in: [[-2, -1]]) == 0)
    }

    @Test("a missing cell in a ragged row reads as zero")
    func raggedRowsReadAsZero() {
        let values = [[3, 1], [2]]
        #expect(SalusHeatmap.value(in: values, row: 1, column: 0) == 2)
        #expect(SalusHeatmap.value(in: values, row: 1, column: 1) == 0)
        #expect(SalusHeatmap.value(in: values, row: 5, column: 0) == 0)
    }
}
