// Ported 1:1 from `feature/medications/src/test/kotlin/com/alicansekban/salus/feature/
// medications/domain/DoseOccurrenceGeneratorTest.kt`.
//
// Eight cases, in the Kotlin order, with the Kotlin inputs and the Kotlin expectations; each
// display name is the backticked Kotlin name verbatim, so a case renamed on one platform and not
// the other is visible in the diff. Each one cites the Kotlin line it comes from.

import SalusModel
import Testing

@testable import FeatureMedications

@Suite("DoseOccurrenceGenerator")
struct DoseOccurrenceGeneratorTests {
    /// `DoseOccurrenceGeneratorTest.kt:15` — 2026-03-02 is a Monday.
    private static let monday = LocalDate(year: 2026, month: 3, day: 2).epochDay

    /// `DoseOccurrenceGeneratorTest.kt:17-18` — one medication starting at epochDay 0, wrapping
    /// whatever schedules the case passes.
    private func med(_ schedules: MedicationSchedule...) -> [MedicationWithSchedules] {
        [MedicationWithSchedules(medication: testMedication(startDateEpochDay: 0), schedules: schedules)]
    }

    /// `DoseOccurrenceGeneratorTest.kt:20-31`.
    @Test("DAILY produces one occurrence per day per schedule")
    func dailyProducesOneOccurrencePerDayPerSchedule() {
        let monday = Self.monday
        let meds = med(
            testSchedule(id: "morning", timeOfDayMinutes: 8 * 60),
            testSchedule(id: "evening", timeOfDayMinutes: 20 * 60)
        )

        let result = DoseOccurrenceGenerator.occurrencesFor(
            medications: meds,
            fromEpochDay: monday,
            toEpochDay: monday + 2
        )

        #expect(result.count == 6) // 3 days x 2 times
        #expect(result.prefix(2).map(\.scheduleId) == ["morning", "evening"])
    }

    /// `DoseOccurrenceGeneratorTest.kt:33-45` — Monday (bit 0) + Wednesday (bit 2).
    @Test("DAYS_OF_WEEK respects the Monday-based bitmask")
    func daysOfWeekRespectsTheMondayBasedBitmask() {
        let monday = Self.monday
        let meds = med(
            testSchedule(recurrence: .daysOfWeek, daysOfWeekMask: 0b101)
        )

        let week = DoseOccurrenceGenerator.occurrencesFor(
            medications: meds,
            fromEpochDay: monday,
            toEpochDay: monday + 6
        )

        #expect(week.count == 2)
        #expect(week.map(\.epochDay) == [monday, monday + 2])
    }

    /// `DoseOccurrenceGeneratorTest.kt:47-60`.
    @Test("INTERVAL_DAYS counts from the anchor date")
    func intervalDaysCountsFromTheAnchorDate() {
        let monday = Self.monday
        let meds = med(
            testSchedule(
                recurrence: .intervalDays,
                intervalDays: 3,
                anchorDateEpochDay: monday
            )
        )

        let result = DoseOccurrenceGenerator.occurrencesFor(
            medications: meds,
            fromEpochDay: monday,
            toEpochDay: monday + 7
        )

        #expect(result.map(\.epochDay) == [monday, monday + 3, monday + 6])
    }

    /// `DoseOccurrenceGeneratorTest.kt:62-67`.
    @Test("AS_NEEDED never generates occurrences")
    func asNeededNeverGeneratesOccurrences() {
        let monday = Self.monday
        let meds = med(testSchedule(recurrence: .asNeeded))

        #expect(
            DoseOccurrenceGenerator.occurrencesFor(
                medications: meds,
                fromEpochDay: monday,
                toEpochDay: monday + 30
            ).isEmpty
        )
    }

    /// `DoseOccurrenceGeneratorTest.kt:69-81`.
    @Test("nothing before the anchor or medication start date")
    func nothingBeforeTheAnchorOrMedicationStartDate() {
        let monday = Self.monday
        let meds = [
            MedicationWithSchedules(
                medication: testMedication(startDateEpochDay: monday + 2),
                schedules: [testSchedule(anchorDateEpochDay: monday + 2)]
            )
        ]

        let result = DoseOccurrenceGenerator.occurrencesFor(
            medications: meds,
            fromEpochDay: monday,
            toEpochDay: monday + 4
        )

        #expect(result.map(\.epochDay) == [monday + 2, monday + 3, monday + 4])
    }

    /// `DoseOccurrenceGeneratorTest.kt:83-95`.
    @Test("medication end date cuts off occurrences")
    func medicationEndDateCutsOffOccurrences() {
        let monday = Self.monday
        let meds = [
            MedicationWithSchedules(
                medication: testMedication(startDateEpochDay: 0, endDateEpochDay: monday + 1),
                schedules: [testSchedule()]
            )
        ]

        let result = DoseOccurrenceGenerator.occurrencesFor(
            medications: meds,
            fromEpochDay: monday,
            toEpochDay: monday + 5
        )

        #expect(result.map(\.epochDay) == [monday, monday + 1])
    }

    /// `DoseOccurrenceGeneratorTest.kt:97-111`.
    @Test("inactive medication or schedule generates nothing")
    func inactiveMedicationOrScheduleGeneratesNothing() {
        let monday = Self.monday
        let meds = [
            MedicationWithSchedules(
                medication: testMedication(isActive: false),
                schedules: [testSchedule()]
            ),
            MedicationWithSchedules(
                medication: testMedication(id: "med-2"),
                schedules: [testSchedule(id: "sch-2", medicationId: "med-2", isActive: false)]
            )
        ]

        #expect(
            DoseOccurrenceGenerator.occurrencesFor(
                medications: meds,
                fromEpochDay: monday,
                toEpochDay: monday + 5
            ).isEmpty
        )
    }

    /// `DoseOccurrenceGeneratorTest.kt:113-128`.
    @Test("output is sorted by day then minute")
    func outputIsSortedByDayThenMinute() {
        let monday = Self.monday
        let meds = med(
            testSchedule(id: "evening", timeOfDayMinutes: 20 * 60),
            testSchedule(id: "morning", timeOfDayMinutes: 8 * 60)
        )

        let result = DoseOccurrenceGenerator.occurrencesFor(
            medications: meds,
            fromEpochDay: monday,
            toEpochDay: monday + 1
        )

        // Kotlin compares a list of `epochDay to minuteOfDay` pairs; a Swift tuple is not
        // `Equatable` as an array element, so the pair travels as the two-field struct the
        // generator already returns.
        #expect(
            result.map { [$0.epochDay, $0.minuteOfDay] } == [
                [monday, 480],
                [monday, 1200],
                [monday + 1, 480],
                [monday + 1, 1200]
            ]
        )
    }
}
