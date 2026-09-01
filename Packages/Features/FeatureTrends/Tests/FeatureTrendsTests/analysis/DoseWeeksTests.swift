// Ported from Android
// `feature/trends/src/test/kotlin/com/alicansekban/salus/feature/trends/analysis/DoseWeeksTest.kt`.

import SalusModel
import Testing

@testable import FeatureTrends

/// The weekly dose analysis: what share of the doses a week *recorded* were marked taken, next to
/// that week's measurement averages (`DoseWeeksTest.kt`).
///
/// Two families of rule are pinned here, and neither can be checked by looking at a device.
///
/// The first is the week grid. Epoch day 0 is a Thursday, so a Monday-start week is an off-by-a
/// few-days calculation that looks right in every spot check made on a Monday and is wrong for
/// the other six days. It is fixed by arithmetic here instead.
///
/// The second is what an absent number means. A week with no logged dose has no ratio — not a
/// ratio of zero — and a week with no reading has no average. Drawing a zero for either would
/// invent a fact about a week the user simply did not record.
@Suite("DoseWeeks")
struct DoseWeeksTests {
    @Test("the week of epoch day zero starts on the Monday before it")
    func weekOfEpochDayZeroStartsOnMondayBeforeIt() {
        // Epoch day 0 is Thursday 1970-01-01, so its week began on 1969-12-29 — day -3.
        #expect(weekStartOf(0) == -3)
    }

    @Test("every day of one week reports the same start")
    func everyDayOfOneWeekReportsTheSameStart() {
        let starts = (0 ..< daysInWeek).map { offset in weekStartOf(monday + offset) }

        #expect(Set(starts) == [monday])
        // And the next day is already the following week, so the buckets do not overlap.
        #expect(weekStartOf(monday + daysInWeek) == monday + daysInWeek)
    }

    @Test("weeks come back oldest first, whatever order the records were logged in")
    func weeksComeBackOldestFirst() {
        let weeks = doseWeeksOf(
            doses: [
                dose(epochDay: monday + daysInWeek, taken: true),
                dose(epochDay: monday, taken: true)
            ],
            measurements: [],
            days: twoWeeks
        )

        #expect(weeks.map(\.startEpochDay) == [monday, monday + daysInWeek])
    }

    @Test("taken counts only the doses marked taken and never exceeds the logged ones")
    func takenCountsOnlyMarkedTakenAndNeverExceedsLogged() {
        let weeks = doseWeeksOf(
            doses: [
                dose(epochDay: monday, taken: true),
                dose(epochDay: monday + 1, taken: false),
                dose(epochDay: monday + 2, taken: true)
            ],
            measurements: [],
            days: twoWeeks
        )

        let first = weeks.first
        #expect(first?.loggedDoses == 3)
        #expect(first?.takenDoses == 2)
        #expect(weeks.allSatisfy { $0.takenDoses <= $0.loggedDoses })
    }

    @Test("a week with no logged dose has no ratio at all")
    func weekWithNoLoggedDoseHasNoRatio() {
        // Not zero: nothing was recorded, so there is no share to report. A zero bar would read
        // as a week of missed doses, which is a different claim entirely.
        let weeks = doseWeeksOf(
            doses: [dose(epochDay: monday + daysInWeek, taken: true)],
            measurements: [],
            days: twoWeeks
        )

        #expect(weeks.first?.loggedDoses == 0)
        #expect(weeks.first?.takenPercent == nil)
        #expect(weeks.last?.takenPercent == 100)
    }

    @Test("the ratio is rounded to the nearest whole percent")
    func ratioIsRoundedToNearestWholePercent() {
        // Two of three is 66.67, which reads as 67. Truncating would report 66 and quietly
        // under-state every week that does not divide evenly.
        let weeks = doseWeeksOf(
            doses: [
                dose(epochDay: monday, taken: true),
                dose(epochDay: monday, taken: true),
                dose(epochDay: monday, taken: false)
            ],
            measurements: [],
            days: twoWeeks
        )

        #expect(weeks.first?.takenPercent == 67)
    }

    @Test("a week's averages are that week's readings, by metric")
    func weeksAveragesAreThatWeeksReadingsByMetric() {
        let weeks = doseWeeksOf(
            doses: [dose(epochDay: monday, taken: true)],
            measurements: [
                measurement(.bloodPressure, monday, primary: 120.0),
                measurement(.bloodPressure, monday + 1, primary: 140.0),
                measurement(.bloodGlucose, monday + 2, primary: 100.0),
                // Next week, so it must not move this week's numbers.
                measurement(.bloodPressure, monday + daysInWeek, primary: 200.0)
            ],
            days: twoWeeks
        )

        let first = weeks.first
        #expect(abs((first?.systolicAverage ?? 0) - 130.0) < tolerance)
        #expect(abs((first?.glucoseAverage ?? 0) - 100.0) < tolerance)
        #expect(abs((weeks.last?.systolicAverage ?? 0) - 200.0) < tolerance)
    }

    @Test("a week with no reading of a metric has no average for it")
    func weekWithNoReadingOfMetricHasNoAverage() {
        let weeks = doseWeeksOf(
            doses: [dose(epochDay: monday, taken: true)],
            measurements: [measurement(.weight, monday, primary: 70.0)],
            days: twoWeeks
        )

        // Weight is not one of the two metrics this card pairs the ratio with, so neither
        // average is filled — and neither is zero.
        #expect(weeks.first?.systolicAverage == nil)
        #expect(weeks.first?.glucoseAverage == nil)
    }

    @Test("a partial week at either end of the window is kept")
    func partialWeekAtEitherEndIsKept() {
        // The window starts on a Wednesday and ends on the Wednesday after: both edge weeks are
        // partial, and dropping them would hide records the user asked about.
        let days = (monday + 2) ... (monday + daysInWeek + 2)
        let weeks: [DoseWeek] = doseWeeksOf(
            doses: [
                dose(epochDay: monday + 2, taken: true),
                dose(epochDay: monday + daysInWeek + 2, taken: false)
            ],
            measurements: [],
            days: days
        )

        #expect(weeks.map(\.startEpochDay) == [monday, monday + daysInWeek])
        #expect(weeks.first?.takenPercent == 100)
        #expect(weeks.last?.takenPercent == 0)
    }

    @Test("records outside the window are not counted")
    func recordsOutsideWindowAreNotCounted() {
        let weeks = doseWeeksOf(
            doses: [
                dose(epochDay: monday - 1, taken: false),
                dose(epochDay: monday, taken: true),
                dose(epochDay: monday + daysInWeek, taken: false)
            ],
            measurements: [
                measurement(.bloodPressure, monday - 1, primary: 200.0)
            ],
            days: monday ... (monday + 1)
        )

        let onlyWeek = weeks.single()
        #expect(onlyWeek.startEpochDay == monday)
        #expect(onlyWeek.loggedDoses == 1)
        #expect(onlyWeek.takenPercent == 100)
        #expect(onlyWeek.systolicAverage == nil)
    }

    @Test("there is no card when the window logged no dose at all")
    func noCardWhenWindowLoggedNoDose() {
        // Measurements alone say nothing about doses, so the card is absent rather than a chart
        // of empty weeks.
        #expect(doseWeeksOrNull(
            doses: [],
            measurements: [measurement(.bloodPressure, monday, primary: 120.0)],
            days: twoWeeks
        ) == nil)
    }

    @Test("one logged dose is enough for a card")
    func oneLoggedDoseIsEnoughForACard() {
        let weeks = doseWeeksOrNull(
            doses: [dose(epochDay: monday, taken: false)],
            measurements: [],
            days: twoWeeks
        )

        #expect(weeks?.first?.takenPercent == 0)
    }

    // MARK: - Fixtures

    private func dose(epochDay: Int, taken: Bool) -> TrendDose {
        TrendDose(epochDay: epochDay, taken: taken)
    }

    private func measurement(
        _ type: VitalType,
        _ epochDay: Int,
        primary: Double
    ) -> TrendMeasurement {
        TrendMeasurement(
            type: type,
            epochDay: epochDay,
            minuteOfDay: noon,
            primary: primary,
            secondary: nil,
            tertiary: nil
        )
    }
}

/// Monday 2026-08-03, so every offset in these tests lands on a known weekday.
private let monday = 20668
private let daysInWeek = 7
private let noon = 720
private let tolerance = 0.0001
private let twoWeeks = monday ... (monday + 2 * daysInWeek - 1)

extension Collection {
    fileprivate func single() -> Element {
        precondition(count == 1, "expected exactly one element, found \(count)")
        // swiftlint:disable:next force_unwrapping
        return first!
    }
}
