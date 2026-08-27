// Ported 1:1 from `core/database/src/main/kotlin/com/alicansekban/salus/core/database/dao/MedicationDao.kt`.
//
// Conventions — the plain struct over the database, the `@Query` strings carried verbatim — are
// `ProfileDao`'s; its doc comments explain why each of them is what it is, and are not repeated
// here. The `AsyncThrowingStream` standing in for Room's `Flow` comes from `conflatedStream`,
// which is where that decision is written down.
//
// Four things are worth naming here.
//
// `insertIntakeLog` is an **insert**, not an upsert, and it is the only write in this package that
// is: Room declares it `OnConflictStrategy.ABORT` because the unique
// `(schedule_id, scheduled_date, scheduled_minutes)` index is the idempotency key — a duplicate
// occurrence must surface as a constraint error, not be silently merged. GRDB's `insert` already
// throws on it; nothing here catches it.
//
// `deactivateSchedulesExcept` deactivates rather than deletes, and that is load-bearing:
// `medication_intake_logs.schedule_id` cascades, so deleting a schedule an edit dropped would
// erase the doses recorded against it.
//
// The `…Between` queries carry **no** `ORDER BY` in the Kotlin (`MedicationDao.kt:105-127`).
// They are ported that way — an order the source does not promise is not one to invent here, and
// a caller that needs one sorts.
//
// `saveWithSchedules` has no Kotlin twin: Android's repository issues upsert, upsertSchedules and
// deactivateSchedulesExcept as three separate writes. Here they share one transaction (recorded
// divergence (d)), so a reader never sees a medication beside the schedule set of its previous
// version.

import GRDB

/// Reads and writes medications, the schedules that say when they are due, and the doses recorded
/// against those schedules.
public struct MedicationDao: Sendable {
    private let database: SalusDatabase

    public init(database: SalusDatabase) {
        self.database = database
    }

    // MARK: - Medications

    /// `MedicationDao.kt:17-18`.
    public func upsert(_ medication: MedicationRecord) async throws {
        try await database.writer.write { db in
            try medication.upsert(db)
        }
    }

    /// `MedicationDao.kt:23-24`.
    public func getById(_ id: String) async throws -> MedicationRecord? {
        try await database.reader.read { db in
            try MedicationRecord.fetchOne(db, sql: Self.byIdSql, arguments: [id])
        }
    }

    /// One medication, and nothing once it is deleted — which is what closes the detail screen
    /// (`MedicationDao.kt:29-30`). The row is answered whether or not it is active.
    public func observeById(_ id: String) -> AsyncThrowingStream<MedicationRecord?, any Error> {
        let observation = ValueObservation.tracking { db in
            try MedicationRecord.fetchOne(db, sql: Self.byIdSql, arguments: [id])
        }
        return conflatedStream(observation.values(in: database.reader))
    }

    /// One profile's active medications, alphabetically (`MedicationDao.kt:26-27`).
    public func observeActive(profileId: String) -> AsyncThrowingStream<[MedicationRecord], any Error> {
        let observation = ValueObservation.tracking { db in
            try MedicationRecord.fetchAll(db, sql: Self.activeSql, arguments: [profileId])
        }
        return conflatedStream(observation.values(in: database.reader))
    }

    /// `MedicationDao.kt:84-85` — the same query as `observeActive`, read once.
    public func getActive(profileId: String) async throws -> [MedicationRecord] {
        try await database.reader.read { db in
            try MedicationRecord.fetchAll(db, sql: Self.activeSql, arguments: [profileId])
        }
    }

    /// `MedicationDao.kt:81-82`. The schedules and their intake logs go with it —
    /// `medication_schedules.medication_id` and `medication_intake_logs.schedule_id` are cascading
    /// foreign keys and `SalusDatabase` keeps foreign keys on.
    public func deleteById(_ id: String) async throws {
        try await database.writer.write { db in
            try db.execute(sql: "DELETE FROM medications WHERE id = ?", arguments: [id])
        }
    }

    /// Subtracts a recorded dose from the tracked stock (`MedicationDao.kt:129-136`).
    ///
    /// `MAX(0, …)` is a floor: recording more than what is left leaves 0, never a negative count.
    /// `AND stock_count IS NOT NULL` is the other half — "no stock tracked" is a NULL, and a dose
    /// must not turn it into a number the user never asked for.
    public func decrementStock(id: String, amount: Double) async throws {
        try await database.writer.write { db in
            try db.execute(
                sql: """
                UPDATE medications
                SET stock_count = MAX(0, stock_count - ?)
                WHERE id = ? AND stock_count IS NOT NULL
                """,
                arguments: [amount, id]
            )
        }
    }

    /// `MedicationDao.kt:138-139` — silences (or un-silences) this medication's dose reminders.
    /// The caller supplies `updated_at` rather than the DAO reading a clock, exactly as Room does.
    public func setRemindersEnabled(id: String, enabled: Bool, updatedAtEpochMs: Int64) async throws {
        try await database.writer.write { db in
            try db.execute(
                sql: "UPDATE medications SET reminders_enabled = ?, updated_at = ? WHERE id = ?",
                arguments: [enabled, updatedAtEpochMs, id]
            )
        }
    }

    // MARK: - Schedules

    /// `MedicationDao.kt:20-21`.
    public func upsertSchedules(_ schedules: [MedicationScheduleRecord]) async throws {
        try await database.writer.write { db in
            for schedule in schedules {
                try schedule.upsert(db)
            }
        }
    }

    /// `MedicationDao.kt:32-33`.
    public func observeActiveSchedulesFor(
        medicationId: String
    ) -> AsyncThrowingStream<[MedicationScheduleRecord], any Error> {
        let observation = ValueObservation.tracking { db in
            try MedicationScheduleRecord.fetchAll(db, sql: Self.activeSchedulesForSql, arguments: [medicationId])
        }
        return conflatedStream(observation.values(in: database.reader))
    }

    /// `MedicationDao.kt:35-36` — the same query as `observeActiveSchedulesFor`, read once.
    public func getActiveSchedulesFor(medicationId: String) async throws -> [MedicationScheduleRecord] {
        try await database.reader.read { db in
            try MedicationScheduleRecord.fetchAll(db, sql: Self.activeSchedulesForSql, arguments: [medicationId])
        }
    }

    /// `MedicationDao.kt:87-88`.
    public func getScheduleById(_ id: String) async throws -> MedicationScheduleRecord? {
        try await database.reader.read { db in
            try MedicationScheduleRecord.fetchOne(
                db,
                sql: "SELECT * FROM medication_schedules WHERE id = ?",
                arguments: [id]
            )
        }
    }

    /// Every active schedule of one profile's active medications — what the dose-reminder
    /// scheduler enumerates (`MedicationDao.kt:38-47`).
    ///
    /// The join is what scopes it twice over: `medication_schedules` carries no `profile_id` and no
    /// copy of the medication's `is_active`, so deactivating a medication has to silence its
    /// schedules through this join rather than by touching their rows.
    public func getAllActiveSchedules(profileId: String) async throws -> [MedicationScheduleRecord] {
        try await database.reader.read { db in
            try MedicationScheduleRecord.fetchAll(db, sql: Self.allActiveSchedulesSql, arguments: [profileId])
        }
    }

    /// `MedicationDao.kt:90-99` — the same query as `getAllActiveSchedules`, observed once.
    public func observeAllActiveSchedules(
        profileId: String
    ) -> AsyncThrowingStream<[MedicationScheduleRecord], any Error> {
        let observation = ValueObservation.tracking { db in
            try MedicationScheduleRecord.fetchAll(db, sql: Self.allActiveSchedulesSql, arguments: [profileId])
        }
        return conflatedStream(observation.values(in: database.reader))
    }

    /// Deactivates every schedule of one medication except those named (`MedicationDao.kt:101-103`).
    ///
    /// Deactivate instead of delete: `medication_intake_logs.schedule_id` cascades, so deleting a
    /// schedule an edit dropped would erase the doses recorded against it.
    ///
    /// An empty `keepIds` deactivates *all* of that medication's schedules — the same thing Room
    /// does with an empty list, whose expansion of `IN (:keepIds)` matches no row, so `NOT IN`
    /// matches every one of them.
    public func deactivateSchedulesExcept(medicationId: String, keepIds: [String]) async throws {
        try await database.writer.write { db in
            try Self.deactivateSchedulesExcept(db, medicationId: medicationId, keepIds: keepIds)
        }
    }

    /// The medication and the complete set of its schedules, written together.
    ///
    /// iOS-only (divergence (d)): Android's repository issues the three statements as three
    /// separate writes, so a reader between them can see the new medication beside the schedule set
    /// of its previous version. Here they share one `write` block. The semantics are otherwise
    /// Android's — upsert the medication, upsert every schedule handed in, then deactivate the rest
    /// of that medication's schedules, which is a *replace* of the active set rather than a merge.
    public func saveWithSchedules(
        _ medication: MedicationRecord,
        schedules: [MedicationScheduleRecord]
    ) async throws {
        try await database.writer.write { db in
            try medication.upsert(db)
            for schedule in schedules {
                try schedule.upsert(db)
            }
            try Self.deactivateSchedulesExcept(db, medicationId: medication.id, keepIds: schedules.map(\.id))
        }
    }

    // MARK: - Intake logs

    /// Records one dose (`MedicationDao.kt:49-52`).
    ///
    /// An insert, not an upsert, and it throws: Room declares it `OnConflictStrategy.ABORT` because
    /// the unique `(schedule_id, scheduled_date, scheduled_minutes)` index is the idempotency key —
    /// a duplicate occurrence must surface as a `DatabaseError` for the caller to resolve, not be
    /// silently merged into the row already there.
    public func insertIntakeLog(_ log: MedicationIntakeLogRecord) async throws {
        try await database.writer.write { db in
            try log.insert(db)
        }
    }

    /// `MedicationDao.kt:54-55` — Room's `@Update`, which matches on the primary key. That is how
    /// recording a dose turns a `PENDING` row into a `TAKEN` one without touching the occurrence
    /// the unique index keys on.
    ///
    /// One divergence from Room, in the safe direction: `@Update` silently updates no row when the
    /// id is not there, while GRDB's update by primary key throws `RecordError.recordNotFound`.
    public func updateIntakeLog(_ log: MedicationIntakeLogRecord) async throws {
        try await database.writer.write { db in
            try log.update(db)
        }
    }

    /// `MedicationDao.kt:57-58`.
    public func getIntakeLogById(_ id: String) async throws -> MedicationIntakeLogRecord? {
        try await database.reader.read { db in
            try MedicationIntakeLogRecord.fetchOne(
                db,
                sql: "SELECT * FROM medication_intake_logs WHERE id = ?",
                arguments: [id]
            )
        }
    }

    /// One profile's recorded doses for one day, earliest dose first — the day screen
    /// (`MedicationDao.kt:60-67`).
    public func observeIntakeLogsForDay(
        profileId: String,
        epochDay: Int
    ) -> AsyncThrowingStream<[MedicationIntakeLogRecord], any Error> {
        let observation = ValueObservation.tracking { db in
            try MedicationIntakeLogRecord.fetchAll(
                db,
                sql: """
                SELECT * FROM medication_intake_logs
                WHERE profile_id = ? AND scheduled_date = ?
                ORDER BY scheduled_minutes ASC
                """,
                arguments: [profileId, epochDay]
            )
        }
        return conflatedStream(observation.values(in: database.reader))
    }

    /// Whether one occurrence already has a row (`MedicationDao.kt:69-79`), keyed by exactly the
    /// columns the unique index covers — so this is the lookup that keeps `insertIntakeLog` from
    /// having to throw in the ordinary case.
    public func getIntakeLogForOccurrence(
        scheduleId: String,
        epochDay: Int,
        minutes: Int
    ) async throws -> MedicationIntakeLogRecord? {
        try await database.reader.read { db in
            try MedicationIntakeLogRecord.fetchOne(
                db,
                sql: """
                SELECT * FROM medication_intake_logs
                WHERE schedule_id = ? AND scheduled_date = ? AND scheduled_minutes = ?
                """,
                arguments: [scheduleId, epochDay, minutes]
            )
        }
    }

    /// One profile's recorded doses over a span of days, both bounds included
    /// (`MedicationDao.kt:105-115`). No `ORDER BY` — see the file header.
    public func observeIntakeLogsBetween(
        profileId: String,
        fromEpochDay: Int,
        toEpochDay: Int
    ) -> AsyncThrowingStream<[MedicationIntakeLogRecord], any Error> {
        let observation = ValueObservation.tracking { db in
            try MedicationIntakeLogRecord.fetchAll(
                db,
                sql: Self.intakeLogsBetweenSql,
                arguments: [profileId, fromEpochDay, toEpochDay]
            )
        }
        return conflatedStream(observation.values(in: database.reader))
    }

    /// `MedicationDao.kt:117-127` — the same query as `observeIntakeLogsBetween`, read once.
    public func getIntakeLogsBetween(
        profileId: String,
        fromEpochDay: Int,
        toEpochDay: Int
    ) async throws -> [MedicationIntakeLogRecord] {
        try await database.reader.read { db in
            try MedicationIntakeLogRecord.fetchAll(
                db,
                sql: Self.intakeLogsBetweenSql,
                arguments: [profileId, fromEpochDay, toEpochDay]
            )
        }
    }

    // MARK: - Shared SQL

    /// `MedicationDao.kt:23-24` and `:29-30` are the same query, read once and observed once.
    private static let byIdSql = "SELECT * FROM medications WHERE id = ?"

    /// `MedicationDao.kt:26-27` and `:84-85` are the same query, observed once and read once.
    private static let activeSql =
        "SELECT * FROM medications WHERE profile_id = ? AND is_active = 1 ORDER BY name"

    /// `MedicationDao.kt:32-33` and `:35-36` are the same query, observed once and read once.
    private static let activeSchedulesForSql =
        "SELECT * FROM medication_schedules WHERE medication_id = ? AND is_active = 1"

    /// `MedicationDao.kt:38-47` and `:90-99` are the same query, read once and observed once.
    private static let allActiveSchedulesSql = """
    SELECT medication_schedules.* FROM medication_schedules
    INNER JOIN medications ON medications.id = medication_schedules.medication_id
    WHERE medications.profile_id = ?
        AND medications.is_active = 1
        AND medication_schedules.is_active = 1
    """

    /// `MedicationDao.kt:105-115` and `:117-127` are the same query, observed once and read once.
    private static let intakeLogsBetweenSql = """
    SELECT * FROM medication_intake_logs
    WHERE profile_id = ? AND scheduled_date BETWEEN ? AND ?
    """

    /// `MedicationDao.kt:101-103`, written once and run from two places: the statement of its own
    /// and the tail of `saveWithSchedules`, which cannot call the public one because that would
    /// open a second write inside the transaction.
    private static func deactivateSchedulesExcept(
        _ db: Database,
        medicationId: String,
        keepIds: [String]
    ) throws {
        try db.execute(
            sql: deactivateSchedulesExceptSql(keepCount: keepIds.count),
            arguments: StatementArguments([medicationId] + keepIds)
        )
    }

    /// Room expands `IN (:keepIds)` at call time and SQLite has no way to bind a list to one `?`,
    /// so the placeholders are built from the id count — and the clause is dropped entirely when
    /// there are none.
    ///
    /// Dropped rather than emitted empty, and the difference is not correctness: SQLite is one of
    /// the few engines that parses `id NOT IN ()`, reading it as "true for every row", which is
    /// exactly the behaviour wanted. It is left out anyway so the statement says what it means
    /// without leaning on an extension that no other SQL engine accepts.
    private static func deactivateSchedulesExceptSql(keepCount: Int) -> String {
        let update = "UPDATE medication_schedules SET is_active = 0 WHERE medication_id = ?"
        guard keepCount > 0 else { return update }
        let placeholders = Array(repeating: "?", count: keepCount).joined(separator: ", ")
        return "\(update) AND id NOT IN (\(placeholders))"
    }
}
