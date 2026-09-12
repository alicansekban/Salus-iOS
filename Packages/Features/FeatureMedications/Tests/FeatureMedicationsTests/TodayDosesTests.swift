// Ported from `feature/medications/src/test/kotlin/com/alicansekban/salus/feature/medications/
// domain/TodayDosesTest.kt` — all seven cases, by name, in the Kotlin order.
//
// PURE SWIFT, like the type under test: no clock, no fake repository, no `waitUntil`. The cases
// that matter are the ones on the day boundary — `TodayDoses.of` is told which day it is
// summarising, so a caller that keeps a stale day gets a perfectly consistent answer about the
// WRONG day. That is what makes the per-emission clock read in `MedicationsViewModel` /
// `MedicationDetailViewModel` load-bearing: the dose this type hands back is what the "take now"
// button writes into a health record.

import SalusModel
import Testing

@testable import FeatureMedications

@Suite("TodayDoses")
struct TodayDosesTests {
    /// `TodayDosesTest.kt:24-25`.
    private static let day = 20000
    private static let morning = 8 * 60

    /// `TodayDosesTest.kt:27-40`.
    @Test("the summary is about the day it is asked for, not the day the logs carry")
    func theSummaryIsAboutTheDayItIsAskedForNotTheDayTheLogsCarry() {
        let logs = [Self.log(epochDay: Self.day, status: .taken)]

        let onThatDay = TodayDoses.of(
            medication: Self.daily(),
            logs: logs,
            todayEpochDay: Self.day,
            nowMinuteOfDay: 12 * 60
        )
        #expect(onThatDay.status == .taken)
        #expect(onThatDay.dueDose == nil)

        // Same rows, one day later: yesterday's record settles nothing today, so the slot is
        // outstanding again and the dose offered belongs to the NEW day.
        let nextDay = TodayDoses.of(
            medication: Self.daily(),
            logs: logs,
            todayEpochDay: Self.day + 1,
            nowMinuteOfDay: 9 * 60
        )
        #expect(nextDay.status == .pending)
        #expect(nextDay.dueDose == PendingDose(scheduleId: "sch-1", epochDay: Self.day + 1, minuteOfDay: Self.morning))
    }

    /// `TodayDosesTest.kt:42-49`.
    @Test("a dose whose minute has not come yet is the next one but is not due")
    func aDoseWhoseMinuteHasNotComeYetIsTheNextOneButIsNotDue() {
        let summary = TodayDoses.of(
            medication: Self.daily(),
            logs: [],
            todayEpochDay: Self.day,
            nowMinuteOfDay: 7 * 60
        )

        #expect(summary.status == .pending)
        #expect(summary.nextDoseMinuteOfDay == Self.morning)
        #expect(summary.dueDose == nil)
    }

    /// `TodayDosesTest.kt:51-56`.
    @Test("a dose is due from its own minute on")
    func aDoseIsDueFromItsOwnMinuteOn() {
        let summary = TodayDoses.of(
            medication: Self.daily(),
            logs: [],
            todayEpochDay: Self.day,
            nowMinuteOfDay: Self.morning
        )

        #expect(summary.dueDose == PendingDose(scheduleId: "sch-1", epochDay: Self.day, minuteOfDay: Self.morning))
    }

    /// `TodayDosesTest.kt:58-67`.
    @Test("a snoozed dose stays outstanding")
    func aSnoozedDoseStaysOutstanding() {
        // A snooze writes PENDING, which records an intention rather than settling the dose.
        let logs = [Self.log(epochDay: Self.day, status: .pending)]

        let summary = TodayDoses.of(
            medication: Self.daily(),
            logs: logs,
            todayEpochDay: Self.day,
            nowMinuteOfDay: 12 * 60
        )

        #expect(summary.status == .pending)
        #expect(summary.dueDose == PendingDose(scheduleId: "sch-1", epochDay: Self.day, minuteOfDay: Self.morning))
    }

    /// `TodayDosesTest.kt:69-88`.
    @Test("the last settled dose of the day is what the status reports")
    func theLastSettledDoseOfTheDayIsWhatTheStatusReports() {
        let medication = MedicationWithSchedules(
            medication: testMedication(startDateEpochDay: Self.day - 10),
            schedules: [
                testSchedule(id: "sch-1", anchorDateEpochDay: Self.day - 10, timeOfDayMinutes: Self.morning),
                testSchedule(id: "sch-2", anchorDateEpochDay: Self.day - 10, timeOfDayMinutes: 20 * 60)
            ]
        )
        let logs = [
            Self.log(epochDay: Self.day, status: .taken),
            Self.log(epochDay: Self.day, status: .skipped, scheduleId: "sch-2", minuteOfDay: 20 * 60)
        ]

        let summary = TodayDoses.of(
            medication: medication,
            logs: logs,
            todayEpochDay: Self.day,
            nowMinuteOfDay: 22 * 60
        )

        #expect(summary.status == .skipped)
        #expect(summary.nextDoseMinuteOfDay == nil)
        #expect(summary.dueDose == nil)
    }

    /// `TodayDosesTest.kt:90-108`.
    @Test("an as-needed medication has no slots to miss")
    func anAsNeededMedicationHasNoSlotsToMiss() {
        let medication = MedicationWithSchedules(
            medication: testMedication(startDateEpochDay: Self.day - 10),
            schedules: [
                testSchedule(
                    recurrence: .asNeeded,
                    anchorDateEpochDay: Self.day - 10,
                    timeOfDayMinutes: 0
                )
            ]
        )

        let summary = TodayDoses.of(
            medication: medication,
            logs: [],
            todayEpochDay: Self.day,
            nowMinuteOfDay: 12 * 60
        )

        #expect(summary.status == .asNeeded)
        #expect(summary.nextDoseMinuteOfDay == nil)
        #expect(summary.dueDose == nil)
    }

    /// `TodayDosesTest.kt:110-131`.
    @Test("a day the schedule does not fire on has no status at all")
    func aDayTheScheduleDoesNotFireOnHasNoStatusAtAll() {
        let medication = MedicationWithSchedules(
            medication: testMedication(startDateEpochDay: Self.day - 10),
            schedules: [
                testSchedule(
                    recurrence: .intervalDays,
                    intervalDays: 2,
                    anchorDateEpochDay: Self.day,
                    timeOfDayMinutes: Self.morning
                )
            ]
        )

        // The day after an every-other-day injection: no slot, so nothing to report and nothing to
        // offer — not a pending card the user could record.
        let summary = TodayDoses.of(
            medication: medication,
            logs: [],
            todayEpochDay: Self.day + 1,
            nowMinuteOfDay: 12 * 60
        )

        #expect(summary.status == nil)
        #expect(summary.nextDoseMinuteOfDay == nil)
        #expect(summary.dueDose == nil)
    }

    /// `TodayDosesTest.kt:133-136`.
    private static func daily() -> MedicationWithSchedules {
        MedicationWithSchedules(
            medication: testMedication(startDateEpochDay: day - 10),
            schedules: [testSchedule(anchorDateEpochDay: day - 10, timeOfDayMinutes: morning)]
        )
    }

    /// `TodayDosesTest.kt:138-154` — the same id shape, so a row is identified by the triple it is
    /// keyed on rather than by a fresh UUID.
    private static func log(
        epochDay: Int,
        status: IntakeStatus,
        scheduleId: String = "sch-1",
        minuteOfDay: Int = TodayDosesTests.morning
    ) -> IntakeLog {
        testLog(
            id: "log-\(scheduleId)-\(epochDay)-\(minuteOfDay)",
            scheduleId: scheduleId,
            epochDay: epochDay,
            minuteOfDay: minuteOfDay,
            status: status
        )
    }
}
