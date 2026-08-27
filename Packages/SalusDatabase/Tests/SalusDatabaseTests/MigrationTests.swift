// Ported from `core/database/src/test/kotlin/com/alicansekban/salus/core/database/MigrationTest.kt`.
//
// The Kotlin comment states the reason and it holds here too: Room validates the schema on open,
// so a wrong migration only fails on a real upgrade — long after the release is out.
// `runMigrationsAndValidate` moves that failure into the test suite; `RoomSchemaParityTests` is
// this port's replacement for the validation half, and this file is the port of the data half —
// what an existing database still holds after the upgrade.
//
// Android's `MigrationTestHelper` hands out a database frozen at version N. GRDB's equivalent is
// `migrator.migrate(_:upTo:)` against a queue the test keeps open, so the "close, reopen at the
// next version" shape of the Kotlin test becomes "migrate the same queue one step further".

import Foundation
import GRDB
import SalusTesting
import Testing

@testable import SalusDatabase

@Suite("Migrations")
struct MigrationTests {
    /// 2023-11-14T22:13:20Z, chosen only because its millisecond value is legible: 1_700_000_000_000.
    private let clock = FixedSalusClock(now: Date(timeIntervalSince1970: 1_700_000_000))

    private var migrator: DatabaseMigrator { SalusMigrations.makeMigrator(clock: clock) }

    /// `MigrationTest.kt:31-50`.
    @Test("1 to 2 adds health notes and keeps the seeded profile")
    func oneToTwoAddsHealthNotesAndKeepsTheSeededProfile() throws {
        let queue = try DatabaseQueue()
        try migrator.migrate(queue, upTo: "v1")

        try queue.write { db in
            try db.execute(
                sql: """
                INSERT OR REPLACE INTO profiles \
                (id, display_name, birth_date, sex, height_cm, is_default, created_at) \
                VALUES ('default-profile', 'Ada', 7000, 'FEMALE', 170.0, 1, 42)
                """
            )
        }

        try migrator.migrate(queue, upTo: "v2")

        try queue.read { db in
            let row = try #require(try Row.fetchOne(db, sql: "SELECT * FROM profiles"))
            #expect(row["display_name"] as String? == "Ada")
            #expect(row["height_cm"] as Double? == 170.0)
            #expect(row["birth_date"] as Int? == 7000)
            #expect(row["created_at"] as Int64? == 42)
            // The column exists and is NULL for rows written before the upgrade.
            #expect(row["health_notes"] as DatabaseValue? == .null)
            #expect(row["health_notes"] as String? == nil)
        }
    }

    /// `MigrationTest.kt:52-88`. The three inserts are the point: the same period in another
    /// language is a different row, and the same key replaces.
    @Test("2 to 3 creates the ai summary cache keyed by period and language")
    func twoToThreeCreatesTheAiSummaryCacheKeyedByPeriodAndLanguage() throws {
        let queue = try DatabaseQueue()
        try migrator.migrate(queue, upTo: "v2")

        try migrator.migrate(queue, upTo: "v3")

        try queue.write { db in
            #expect(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM ai_summaries") == 0)

            try db.execute(
                sql: """
                INSERT INTO ai_summaries \
                (period_type, start_epoch_day, end_epoch_day, language, text, created_at_epoch_ms) \
                VALUES ('WEEKLY', 20685, 20691, 'tr', 'ilk', 1)
                """
            )
            try db.execute(
                sql: """
                INSERT INTO ai_summaries \
                (period_type, start_epoch_day, end_epoch_day, language, text, created_at_epoch_ms) \
                VALUES ('WEEKLY', 20685, 20691, 'en', 'first', 2)
                """
            )
            try db.execute(
                sql: """
                INSERT OR REPLACE INTO ai_summaries \
                (period_type, start_epoch_day, end_epoch_day, language, text, created_at_epoch_ms) \
                VALUES ('WEEKLY', 20685, 20691, 'tr', 'yenisi', 3)
                """
            )

            #expect(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM ai_summaries") == 2)
            let text = try String.fetchOne(
                db,
                sql: """
                SELECT text FROM ai_summaries WHERE period_type = 'WEEKLY' \
                AND start_epoch_day = 20685 AND language = 'tr'
                """
            )
            #expect(text == "yenisi")
        }
    }

    /// `MigrationTest.kt:90-110`. The default is the point: a medication written before the
    /// upgrade never asked to be silenced, so it must come out of the migration still ringing.
    @Test("3 to 4 adds reminders_enabled and existing medications keep ringing")
    func threeToFourAddsRemindersEnabledAndExistingMedicationsKeepRinging() throws {
        let queue = try DatabaseQueue()
        try migrator.migrate(queue, upTo: "v3")

        // The Kotlin test inserts the owning profile first; `"v1"` already seeded that exact row
        // here, so the medication's foreign key has something to point at without it.
        try queue.write { db in
            try db.execute(
                sql: """
                INSERT INTO medications \
                (id, profile_id, name, form, color_token, start_date, is_active, created_at, updated_at) \
                VALUES ('med-1', 'default-profile', 'Aspirin', 'TABLET', 'primary', 0, 1, 1, 1)
                """
            )
        }

        try migrator.migrate(queue, upTo: "v4")

        try queue.read { db in
            let row = try #require(try Row.fetchOne(db, sql: "SELECT * FROM medications WHERE id = 'med-1'"))
            #expect(row["reminders_enabled"] as Int? == 1)
            // Nothing else moved: the row is the one the v3 database held.
            #expect(row["name"] as String? == "Aspirin")
        }
    }

    /// Not in the Kotlin test, because Room's `onCreate` callback cannot run twice. GRDB's
    /// migrator decides for itself what still needs applying, and this pins that it decides
    /// correctly: an app that launches twice must not end up with two default profiles.
    @Test("running the migrator again is a no-op")
    func runningTheMigratorAgainIsANoOp() throws {
        let queue = try DatabaseQueue()
        try migrator.migrate(queue)
        let before = try queue.read(SchemaSnapshot.init)

        try migrator.migrate(queue)
        // …and again through a freshly built migrator, the way a second app launch would.
        try SalusMigrations.makeMigrator(clock: clock).migrate(queue)

        let after = try queue.read(SchemaSnapshot.init)
        #expect(after == before)
        #expect(after.profileCount == 1)
        #expect(after.appliedMigrations == ["v1", "v2", "v3", "v4"])
    }

    /// The seeded row is what every other table's `profile_id` points at, so it is worth pinning
    /// on its own — including the `created_at` the injected clock wrote, which is the whole reason
    /// `makeMigrator` takes a clock at all (`DatabaseModule.kt:30-40`).
    @Test("v1 seeds exactly one default profile, stamped by the clock")
    func v1SeedsExactlyOneDefaultProfile() throws {
        let queue = try DatabaseQueue()
        try migrator.migrate(queue, upTo: "v1")

        try queue.read { db in
            #expect(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM profiles") == 1)
            let row = try #require(try Row.fetchOne(db, sql: "SELECT * FROM profiles"))
            #expect(row["id"] as String? == SalusDatabase.defaultProfileId)
            // Present and empty, the way Kotlin's `display_name ''` writes it — not NULL.
            #expect((row["display_name"] as String?)?.isEmpty == true)
            #expect(row["birth_date"] as DatabaseValue? == .null)
            #expect(row["sex"] as DatabaseValue? == .null)
            #expect(row["height_cm"] as DatabaseValue? == .null)
            #expect(row["is_default"] as Int? == 1)
            #expect(row["created_at"] as Int64? == 1_700_000_000_000)
        }
    }

    /// The whole seed survives the two upgrades, `health_notes` included.
    @Test("the seeded profile survives every migration")
    func theSeededProfileSurvivesEveryMigration() throws {
        let queue = try DatabaseQueue()
        try migrator.migrate(queue)

        try queue.read { db in
            let profile = try #require(try ProfileRecord.fetchOne(db, key: SalusDatabase.defaultProfileId))
            #expect(profile == ProfileRecord(
                id: "default-profile",
                displayName: "",
                birthDateEpochDay: nil,
                sex: nil,
                heightCm: nil,
                healthNotes: nil,
                isDefault: true,
                createdAtEpochMs: 1_700_000_000_000
            ))
        }
    }

    /// The schema leans on cascades — deleting a profile has to clear eleven tables — so the
    /// pragma being on is part of the contract, not a GRDB default worth trusting silently.
    @Test("foreign keys are enforced on an open database")
    func foreignKeysAreEnforced() async throws {
        let database = try SalusDatabase.inMemory(clock: clock)

        try await database.reader.read { db in
            let enabled = try Bool.fetchOne(db, sql: "PRAGMA foreign_keys")
            #expect(enabled == true)
        }

        // And they bite: an appointment for a profile that does not exist is rejected.
        await #expect(throws: DatabaseError.self) {
            try await database.writer.write { db in
                try AppointmentRecord(
                    id: "orphan",
                    profileId: "no-such-profile",
                    title: "Kardiyoloji kontrolü",
                    doctorName: nil,
                    specialty: nil,
                    location: nil,
                    notes: nil,
                    startsAtLocal: "2026-09-01T14:30",
                    timeZoneId: "Europe/Istanbul",
                    startsAtEpochMs: 1_788_000_000_000,
                    durationMinutes: 30,
                    status: "SCHEDULED",
                    createdAtEpochMs: 1,
                    updatedAtEpochMs: 1
                ).insert(db)
            }
        }
    }

    /// Deleting the profile clears everything hanging off it — the cascade the whole single-user
    /// schema is built on (`SalusDatabase.kt:62-64`).
    @Test("deleting a profile cascades to its data")
    func deletingAProfileCascadesToItsData() async throws {
        let database = try SalusDatabase.inMemory(clock: clock)

        try await database.writer.write { db in
            for sample in SampleRecords.all {
                try sample.insertAndReadBack(db)
            }
            _ = try ProfileRecord.deleteOne(db, key: SampleRecords.profileId)

            #expect(try AppointmentRecord.fetchCount(db) == 0)
            #expect(try AppointmentReminderRecord.fetchCount(db) == 0)
            #expect(try MedicationRecord.fetchCount(db) == 0)
            #expect(try MedicationScheduleRecord.fetchCount(db) == 0)
            #expect(try MedicationIntakeLogRecord.fetchCount(db) == 0)
            #expect(try CyclePeriodRecord.fetchCount(db) == 0)
            #expect(try CycleDailyEntryRecord.fetchCount(db) == 0)
            #expect(try CycleEntrySymptomRecord.fetchCount(db) == 0)
            #expect(try VitalsMeasurementRecord.fetchCount(db) == 0)
            // No foreign key on these three, so they stay — by design, not by omission.
            #expect(try SymptomRecord.fetchCount(db) == 1)
            #expect(try ReminderAlarmRecord.fetchCount(db) == 1)
            #expect(try AiSummaryRecord.fetchCount(db) == 1)
        }
    }
}

/// Everything about a database that a re-run of the migrator must leave untouched.
private struct SchemaSnapshot: Equatable {
    let tables: [String]
    let profileCount: Int
    let appliedMigrations: [String]

    init(_ db: Database) throws {
        tables = try String.fetchAll(
            db,
            sql: "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name"
        )
        profileCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM profiles") ?? 0
        appliedMigrations = try String.fetchAll(db, sql: "SELECT identifier FROM grdb_migrations ORDER BY identifier")
    }
}
