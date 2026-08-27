// Ported 1:1 from `feature/medications/src/test/kotlin/com/alicansekban/salus/feature/
// medications/data/MedicationMappersTest.kt`.
//
// The four Kotlin case names are carried over verbatim with one substitution: Room's word for a
// row is `entity`, GRDB's is `record`, so `… round-trips through the entity` becomes
// `… round-trips through the record` (recorded divergence (g)). Nothing else about the cases
// changes — the same three round trips and the same fallback, against the same `testMedication` /
// `testSchedule` builders.

import SalusDatabase
import SalusModel
import Testing

@testable import FeatureMedications

@Suite("MedicationMapper")
struct MedicationMapperTests {
    /// `MedicationMappersTest.kt:14-34`.
    ///
    /// `remindersEnabled` is handed to `toRecord` explicitly rather than read off the model,
    /// because the column has no default on the Swift side of the write path either — the
    /// repository is the one place that decides which of the two values wins.
    @Test("medication round-trips through the record")
    func medicationRoundTripsThroughTheRecord() {
        let domain = testMedication(
            endDateEpochDay: 200,
            stockCount: 12.0,
            stockThreshold: 5.0,
            remindersEnabled: false
        )

        let roundTripped = domain
            .toRecord(
                profileId: "p",
                colorToken: "primary",
                createdAtEpochMs: 1,
                updatedAtEpochMs: 2,
                remindersEnabled: domain.remindersEnabled
            )
            .toDomain()

        #expect(roundTripped == domain)
    }

    /// `MedicationMappersTest.kt:36-45`.
    @Test("schedule round-trips through the record")
    func scheduleRoundTripsThroughTheRecord() {
        let domain = testSchedule(
            recurrence: .daysOfWeek,
            daysOfWeekMask: 0b1010,
            intervalDays: nil
        )

        #expect(domain.toRecord().toDomain() == domain)
    }

    /// `MedicationMappersTest.kt:47-63`.
    @Test("intake log round-trips through the record")
    func intakeLogRoundTripsThroughTheRecord() {
        let domain = IntakeLog(
            id: "log-1",
            scheduleId: "sch-1",
            medicationId: "med-1",
            epochDay: 100,
            minuteOfDay: 480,
            status: .taken,
            takenAtEpochMs: 123,
            snoozedUntilEpochMs: nil,
            doseAmount: 2.0,
            note: "with food"
        )

        #expect(domain.toRecord(profileId: "p").toDomain() == domain)
    }

    /// `MedicationMappersTest.kt:65-80`.
    ///
    /// A stored spelling this build does not know is a future Android version's, reached through a
    /// backup or a downgrade. Falling back keeps the row readable — the alternative, throwing,
    /// would blank the whole list because one schedule repeats in a way this build cannot name.
    /// The Kotlin case asserts only `Recurrence`; the two sibling enums are asserted here too,
    /// because the same `?? default` is written three times and one of them could rot alone.
    @Test("unknown enum strings fall back to safe defaults")
    func unknownEnumStringsFallBackToSafeDefaults() {
        let schedule = MedicationScheduleRecord(
            id: "s",
            medicationId: "m",
            recurrence: "SOMETHING_NEW",
            daysOfWeekMask: 0,
            intervalDays: nil,
            anchorDateEpochDay: 0,
            timeOfDayMinutes: 0,
            doseAmount: 1.0,
            isActive: true
        )

        #expect(schedule.toDomain().recurrence == .daily)
        #expect(Self.medicationRecord(form: "SOMETHING_NEW").toDomain().form == .other)
        #expect(Self.logRecord(status: "SOMETHING_NEW").toDomain().status == .pending)
    }

    private static func medicationRecord(form: String) -> MedicationRecord {
        MedicationRecord(
            id: "m",
            profileId: "p",
            name: "Aspirin",
            form: form,
            strengthValue: nil,
            strengthUnit: nil,
            colorToken: "primary",
            instructions: nil,
            stockCount: nil,
            stockThreshold: nil,
            startDateEpochDay: 0,
            endDateEpochDay: nil,
            isActive: true,
            remindersEnabled: true,
            createdAtEpochMs: 1,
            updatedAtEpochMs: 2
        )
    }

    private static func logRecord(status: String) -> MedicationIntakeLogRecord {
        MedicationIntakeLogRecord(
            id: "log-1",
            scheduleId: "sch-1",
            medicationId: "med-1",
            profileId: "p",
            scheduledDateEpochDay: 100,
            scheduledMinutes: 480,
            status: status,
            takenAtEpochMs: nil,
            snoozedUntilEpochMs: nil,
            doseAmount: 1.0,
            note: nil
        )
    }
}
