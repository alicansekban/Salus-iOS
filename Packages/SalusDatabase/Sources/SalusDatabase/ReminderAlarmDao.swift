// Ported 1:1 from `core/database/src/main/kotlin/com/alicansekban/salus/core/database/dao/ReminderAlarmDao.kt`.
//
// Conventions — the plain struct over the database, the `@Query` strings carried verbatim — are
// `ProfileDao`'s; its doc comments explain why each of them is what it is, and are not repeated
// here. This DAO observes nothing: Room declares no `Flow` on it, because the scheduler polls the
// ledger when it re-syncs rather than reacting to it.
//
// The `'SCHEDULED'` literals stay inside the SQL, exactly where Kotlin has them. They are the
// `AlarmState` raw values of `SalusModel/Reminder.swift`, but `SalusDatabase` does not link
// `SalusModel` — records and DAOs speak the column's own vocabulary, and a repository maps.

import GRDB

/// Reads and writes the scheduler's ledger: the rolling window of upcoming reminder occurrences
/// (`ReminderAlarmRecord`).
public struct ReminderAlarmDao: Sendable {
    private let database: SalusDatabase

    public init(database: SalusDatabase) {
        self.database = database
    }

    /// The twin of Room's `@Upsert` (`ReminderAlarmDao.kt:11-12`): insert, or replace the row that
    /// shares the **primary key**.
    ///
    /// The conflict target is spelled out here, and only here among the DAOs, because
    /// `reminder_alarms` is the only table carrying a second uniqueness constraint — the unique
    /// `request_code` index (`ReminderAlarmEntity.kt:13`). GRDB's plain `upsert(db)` emits an
    /// untargeted `ON CONFLICT DO UPDATE`, which treats *any* uniqueness violation as "update the
    /// row I collided with": a new alarm reusing a live request code would silently overwrite the
    /// other alarm's payload while keeping its id, and the index meant to prevent exactly that
    /// would never fire. Targeting `id` keeps the upsert to what `@Upsert` means and leaves the
    /// request-code index free to reject the write with `SQLITE_CONSTRAINT_UNIQUE`.
    ///
    /// Room is silent here too, differently: its generated adapter retries the failed insert as an
    /// `UPDATE ... WHERE id = ?`, which matches no row and changes nothing. Neither silence is a
    /// behaviour a caller can build on — request codes are derived deterministically, so a
    /// collision is a bug in the deriving, and it should say so.
    public func upsert(_ alarm: ReminderAlarmRecord) async throws {
        try await database.writer.write { db in
            _ = try alarm.upsertAndFetch(db, onConflict: ["id"])
        }
    }

    /// The scheduler's working set — everything still waiting to fire, soonest first
    /// (`ReminderAlarmDao.kt:14-15`).
    public func getScheduled() async throws -> [ReminderAlarmRecord] {
        try await database.reader.read { db in
            try ReminderAlarmRecord.fetchAll(
                db,
                sql: """
                SELECT * FROM reminder_alarms
                WHERE state = 'SCHEDULED'
                ORDER BY trigger_at_epoch_ms ASC
                """
            )
        }
    }

    /// Every alarm materialized for one schedule, appointment or cycle
    /// (`ReminderAlarmDao.kt:17-18`).
    public func getByEntity(type: String, entityId: String) async throws -> [ReminderAlarmRecord] {
        try await database.reader.read { db in
            try ReminderAlarmRecord.fetchAll(
                db,
                sql: "SELECT * FROM reminder_alarms WHERE type = ? AND entity_id = ?",
                arguments: [type, entityId]
            )
        }
    }

    /// One occurrence of one entity, or none (`ReminderAlarmDao.kt:20-27`).
    public func getByOccurrence(
        type: String,
        entityId: String,
        occurrenceKey: String
    ) async throws -> ReminderAlarmRecord? {
        try await database.reader.read { db in
            try ReminderAlarmRecord.fetchOne(
                db,
                sql: """
                SELECT * FROM reminder_alarms
                WHERE type = ? AND entity_id = ? AND occurrence_key = ?
                """,
                arguments: [type, entityId, occurrenceKey]
            )
        }
    }

    /// The lookup a fired alarm arrives with — the request code is all the OS hands back
    /// (`ReminderAlarmDao.kt:29-30`).
    public func getByRequestCode(_ requestCode: Int) async throws -> ReminderAlarmRecord? {
        try await database.reader.read { db in
            try ReminderAlarmRecord.fetchOne(
                db,
                sql: "SELECT * FROM reminder_alarms WHERE request_code = ? LIMIT 1",
                arguments: [requestCode]
            )
        }
    }

    /// `ReminderAlarmDao.kt:32-33`.
    public func updateState(id: String, newState: String) async throws {
        try await database.writer.write { db in
            try db.execute(
                sql: "UPDATE reminder_alarms SET state = ? WHERE id = ?",
                arguments: [newState, id]
            )
        }
    }

    /// `ReminderAlarmDao.kt:35-36`.
    public func deleteByEntity(type: String, entityId: String) async throws {
        try await database.writer.write { db in
            try db.execute(
                sql: "DELETE FROM reminder_alarms WHERE type = ? AND entity_id = ?",
                arguments: [type, entityId]
            )
        }
    }

    /// Prunes finished history and nothing else: a `SCHEDULED` row survives however old it is,
    /// because an old one still in that state is the signal a re-sync turns into `MISSED`
    /// (`ReminderAlarmDao.kt:38-39`).
    public func purgeFinishedBefore(_ beforeEpochMs: Int64) async throws {
        try await database.writer.write { db in
            try db.execute(
                sql: """
                DELETE FROM reminder_alarms
                WHERE state != 'SCHEDULED' AND trigger_at_epoch_ms < ?
                """,
                arguments: [beforeEpochMs]
            )
        }
    }
}
