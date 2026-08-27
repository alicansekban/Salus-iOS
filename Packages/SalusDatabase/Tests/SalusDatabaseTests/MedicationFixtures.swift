// The `DaoSmokeTest.kt` medication fixtures, shared by the two `MedicationDao` suites —
// `MedicationDaoTests` (medications, stock, schedules) and `MedicationIntakeLogDaoTests`.
//
// They live in a file of their own for the same reason `SampleRecords` does: one populated
// instance per record, in an order that satisfies the foreign keys, with only the columns the
// queries filter on opened up. A default here is `DaoSmokeTest.kt`'s value, not a fresh choice.

import SalusCommon

@testable import SalusDatabase

enum MedicationFixtures {
    /// The Kotlin fixture's `p1` profile (`DaoSmokeTest.kt:34-43`), which every medication below
    /// hangs off — `medications.profile_id` is a cascading foreign key.
    static let profile = ProfileRecord(
        id: "p1",
        displayName: "Test",
        birthDateEpochDay: nil,
        sex: nil,
        heightCm: nil,
        healthNotes: nil,
        isDefault: true,
        createdAtEpochMs: 0
    )

    /// A migrated in-memory database with `p1` in it — so the seeded default profile is already
    /// there and `p1` is a second row, which is what lets a test write to "another profile".
    static func makeDao(clock: any SalusClock) async throws -> MedicationDao {
        let database = try SalusDatabase.inMemory(clock: clock)
        try await ProfileDao(database: database).upsert(profile)
        return MedicationDao(database: database)
    }

    /// One medication and one schedule of each profile, so an intake log can be written under
    /// either without the foreign keys getting in the way of what the test is about.
    static func seedTwoSchedules(_ dao: MedicationDao) async throws {
        try await dao.upsert(medication(id: "m1"))
        try await dao.upsert(medication(id: "m2", name: "Demir", profileId: SalusDatabase.defaultProfileId))
        try await dao.upsertSchedules([
            schedule(id: "s1", medicationId: "m1"),
            schedule(id: "s2", medicationId: "m2")
        ])
    }

    /// `DaoSmokeTest.kt:155-172`, with the name, the profile, the active flag and the stock opened
    /// up so a test can write a row the query is supposed to skip.
    static func medication(
        id: String,
        name: String = "Vitamin D",
        profileId: String = "p1",
        isActive: Bool = true,
        stockCount: Double? = nil
    ) -> MedicationRecord {
        MedicationRecord(
            id: id,
            profileId: profileId,
            name: name,
            form: "TABLET",
            strengthValue: 1000.0,
            strengthUnit: "IU",
            colorToken: "teal",
            instructions: nil,
            stockCount: stockCount,
            stockThreshold: nil,
            startDateEpochDay: 20000,
            endDateEpochDay: nil,
            isActive: isActive,
            remindersEnabled: true,
            createdAtEpochMs: 0,
            updatedAtEpochMs: 0
        )
    }

    /// `DaoSmokeTest.kt:174-184`, with the active flag and the time of day opened up.
    static func schedule(
        id: String,
        medicationId: String,
        isActive: Bool = true,
        timeOfDayMinutes: Int = 510
    ) -> MedicationScheduleRecord {
        MedicationScheduleRecord(
            id: id,
            medicationId: medicationId,
            recurrence: "DAILY",
            daysOfWeekMask: 0,
            intervalDays: nil,
            anchorDateEpochDay: 20000,
            timeOfDayMinutes: timeOfDayMinutes,
            doseAmount: 1.0,
            isActive: isActive
        )
    }

    /// `DaoSmokeTest.kt:186-197`, with the occurrence columns and the status opened up — they are
    /// what the unique index and the range queries key on. The medication follows the profile, so
    /// a log written under the other profile still satisfies its foreign key.
    static func intakeLog(
        id: String,
        scheduleId: String,
        profileId: String = "p1",
        epochDay: Int = 20100,
        minutes: Int = 510,
        status: String = "PENDING"
    ) -> MedicationIntakeLogRecord {
        MedicationIntakeLogRecord(
            id: id,
            scheduleId: scheduleId,
            medicationId: profileId == "p1" ? "m1" : "m2",
            profileId: profileId,
            scheduledDateEpochDay: epochDay,
            scheduledMinutes: minutes,
            status: status,
            takenAtEpochMs: nil,
            snoozedUntilEpochMs: nil,
            doseAmount: 1.0,
            note: nil
        )
    }
}
