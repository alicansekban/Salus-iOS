// Ported from Android
// `feature/trends/src/test/kotlin/com/alicansekban/salus/feature/trends/ui/SmokingTrendsModelTest.kt`
// (the reduction-curve cases).

import Testing

@testable import FeatureTrends

/// The reduction curve: units per day, one point per week since setup.
@Suite("ReductionChartModel")
struct ReductionChartModelTests {
    @Test("a week with no logged day is a gap in the curve, not a zero")
    func weekWithNoLoggedDayIsAGap() {
        let model = reductionChartModelOf(weekly: [20, nil, 12, 6]) { "w\($0)" }

        // Week numbers are 1-based, and week 2 has no point at all.
        #expect(model?.points.map(\.xEpochDay) == [1, 3, 4])
        #expect(model?.points.map(\.y) == [20, 12, 6])
    }

    @Test("one logged week is not a curve")
    func oneLoggedWeekIsNotACurve() {
        #expect(reductionChartModelOf(weekly: [nil, 8, nil]) { "w\($0)" } == nil)
        #expect(reductionChartModelOf(weekly: []) { "w\($0)" } == nil)
    }

    @Test("the curve's x labels are the caller's week captions")
    func xLabelsAreTheCallersWeekCaptions() {
        let model = reductionChartModelOf(weekly: [9, 8]) { "Week \($0)" }

        #expect(model?.xLabel(2) == "Week 2")
    }

    @Test("the y axis writes whole units")
    func yAxisWritesWholeUnits() {
        let model = reductionChartModelOf(weekly: [9, 8]) { "w\($0)" }

        #expect(model?.yLabel(12.4) == "12")
    }
}
