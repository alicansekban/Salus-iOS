import Testing

@testable import SalusUI

/// A baseline line (the REDUCE "old average", iOS-M17 Task 11) has to be inside the plotted range:
/// Swift Charts fits the y scale to the marks it is given, and a 20-a-day rule over bars of 5 to 8
/// would otherwise be drawn off the top of the canvas or squash the bars. Twin of Android's
/// `BarChartRangeTest`.
@Suite("BarChartRange")
struct BarChartRangeTests {
    private func bars(_ values: Float...) -> [BarEntry] {
        values.map { BarEntry(label: "d", value: $0) }
    }

    @Test("without a baseline the chart keeps its own range")
    func noBaselineNoRange() {
        #expect(BarChartRange.maxY(bars: bars(5, 8), baseline: nil) == nil)
    }

    @Test("a baseline above every bar is inside the range, with room for its label")
    func baselineAboveBarsFits() throws {
        let maxY = try #require(BarChartRange.maxY(bars: bars(5, 8), baseline: BarBaseline(value: 20, label: "avg")))

        #expect(maxY > 20)
    }

    @Test("a bar above the baseline still fits")
    func tallBarStillFits() throws {
        let maxY = try #require(BarChartRange.maxY(bars: bars(5, 30), baseline: BarBaseline(value: 20, label: "avg")))

        #expect(maxY >= 30)
    }

    @Test("bars that are all zero still give the baseline a range")
    func zeroBarsGiveTheBaselineARange() throws {
        let maxY = try #require(BarChartRange.maxY(bars: bars(0, 0), baseline: BarBaseline(value: 20)))

        #expect(maxY > 20)
    }

    @Test("a grouped chart's second series counts toward the tallest bar")
    func secondaryValueCounts() throws {
        let grouped = [BarEntry(label: "d", value: 3, secondaryValue: 40)]
        let maxY = try #require(BarChartRange.maxY(bars: grouped, baseline: BarBaseline(value: 20)))

        #expect(maxY >= 40)
    }

    @Test("the baseline is optional on the model, so every existing call site is unchanged")
    func baselineDefaultsToNone() {
        #expect(BarChartUiModel(bars: []).baseline == nil)
    }
}
