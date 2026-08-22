// The GRDB twin of Room's schema history, ported from
// `core/database/src/main/kotlin/com/alicansekban/salus/core/database/migration/Migrations.kt`
// and `di/DatabaseModule.kt` (`SeedDefaultProfileCallback`).
//
// Room generates v1's DDL from the `@Entity` classes and only *ships* the 1→2 and 2→3 statements.
// GRDB generates nothing, so v1 is written out here — and the statements below are not re-authored
// SQL: they are the `createSql` strings of
// `salus-android/core/database/schemas/…/1.json`, copied with Room's backticks, its
// `IF NOT EXISTS`, its `index_<table>_<columns>` names and its `ON UPDATE NO ACTION ON DELETE
// CASCADE` spelling intact, with Room's `${TABLE_NAME}` placeholder resolved. Hand-tidying any of
// it is how the two schemas drift; `RoomSchemaParityTests` compares the result against the same
// JSON on every run.

import Foundation
import GRDB
import SalusCommon

/// The migration list, in one place — the twin of Kotlin's `salusMigrations` array.
enum SalusMigrations {
    /// v1 = Room's `createSql` for every entity of `1.json`, each table followed by its own
    /// indices, in the order the export lists them.
    static let v1Statements: [String] = [
        """
        CREATE TABLE IF NOT EXISTS `profiles` (`id` TEXT NOT NULL, `display_name` TEXT NOT NULL, \
        `birth_date` INTEGER, `sex` TEXT, `height_cm` REAL, `is_default` INTEGER NOT NULL, \
        `created_at` INTEGER NOT NULL, PRIMARY KEY(`id`))
        """,
        """
        CREATE TABLE IF NOT EXISTS `appointments` (`id` TEXT NOT NULL, `profile_id` TEXT NOT NULL, \
        `title` TEXT NOT NULL, `doctor_name` TEXT, `specialty` TEXT, `location` TEXT, `notes` TEXT, \
        `starts_at_local` TEXT NOT NULL, `tz_id` TEXT NOT NULL, `starts_at_epoch_ms` INTEGER NOT NULL, \
        `duration_min` INTEGER NOT NULL, `status` TEXT NOT NULL, `created_at` INTEGER NOT NULL, \
        `updated_at` INTEGER NOT NULL, PRIMARY KEY(`id`), FOREIGN KEY(`profile_id`) REFERENCES \
        `profiles`(`id`) ON UPDATE NO ACTION ON DELETE CASCADE )
        """,
        """
        CREATE INDEX IF NOT EXISTS `index_appointments_profile_id_starts_at_epoch_ms` ON \
        `appointments` (`profile_id`, `starts_at_epoch_ms`)
        """,
        "CREATE INDEX IF NOT EXISTS `index_appointments_status` ON `appointments` (`status`)",
        """
        CREATE TABLE IF NOT EXISTS `appointment_reminders` (`id` TEXT NOT NULL, \
        `appointment_id` TEXT NOT NULL, `offset_minutes` INTEGER NOT NULL, `enabled` INTEGER NOT NULL, \
        PRIMARY KEY(`id`), FOREIGN KEY(`appointment_id`) REFERENCES `appointments`(`id`) \
        ON UPDATE NO ACTION ON DELETE CASCADE )
        """,
        """
        CREATE INDEX IF NOT EXISTS `index_appointment_reminders_appointment_id` ON \
        `appointment_reminders` (`appointment_id`)
        """,
        """
        CREATE TABLE IF NOT EXISTS `medications` (`id` TEXT NOT NULL, `profile_id` TEXT NOT NULL, \
        `name` TEXT NOT NULL, `form` TEXT NOT NULL, `strength_value` REAL, `strength_unit` TEXT, \
        `color_token` TEXT NOT NULL, `instructions` TEXT, `stock_count` REAL, `stock_threshold` REAL, \
        `start_date` INTEGER NOT NULL, `end_date` INTEGER, `is_active` INTEGER NOT NULL, \
        `created_at` INTEGER NOT NULL, `updated_at` INTEGER NOT NULL, PRIMARY KEY(`id`), \
        FOREIGN KEY(`profile_id`) REFERENCES `profiles`(`id`) ON UPDATE NO ACTION ON DELETE CASCADE )
        """,
        """
        CREATE INDEX IF NOT EXISTS `index_medications_profile_id_is_active` ON \
        `medications` (`profile_id`, `is_active`)
        """,
        """
        CREATE TABLE IF NOT EXISTS `medication_schedules` (`id` TEXT NOT NULL, \
        `medication_id` TEXT NOT NULL, `recurrence` TEXT NOT NULL, `days_of_week_mask` INTEGER NOT NULL, \
        `interval_days` INTEGER, `anchor_date` INTEGER NOT NULL, `time_of_day_minutes` INTEGER NOT NULL, \
        `dose_amount` REAL NOT NULL, `is_active` INTEGER NOT NULL, PRIMARY KEY(`id`), \
        FOREIGN KEY(`medication_id`) REFERENCES `medications`(`id`) ON UPDATE NO ACTION ON DELETE CASCADE )
        """,
        """
        CREATE INDEX IF NOT EXISTS `index_medication_schedules_medication_id` ON \
        `medication_schedules` (`medication_id`)
        """,
        """
        CREATE TABLE IF NOT EXISTS `medication_intake_logs` (`id` TEXT NOT NULL, \
        `schedule_id` TEXT NOT NULL, `medication_id` TEXT NOT NULL, `profile_id` TEXT NOT NULL, \
        `scheduled_date` INTEGER NOT NULL, `scheduled_minutes` INTEGER NOT NULL, `status` TEXT NOT NULL, \
        `taken_at_epoch_ms` INTEGER, `snoozed_until_epoch_ms` INTEGER, `dose_amount` REAL NOT NULL, \
        `note` TEXT, PRIMARY KEY(`id`), FOREIGN KEY(`schedule_id`) REFERENCES `medication_schedules`(`id`) \
        ON UPDATE NO ACTION ON DELETE CASCADE )
        """,
        """
        CREATE UNIQUE INDEX IF NOT EXISTS \
        `index_medication_intake_logs_schedule_id_scheduled_date_scheduled_minutes` ON \
        `medication_intake_logs` (`schedule_id`, `scheduled_date`, `scheduled_minutes`)
        """,
        """
        CREATE INDEX IF NOT EXISTS `index_medication_intake_logs_profile_id_scheduled_date` ON \
        `medication_intake_logs` (`profile_id`, `scheduled_date`)
        """,
        """
        CREATE INDEX IF NOT EXISTS `index_medication_intake_logs_medication_id` ON \
        `medication_intake_logs` (`medication_id`)
        """,
        """
        CREATE TABLE IF NOT EXISTS `cycle_periods` (`id` TEXT NOT NULL, `profile_id` TEXT NOT NULL, \
        `start_date` INTEGER NOT NULL, `end_date` INTEGER, `flow_peak` TEXT, `note` TEXT, \
        `created_at` INTEGER NOT NULL, PRIMARY KEY(`id`), FOREIGN KEY(`profile_id`) REFERENCES \
        `profiles`(`id`) ON UPDATE NO ACTION ON DELETE CASCADE )
        """,
        """
        CREATE UNIQUE INDEX IF NOT EXISTS `index_cycle_periods_profile_id_start_date` ON \
        `cycle_periods` (`profile_id`, `start_date`)
        """,
        """
        CREATE TABLE IF NOT EXISTS `cycle_daily_entries` (`id` TEXT NOT NULL, \
        `profile_id` TEXT NOT NULL, `date` INTEGER NOT NULL, `flow` TEXT, `mood` TEXT, `note` TEXT, \
        PRIMARY KEY(`id`), FOREIGN KEY(`profile_id`) REFERENCES `profiles`(`id`) \
        ON UPDATE NO ACTION ON DELETE CASCADE )
        """,
        """
        CREATE UNIQUE INDEX IF NOT EXISTS `index_cycle_daily_entries_profile_id_date` ON \
        `cycle_daily_entries` (`profile_id`, `date`)
        """,
        """
        CREATE TABLE IF NOT EXISTS `symptoms` (`id` TEXT NOT NULL, `name_key` TEXT NOT NULL, \
        `is_custom` INTEGER NOT NULL, `icon_token` TEXT, PRIMARY KEY(`id`))
        """,
        """
        CREATE TABLE IF NOT EXISTS `cycle_entry_symptoms` (`entry_id` TEXT NOT NULL, \
        `symptom_id` TEXT NOT NULL, `severity` INTEGER NOT NULL, PRIMARY KEY(`entry_id`, `symptom_id`), \
        FOREIGN KEY(`entry_id`) REFERENCES `cycle_daily_entries`(`id`) ON UPDATE NO ACTION ON DELETE CASCADE , \
        FOREIGN KEY(`symptom_id`) REFERENCES `symptoms`(`id`) ON UPDATE NO ACTION ON DELETE CASCADE )
        """,
        """
        CREATE INDEX IF NOT EXISTS `index_cycle_entry_symptoms_symptom_id` ON \
        `cycle_entry_symptoms` (`symptom_id`)
        """,
        """
        CREATE TABLE IF NOT EXISTS `vitals_measurements` (`id` TEXT NOT NULL, \
        `profile_id` TEXT NOT NULL, `type` TEXT NOT NULL, `measured_at_epoch_ms` INTEGER NOT NULL, \
        `tz_id` TEXT NOT NULL, `value_primary` REAL NOT NULL, `value_secondary` REAL, \
        `value_tertiary` REAL, `unit` TEXT NOT NULL, `measurement_context` TEXT, `note` TEXT, \
        PRIMARY KEY(`id`), FOREIGN KEY(`profile_id`) REFERENCES `profiles`(`id`) \
        ON UPDATE NO ACTION ON DELETE CASCADE )
        """,
        """
        CREATE INDEX IF NOT EXISTS `index_vitals_measurements_profile_id_type_measured_at_epoch_ms` ON \
        `vitals_measurements` (`profile_id`, `type`, `measured_at_epoch_ms`)
        """,
        """
        CREATE TABLE IF NOT EXISTS `reminder_alarms` (`id` TEXT NOT NULL, `type` TEXT NOT NULL, \
        `entity_id` TEXT NOT NULL, `occurrence_key` TEXT NOT NULL, `trigger_at_epoch_ms` INTEGER NOT NULL, \
        `request_code` INTEGER NOT NULL, `state` TEXT NOT NULL, PRIMARY KEY(`id`))
        """,
        """
        CREATE INDEX IF NOT EXISTS `index_reminder_alarms_trigger_at_epoch_ms` ON \
        `reminder_alarms` (`trigger_at_epoch_ms`)
        """,
        """
        CREATE INDEX IF NOT EXISTS `index_reminder_alarms_type_entity_id` ON \
        `reminder_alarms` (`type`, `entity_id`)
        """,
        """
        CREATE UNIQUE INDEX IF NOT EXISTS `index_reminder_alarms_request_code` ON \
        `reminder_alarms` (`request_code`)
        """
    ]

    /// 1 → 2 (`Migrations.kt:15-17`): onboarding asks for chronic conditions and allergies.
    static let v2Statement = "ALTER TABLE profiles ADD COLUMN health_notes TEXT"

    /// 2 → 3 (`Migrations.kt:28-39`): the per-period, per-language summary cache. Byte-identical
    /// to the Kotlin statement, which is itself what Room generates for `AiSummaryEntity`.
    static let v3Statement = """
    CREATE TABLE IF NOT EXISTS `ai_summaries` (\
    `period_type` TEXT NOT NULL, \
    `start_epoch_day` INTEGER NOT NULL, \
    `end_epoch_day` INTEGER NOT NULL, \
    `language` TEXT NOT NULL, \
    `text` TEXT NOT NULL, \
    `created_at_epoch_ms` INTEGER NOT NULL, \
    PRIMARY KEY(`period_type`, `start_epoch_day`, `language`))
    """

    /// Builds the migrator. `eraseDatabaseOnSchemaChange` stays off: this is a health log with no
    /// backend to restore from, so a schema mismatch must fail loudly rather than delete the data.
    ///
    /// The clock is here for one row only — see `seedDefaultProfile`.
    static func makeMigrator(clock: any SalusClock) -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            for statement in v1Statements {
                try db.execute(sql: statement)
            }
            try seedDefaultProfile(db, clock: clock)
        }

        migrator.registerMigration("v2") { db in
            try db.execute(sql: v2Statement)
        }

        migrator.registerMigration("v3") { db in
            try db.execute(sql: v3Statement)
        }

        return migrator
    }

    /// The twin of `SeedDefaultProfileCallback.onCreate` (`DatabaseModule.kt:30-40`): single-user
    /// v1 carries `profile_id` on every data table, and this fixed row is what they all point at.
    ///
    /// One column is missing next to the Kotlin statement, and it has to be: Room's callback runs
    /// once, on creation, against the *final* schema, so it can name `health_notes`. This runs
    /// inside `"v1"`, where that column does not exist yet — it arrives one migration later and is
    /// NULL for every pre-existing row, which is the same end state the Kotlin insert produces.
    ///
    /// `System.currentTimeMillis()` becomes the injected clock: a seed row written by `Date()`
    /// would make the seeded `created_at` unassertable, and production code in this port never
    /// reads the wall clock directly (`SalusClock.swift`).
    private static func seedDefaultProfile(_ db: Database, clock: any SalusClock) throws {
        let createdAtEpochMs = Int64((clock.now().timeIntervalSince1970 * 1000).rounded())
        try db.execute(
            sql: """
            INSERT INTO profiles \
            (id, display_name, birth_date, sex, height_cm, is_default, created_at) \
            VALUES (?, '', NULL, NULL, NULL, 1, ?)
            """,
            arguments: [SalusDatabase.defaultProfileId, createdAtEpochMs]
        )
    }
}
