// Ported from Android
// `feature/trends/src/test/kotlin/com/alicansekban/salus/feature/trends/ui/DoseWeeksChartModelTest.kt`.

import SalusUI
import Testing

@testable import FeatureTrends

/// The UI edge of the weekly dose analysis (`DoseWeeksChartModelTest.kt`).
///
/// What is pinned here is what a bar is allowed to stand for. A column chart makes every value
/// look like a measured one, so the rules that keep an unlogged week off the axis — and the
/// averages off an axis that belongs to percentages — are checked in code rather than by eye.
@Suite("DoseWeeksChartModel")
struct DoseWeeksChartModelTests {
    @Test("a week with no logged dose gets no bar at all")
    func weekWithNoLoggedDoseGetsNoBar() {
        // Not a zero-height column: nothing was recorded, and a zero would read as a week whose
        // doses all went untaken.
        let model = doseWeeksChartModelOf(
            weeks: [
                week(startEpochDay: monday, percent: nil),
                week(startEpochDay: monday + daysInWeek, percent: 80)
            ],
            weekLabel: labelOf,
            axisLabel: axisLabelOf
        )

        let bars = model?.chart.bars ?? []
        #expect(bars.count == 1)
        #expect(bars.single().label == labelOf(monday + daysInWeek))
        #expect(abs(bars.single().value - 80) < floatTolerance)
    }

    @Test("no bar carries a second series, because the axis is a percentage")
    func noBarCarriesASecondSeries() {
        let model = doseWeeksChartModelOf(
            weeks: [week(startEpochDay: monday, percent: 50, systolic: 130.0, glucose: 100.0)],
            weekLabel: labelOf,
            axisLabel: axisLabelOf
        )

        #expect((model?.chart.bars ?? []).allSatisfy { $0.secondaryValue == nil })
    }

    @Test("a caption describes the bar standing next to it")
    func captionDescribesTheBarStandingNextToIt() {
        let model = doseWeeksChartModelOf(
            weeks: [
                week(startEpochDay: monday, percent: 40, systolic: 120.0),
                week(startEpochDay: monday + daysInWeek, percent: nil, systolic: 200.0),
                week(startEpochDay: monday + 2 * daysInWeek, percent: 60, glucose: 105.0)
            ],
            weekLabel: labelOf,
            axisLabel: axisLabelOf
        )

        let weeks = model?.weeks ?? []
        // The undrawn middle week takes its averages with it: they belonged to a bar that does
        // not exist, so no caption may claim them.
        #expect(model?.chart.bars.count == weeks.count)
        #expect(model?.chart.bars.map(\.label) == weeks.map(\.label))
        #expect(weeks.map(\.takenPercent) == [40, 60])
        #expect(abs((weeks.first?.systolicAverage ?? 0) - 120.0) < tolerance)
        #expect(weeks.last?.systolicAverage == nil)
        #expect(abs((weeks.last?.glucoseAverage ?? 0) - 105.0) < tolerance)
    }

    @Test("a week with no reading keeps both averages absent")
    func weekWithNoReadingKeepsBothAveragesAbsent() {
        let model = doseWeeksChartModelOf(
            weeks: [week(startEpochDay: monday, percent: 100)],
            weekLabel: labelOf,
            axisLabel: axisLabelOf
        )

        #expect(model?.weeks.single().systolicAverage == nil)
        #expect(model?.weeks.single().glucoseAverage == nil)
    }

    @Test("there is no model when not one week logged a dose")
    func noModelWhenNotOneWeekLoggedADose() {
        #expect(doseWeeksChartModelOf(
            weeks: [week(startEpochDay: monday, percent: nil), week(startEpochDay: monday + daysInWeek, percent: nil)],
            weekLabel: labelOf,
            axisLabel: axisLabelOf
        ) == nil)
    }

    @Test("an empty window has no model either")
    func emptyWindowHasNoModel() {
        #expect(doseWeeksChartModelOf(
            weeks: [],
            weekLabel: labelOf,
            axisLabel: axisLabelOf
        ) == nil)
    }

    @Test("the axis writer is the one the caller passed in")
    func axisWriterIsTheOneTheCallerPassedIn() {
        let model = doseWeeksChartModelOf(
            weeks: [week(startEpochDay: monday, percent: 25)],
            weekLabel: labelOf,
            axisLabel: axisLabelOf
        )

        #expect(model?.chart.yLabel(25) == axisLabelOf(25))
    }

    // MARK: - Fixtures

    private func week(
        startEpochDay: Int,
        percent: Int?,
        systolic: Double? = nil,
        glucose: Double? = nil
    ) -> DoseWeek {
        DoseWeek(
            startEpochDay: startEpochDay,
            // The counts play no part in the mapping; the share is what a bar is drawn from.
            loggedDoses: percent == nil ? 0 : dosesPerWeek,
            takenDoses: percent == nil ? 0 : dosesPerWeek,
            takenPercent: percent,
            systolicAverage: systolic,
            glucoseAverage: glucose
        )
    }

    private func labelOf(_ epochDay: Int) -> String {
        "day \(epochDay)"
    }

    private func axisLabelOf(_ value: Float) -> String {
        "tick \(value)"
    }
}

private let monday = 20668
private let daysInWeek = 7
private let dosesPerWeek = 7
private let tolerance = 0.0001
private let floatTolerance: Float = 0.0001

extension Collection {
    fileprivate func single() -> Element {
        precondition(count == 1, "expected exactly one element, found \(count)")
        // swiftlint:disable:next force_unwrapping
        return first!
    }
}
