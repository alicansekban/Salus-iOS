// Ported from Android
// `feature/trends/src/test/kotlin/com/alicansekban/salus/feature/trends/ui/TimeOfDayChartModelTest.kt`.

import Foundation
import SalusModel
import Testing

@testable import FeatureTrends

/// The UI edge of the time-of-day analysis (`TimeOfDayChartModelTest.kt`).
///
/// The rule these tests exist for: both chart series must always cover the same x values. The
/// bar chart draws a grouped column layer, and a second series that spans fewer columns than the
/// first is a rendering path this app does not want to depend on — so the mapping makes it
/// unreachable, and this is where that is checked.
@Suite("TimeOfDayChartModel")
struct TimeOfDayChartModelTests {
    @Test("every measured bucket becomes one bar, in the analysis's order")
    func everyMeasuredBucketBecomesOneBar() {
        let model = barChartModelOf(
            breakdown: breakdown(
                stats(.morning, count: 3, primary: 130.0, secondary: 85.0),
                stats(.midday, count: 2, primary: 126.0, secondary: 82.0),
                stats(.evening, count: 4, primary: 138.0, secondary: 88.0),
                stats(.night, count: 1, primary: 120.0, secondary: 78.0)
            ),
            partLabel: labelOf,
            displayValue: asStored,
            axisLabel: wholeTick
        )

        #expect(model?.bars.map(\.label) == ["MORNING", "MIDDAY", "EVENING", "NIGHT"])
        #expect(model?.bars.map(\.value) == [130, 126, 138, 120])
        #expect(model?.bars.map(\.secondaryValue) == [85, 82, 88, 78])
    }

    @Test("a bucket with no measurement produces no bar at all")
    func bucketWithNoMeasurementProducesNoBar() {
        // No zero-height placeholder: nobody's blood pressure is 0, and a fabricated value on a
        // health screen is worse than a missing column.
        let model = barChartModelOf(
            breakdown: breakdown(
                stats(.morning, count: 3, primary: 130.0, secondary: 85.0),
                stats(.midday, count: 0, primary: nil, secondary: nil),
                stats(.evening, count: 4, primary: 138.0, secondary: 88.0),
                stats(.night, count: 1, primary: 120.0, secondary: 78.0)
            ),
            partLabel: labelOf,
            displayValue: asStored,
            axisLabel: wholeTick
        )

        #expect(model?.bars.map(\.label) == ["MORNING", "EVENING", "NIGHT"])
        #expect(model?.bars.allSatisfy { $0.secondaryValue != nil } == true)
    }

    @Test("one bar missing its second value drops the second series entirely")
    func oneBarMissingSecondValueDropsSecondSeries() {
        // This is the whole point of the rule: a second series covering three of four columns
        // would leave the grouped column layer to decide what a gap means. Systolic alone is
        // still an honest chart.
        let model = barChartModelOf(
            breakdown: breakdown(
                stats(.morning, count: 3, primary: 130.0, secondary: 85.0),
                stats(.midday, count: 2, primary: 126.0, secondary: nil),
                stats(.evening, count: 4, primary: 138.0, secondary: 88.0),
                stats(.night, count: 1, primary: 120.0, secondary: 78.0)
            ),
            partLabel: labelOf,
            displayValue: asStored,
            axisLabel: wholeTick
        )

        #expect(model?.bars.count == 4)
        #expect(model?.bars.allSatisfy { $0.secondaryValue == nil } == true)
    }

    @Test("a metric with no second value is a single series")
    func metricWithNoSecondValueIsSingleSeries() {
        // Glucose. Nothing is missing here — there simply is no second number to draw.
        let model = barChartModelOf(
            breakdown: breakdown(
                stats(.morning, count: 3, primary: 104.0, secondary: nil),
                stats(.midday, count: 0, primary: nil, secondary: nil),
                stats(.evening, count: 0, primary: nil, secondary: nil),
                stats(.night, count: 2, primary: 118.0, secondary: nil),
                type: .bloodGlucose
            ),
            partLabel: labelOf,
            displayValue: asStored,
            axisLabel: wholeTick
        )

        #expect(model?.bars.map(\.label) == ["MORNING", "NIGHT"])
        #expect(model?.bars.allSatisfy { $0.secondaryValue == nil } == true)
    }

    @Test("a breakdown with nothing measured in it produces no model")
    func breakdownWithNothingMeasuredProducesNoModel() {
        // Unreachable through the repository — a breakdown only exists when the metric was
        // logged — but answered rather than assumed, and answered the same way the screen
        // already hides the card: with nil.
        let model = barChartModelOf(
            breakdown: breakdown(
                stats(.morning, count: 0, primary: nil, secondary: nil),
                stats(.midday, count: 0, primary: nil, secondary: nil),
                stats(.evening, count: 0, primary: nil, secondary: nil),
                stats(.night, count: 0, primary: nil, secondary: nil)
            ),
            partLabel: labelOf,
            displayValue: asStored,
            axisLabel: wholeTick
        )

        #expect(model == nil)
    }

    @Test("the axis formatter is the caller's, carried through untouched")
    func axisFormatterIsTheCallers() {
        // The mapping does not invent an axis format of its own. It cannot: the unit decides
        // how many decimals a tick carries, and only the caller knows which unit was chosen.
        let model = barChartModelOf(
            breakdown: breakdown(stats(.morning, count: 3, primary: 129.6, secondary: 84.4)),
            partLabel: labelOf,
            displayValue: asStored,
            axisLabel: wholeTick
        )

        #expect(model?.yLabel(129.6) == wholeTick(129.6))
        #expect(model?.yLabel(129.6) == "130")
    }

    @Test("glucose bars and their axis are both in the unit the reader chose")
    func glucoseBarsAndAxisInChosenUnit() throws {
        // The averages arrive in canonical mg/dL; a reader on mmol/L must get converted bars
        // *and* an axis in the same unit — bars in one unit under ticks in another is a chart
        // that reads as a wrong value rather than as a bug.
        let maybeModel = barChartModelOf(
            breakdown: breakdown(
                stats(.morning, count: 3, primary: 104.0, secondary: nil),
                stats(.midday, count: 0, primary: nil, secondary: nil),
                stats(.evening, count: 0, primary: nil, secondary: nil),
                stats(.night, count: 2, primary: 90.0, secondary: nil),
                type: .bloodGlucose
            ),
            partLabel: labelOf,
            displayValue: { MetricDisplay.value(type: .bloodGlucose, stored: $0, glucoseUnit: .mmolL) },
            axisLabel: { MetricDisplay.write(converted: Double($0), decimals: 1, locale: Locale(identifier: "en_US")) }
        )
        let model = try #require(maybeModel)
        let first = try #require(model.bars.first?.value)
        let last = try #require(model.bars.last?.value)

        // 104 / 18.0182 is 5.7719…, 90 / 18.0182 is 4.9949… — not the stored numbers.
        #expect(abs(first - 5.7719) < tolerance)
        #expect(abs(last - 4.9949) < tolerance)
        #expect(model.yLabel(first) == "5.8")
    }

    @Test("a reader on mg per dL sees the stored numbers, unconverted")
    func readerOnMgPerDlSeesStoredNumbers() throws {
        // The identity conversion is now something a caller states, not something it inherits
        // by leaving an argument off.
        let maybeModel = barChartModelOf(
            breakdown: breakdown(
                stats(.morning, count: 3, primary: 104.0, secondary: nil),
                type: .bloodGlucose
            ),
            partLabel: labelOf,
            displayValue: { MetricDisplay.value(type: .bloodGlucose, stored: $0, glucoseUnit: .mgDl) },
            axisLabel: { MetricDisplay.write(converted: Double($0), decimals: 0) }
        )
        let model = try #require(maybeModel)
        let first = try #require(model.bars.first?.value)

        #expect(abs(first - 104) < tolerance)
        #expect(model.yLabel(first) == "104")
    }

    // MARK: - Fixtures

    private func labelOf(_ part: DayPart) -> String {
        switch part {
        case .morning: "MORNING"
        case .midday: "MIDDAY"
        case .evening: "EVENING"
        case .night: "NIGHT"
        }
    }

    /// A reader whose chosen unit is the stored one: blood pressure, or glucose in mg/dL.
    private func asStored(_ stored: Double) -> Double {
        stored
    }

    /// The tick format that unit is written with.
    private func wholeTick(_ value: Float) -> String {
        String(Int(value.rounded()))
    }

    private func stats(
        _ part: DayPart,
        count: Int,
        primary: Double?,
        secondary: Double?
    ) -> DayPartStats {
        DayPartStats(part: part, count: count, primaryAverage: primary, secondaryAverage: secondary)
    }

    private func breakdown(
        _ parts: DayPartStats...,
        type: VitalType = .bloodPressure
    ) -> TimeOfDayBreakdown {
        TimeOfDayBreakdown(type: type, parts: parts)
    }
}

private let tolerance: Float = 0.0001
