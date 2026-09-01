// Ported from Android
// `feature/trends/src/test/kotlin/com/alicansekban/salus/feature/trends/analysis/OverlayTest.kt`.

import SalusModel
import Testing

@testable import FeatureTrends

/// The overlay analysis: several metrics, different units, one shared 0...1 axis (`OverlayTest.kt`).
///
/// The rules worth pinning down are the ones a reader cannot verify by eye on a device. A
/// normalized chart hides its own arithmetic — every series ends up between the top and the
/// bottom of the same box whatever the numbers were — so if the scaling is wrong, the picture
/// still looks plausible. These tests are the only place that is checked.
@Suite("Overlay")
struct OverlayTests {
    @Test("several readings on one day are that day's average, not several points")
    func severalReadingsOnOneDayAreThatDaysAverage() {
        // A day with three readings would otherwise crowd the line with vertical noise that
        // says nothing about the trend across days, which is what this chart is for.
        let overlay = metricOverlayOf(
            [
                measurement(epochDay: day, primary: 100.0),
                measurement(epochDay: day, primary: 140.0),
                measurement(epochDay: day + 1, primary: 180.0)
            ],
            days: window
        )

        let points = overlay.series.single().points
        #expect(points.count == 2)
        // 100 and 140 average to 120, the low end of the 120..180 range, so it lands at 0.
        #expect(points.first?.xEpochDay == day)
        #expect(abs((points.first?.y ?? 0) - 0) < tolerance)
        #expect(abs((points.last?.y ?? 0) - 1) < tolerance)
    }

    @Test("a value sits where it falls between the series' own minimum and maximum")
    func valueSitsWhereItFallsBetweenMinAndMax() {
        let overlay = metricOverlayOf(
            [
                measurement(epochDay: day, primary: 100.0),
                measurement(epochDay: day + 1, primary: 125.0),
                measurement(epochDay: day + 2, primary: 200.0)
            ],
            days: window
        )

        let series = overlay.series.single()
        #expect(series.min == 100.0)
        #expect(series.max == 200.0)
        // (125 - 100) / (200 - 100).
        #expect(abs((series.points[1].y) - 0.25) < tolerance)
    }

    @Test("points come back in day order, whatever order they were logged in")
    func pointsComeBackInDayOrder() {
        // The chart draws a line through them in the order it is given; unsorted input would
        // draw a zigzag back and forth across the window.
        let overlay = metricOverlayOf(
            [
                measurement(epochDay: day + 2, primary: 120.0),
                measurement(epochDay: day, primary: 100.0),
                measurement(epochDay: day + 1, primary: 110.0)
            ],
            days: window
        )

        #expect(overlay.series.single().points.map(\.xEpochDay) == [day, day + 1, day + 2])
    }

    @Test("a metric whose values never move is drawn down the middle, not divided by zero")
    func metricWhoseValuesNeverMoveIsDrawnDownTheMiddle() {
        // min == max makes the span zero. Half height is the honest answer: the series has no
        // spread of its own to show, and the legend still carries the real value.
        let overlay = metricOverlayOf(
            [
                measurement(epochDay: day, primary: 120.0),
                measurement(epochDay: day + 1, primary: 120.0)
            ],
            days: window
        )

        let series = overlay.series.single()
        #expect(series.points.allSatisfy { $0.y == 0.5 })
        #expect(series.min == 120.0)
        #expect(series.max == 120.0)
    }

    @Test("a metric measured once is also drawn down the middle")
    func metricMeasuredOnceIsDrawnDownTheMiddle() {
        // The single-point case is the same degenerate span, reached by a much likelier route.
        let overlay = metricOverlayOf(
            [measurement(epochDay: day, primary: 98.0)],
            days: window
        )

        #expect(abs(overlay.series.single().points.single().y - 0.5) < tolerance)
    }

    @Test("a metric with no measurement in the window is not a series at all")
    func metricWithNoMeasurementInWindowIsNotASeries() {
        // Not an empty line at the bottom of the chart: a metric nobody logged has no place
        // in a legend that promises a real minimum and maximum for every entry.
        let overlay = metricOverlayOf(
            [measurement(epochDay: day, type: .weight, primary: 70.0)],
            days: window
        )

        #expect(overlay.series.map(\.type) == [.weight])
    }

    @Test("series come back in VitalType order, whatever order the records arrived in")
    func seriesComeBackInVitalTypeOrder() {
        // A stable order is what keeps a metric's colour from changing between two loads of
        // the same screen.
        let overlay = metricOverlayOf(
            [
                measurement(epochDay: day, type: .bloodGlucose, primary: 95.0),
                measurement(epochDay: day, type: .weight, primary: 70.0),
                measurement(epochDay: day, type: .bloodPressure, primary: 130.0)
            ],
            days: window
        )

        #expect(overlay.series.map(\.type) == VitalType.allCases)
    }

    @Test("a measurement outside the window is dropped before anything is scaled")
    func measurementOutsideWindowIsDropped() {
        // The window is the question the user asked. A stray older reading that happened to be
        // the lowest ever would otherwise pull the whole series' scale down with it.
        let overlay = metricOverlayOf(
            [
                measurement(epochDay: window.lowerBound - 1, primary: 60.0),
                measurement(epochDay: day, primary: 120.0),
                measurement(epochDay: window.upperBound + 1, primary: 220.0)
            ],
            days: window
        )

        let series = overlay.series.single()
        #expect(series.points.map(\.xEpochDay) == [day])
        #expect(series.min == 120.0)
    }

    @Test("blood pressure is drawn from its systolic number")
    func bloodPressureIsDrawnFromSystolic() {
        // `primary` is systolic and `secondary` is diastolic. One line per metric is the whole
        // point of this card, so the pair has to be reduced to one number, and systolic is the
        // one a blood pressure reading is named by.
        let overlay = metricOverlayOf(
            [
                measurement(
                    epochDay: day,
                    type: .bloodPressure,
                    primary: 130.0,
                    secondary: 85.0
                ),
                measurement(
                    epochDay: day + 1,
                    type: .bloodPressure,
                    primary: 150.0,
                    secondary: 95.0
                )
            ],
            days: window
        )

        let series = overlay.series.single()
        #expect(series.min == 130.0)
        #expect(series.max == 150.0)
    }

    @Test("one metric on its own is nothing to overlay")
    func oneMetricOnItsOwnIsNothingToOverlay() {
        // Laying a metric over itself shows nothing the vitals screen does not already show,
        // and nil is what leaves the card out rather than drawing a one-line chart with a
        // normalized axis nobody can read a number off.
        #expect(metricOverlayOrNull([measurement(epochDay: day, primary: 120.0)], days: window) == nil)
    }

    @Test("two metrics are enough to be worth overlaying")
    func twoMetricsAreEnoughToOverlay() {
        let overlay = metricOverlayOrNull(
            [
                measurement(epochDay: day, type: .bloodPressure, primary: 130.0),
                measurement(epochDay: day, type: .weight, primary: 70.0)
            ],
            days: window
        )

        #expect(overlay?.series.count == 2)
    }

    @Test("an empty window is nothing to overlay either")
    func emptyWindowIsNothingToOverlay() {
        #expect(metricOverlayOrNull([], days: window) == nil)
    }

    @Test("a window of a month or less keeps a point per day")
    func windowOfMonthOrLessKeepsPointPerDay() {
        let overlay = metricOverlayOf(
            (0 ..< 31).map { offset in measurement(epochDay: monday + offset, primary: 120.0 + Double(offset)) },
            days: monday ... (monday + 30)
        )

        #expect(overlay.bucket == .daily)
        #expect(overlay.series.single().points.count == 31)
    }

    @Test("a window longer than a month collapses to a point per week")
    func windowLongerThanMonthCollapsesToPointPerWeek() {
        // 35 days is five whole weeks starting on a Monday, so the count is exact rather than
        // dependent on where the window happens to fall.
        let overlay = metricOverlayOf(
            (0 ..< 35).map { offset in measurement(epochDay: monday + offset, primary: 120.0) },
            days: monday ... (monday + 34)
        )

        #expect(overlay.bucket == .weekly)
        let points = overlay.series.single().points
        #expect(points.count == 5)
        // Every point is stamped with the Monday its week starts on, so the axis labels a real
        // date rather than the middle of a bucket.
        #expect(points.map(\.xEpochDay) == [monday, monday + 7, monday + 14, monday + 21, monday + 28])
    }

    @Test("a weekly point averages the days, so a heavily measured day cannot outweigh a quiet one")
    func weeklyPointAveragesTheDays() {
        // Week one: a single 100 on Monday, then a Tuesday measured three times at 160 each.
        // Averaging the readings would give 145; averaging the days gives 130, which is what a
        // chart comparing weeks has to say.
        let week = [
            measurement(epochDay: monday, primary: 100.0),
            measurement(epochDay: monday + 1, primary: 160.0),
            measurement(epochDay: monday + 1, primary: 160.0),
            measurement(epochDay: monday + 1, primary: 160.0)
        ]
        let laterWeeks = (14 ..< 35).map { offset in measurement(epochDay: monday + offset, primary: 200.0) }

        let overlay = metricOverlayOf(week + laterWeeks, days: monday ... (monday + 34))

        #expect(overlay.series.single().min == 130.0)
    }

    @Test("min and max describe the weekly averages that are drawn, not the raw readings")
    func minAndMaxDescribeDrawnWeeklyAverages() {
        let overlay = metricOverlayOf(
            [
                measurement(epochDay: monday, primary: 100.0),
                measurement(epochDay: monday + 1, primary: 200.0)
            ] + (7 ..< 35).map { offset in measurement(epochDay: monday + offset, primary: 150.0) },
            days: monday ... (monday + 34)
        )

        // The raw readings run 100..200, but every plotted point is a weekly average of 150.
        let series = overlay.series.single()
        #expect(series.min == 150.0)
        #expect(series.max == 150.0)
        #expect(series.points.allSatisfy { $0.y == 0.5 })
    }

    // MARK: - Fixtures

    private func measurement(
        epochDay: Int,
        type: VitalType = .bloodPressure,
        primary: Double = 120.0,
        secondary: Double? = nil
    ) -> TrendMeasurement {
        TrendMeasurement(
            type: type,
            epochDay: epochDay,
            minuteOfDay: morningMinute,
            primary: primary,
            secondary: secondary,
            tertiary: nil
        )
    }
}

private let day = 20000
private let window = (day - 10) ... (day + 10)
private let morningMinute = 8 * 60
private let tolerance: Float = 0.0001

/// Epoch day 20_003 is a Monday, so a week bucket starts exactly here.
private let monday = 20003

extension Collection {
    fileprivate func single() -> Element {
        precondition(count == 1, "expected exactly one element, found \(count)")
        // swiftlint:disable:next force_unwrapping
        return first!
    }
}
