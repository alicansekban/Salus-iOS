// Ported from Android
// `feature/trends/src/test/kotlin/com/alicansekban/salus/feature/trends/analysis/SummariesTest.kt`.

import SalusModel
import Testing

@testable import FeatureTrends

/// The metric summary: what each metric amounted to in the window, and how its average moved
/// against the window immediately before it (`SummariesTest.kt`).
///
/// Three families of rule are pinned here, and none of them can be checked by looking at a device.
///
/// The first is what an absent number means. A metric nobody measured has no row at all rather
/// than a row of zeros, and a metric measured only in the current window has no previous stats
/// and no change — not a change of zero, which would be the claim that it held still.
///
/// The second is the division. A percentage change divides by the earlier average, and the one
/// value that cannot be divided by is the one a total function still has to answer for.
///
/// The third is order. The trend of a series is read off its first half against its last half, so
/// a summary built from records in the order the database happened to return them would report a
/// direction that depends on a sort nobody promised.
@Suite("Summaries")
struct SummariesTests {
    @Test("a metric with no reading in the window has no row at all")
    func metricWithNoReadingHasNoRow() {
        let summaries = metricSummariesOf(
            current: [reading(.weight, day: 1, primary: 72.0)],
            previous: []
        )

        #expect(summaries.items.map(\.type) == [.weight])
    }

    @Test("rows come back in VitalType order, whatever order the records were logged in")
    func rowsComeBackInVitalTypeOrder() {
        // The order is what keeps a metric in the same place between two loads of the same
        // screen; taking it from the records would move rows around as readings arrive.
        let summaries = metricSummariesOf(
            current: [
                reading(.bloodGlucose, day: 1, primary: 104.0),
                reading(.weight, day: 1, primary: 72.0),
                reading(.bloodPressure, day: 1, primary: 128.0, secondary: 82.0)
            ],
            previous: []
        )

        #expect(summaries.items.map(\.type) == [.weight, .bloodPressure, .bloodGlucose])
    }

    @Test("a metric absent from the previous window has no previous stats and no change")
    func metricAbsentFromPreviousWindowHasNoChange() {
        let summaries = metricSummariesOf(
            current: [reading(.weight, day: 1, primary: 72.0)],
            previous: [reading(.bloodGlucose, day: -30, primary: 104.0)]
        )

        // The list itself is the first claim: a metric measured only in the earlier window
        // gets no row, because a row for it would have to fabricate a `current` it never had.
        #expect(summaries.items.map(\.type) == [.weight])
        let weight = summaries.items.single()
        #expect(weight.previous == nil)
        #expect(weight.changePercent == nil)
    }

    @Test("a previous average of zero produces no change rather than a division")
    func previousAverageOfZeroProducesNoChange() {
        // Not a reading any of these metrics can really take, but the function is total and a
        // division by zero here would be an infinity written onto the screen as a percentage.
        let summaries = metricSummariesOf(
            current: [reading(.weight, day: 1, primary: 72.0)],
            previous: [reading(.weight, day: -30, primary: 0.0)]
        )

        let weight = summaries.items.single()
        #expect(weight.previous != nil)
        #expect(weight.changePercent == nil)
    }

    @Test("an average of eighty rising to eighty-eight is a ten percent change")
    func eightyRisingToEightyEightIsTenPercent() {
        let summaries = metricSummariesOf(
            current: [reading(.bloodGlucose, day: 1, primary: 88.0)],
            previous: [reading(.bloodGlucose, day: -30, primary: 80.0)]
        )

        #expect(abs((summaries.items.single().changePercent ?? 0) - 10.0) < tolerance)
    }

    @Test("a fall against the previous window is a negative change")
    func fallAgainstPreviousWindowIsNegative() {
        let summaries = metricSummariesOf(
            current: [reading(.bloodGlucose, day: 1, primary: 90.0)],
            previous: [reading(.bloodGlucose, day: -30, primary: 100.0)]
        )

        #expect(abs((summaries.items.single().changePercent ?? 0) - -10.0) < tolerance)
    }

    @Test("blood pressure is summarised on its systolic number")
    func bloodPressureIsSummarisedOnSystolic() {
        // Diastolic is carried on the same record, so a summary that read the wrong field would
        // still produce plausible numbers — which is exactly why it is asserted rather than
        // assumed.
        let summaries = metricSummariesOf(
            current: [
                reading(.bloodPressure, day: 1, primary: 130.0, secondary: 84.0),
                reading(.bloodPressure, day: 2, primary: 126.0, secondary: 80.0)
            ],
            previous: []
        )

        let pressure = summaries.items.single()
        #expect(abs(pressure.current.average - 128.0) < tolerance)
        #expect(abs(pressure.current.min - 126.0) < tolerance)
        #expect(abs(pressure.current.max - 130.0) < tolerance)
        #expect(pressure.current.count == 2)
    }

    @Test("a window with no measurement at all has no summaries to carry")
    func windowWithNoMeasurementHasNoSummaries() {
        // Null rather than an empty list, so the screen physically cannot draw an empty card —
        // the same shape the other three analyses answer with.
        #expect(metricSummariesOrNull(current: [], previous: []) == nil)
    }

    @Test("a window with a measurement carries summaries")
    func windowWithMeasurementCarriesSummaries() {
        let summaries = metricSummariesOrNull(
            current: [reading(.weight, day: 1, primary: 72.0)],
            previous: []
        )

        #expect(summaries?.items.isEmpty == false)
    }

    // MARK: - Fixtures

    private func reading(
        _ type: VitalType,
        day: Int,
        primary: Double,
        minuteOfDay: Int = 8 * 60,
        secondary: Double? = nil
    ) -> TrendMeasurement {
        TrendMeasurement(
            type: type,
            epochDay: day,
            minuteOfDay: minuteOfDay,
            primary: primary,
            secondary: secondary,
            tertiary: nil
        )
    }
}

private let tolerance = 0.0001

extension Collection {
    fileprivate func single() -> Element {
        precondition(count == 1, "expected exactly one element, found \(count)")
        // swiftlint:disable:next force_unwrapping
        return first!
    }
}
