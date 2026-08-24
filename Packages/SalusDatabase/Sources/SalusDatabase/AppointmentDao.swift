// Ported 1:1 from `core/database/src/main/kotlin/com/alicansekban/salus/core/database/dao/AppointmentDao.kt`.
//
// Conventions — the plain struct over the database, the `@Query` strings carried verbatim, the
// conflated `AsyncThrowingStream` standing in for Room's `Flow` — are `ProfileDao`'s; its doc
// comments explain why each of them is what it is, and are not repeated here.
//
// Two things are worth naming here. `upsertWithReminders` is Room's `@Transaction` default method,
// so it is one `write` block: the appointment and its reminder rows are replaced together or not
// at all. And `getRemindersForAppointments` builds its `IN (…)` placeholders from the id count,
// because Room expands `IN (:ids)` at call time and SQLite has no way to bind a list to one `?`.

import GRDB

/// Reads and writes appointments and the reminder offsets hanging off them.
public struct AppointmentDao: Sendable {
    private let database: SalusDatabase

    public init(database: SalusDatabase) {
        self.database = database
    }

    /// `AppointmentDao.kt:14-15`.
    public func upsert(_ appointment: AppointmentRecord) async throws {
        try await database.writer.write { db in
            try appointment.upsert(db)
        }
    }

    /// `AppointmentDao.kt:17-18`.
    public func upsertReminders(_ reminders: [AppointmentReminderRecord]) async throws {
        try await database.writer.write { db in
            for reminder in reminders {
                try reminder.upsert(db)
            }
        }
    }

    /// The appointment and the complete set of its reminder rows, written together
    /// (`AppointmentDao.kt:20-28`).
    ///
    /// Room's `@Transaction` default method is upsert → `deleteRemindersFor` → `upsertReminders`,
    /// which is a *replace*, not a merge: a save that drops an offset drops its row. The three
    /// statements share one `write` block so a reader never sees the appointment beside the
    /// reminder rows of its previous version.
    public func upsertWithReminders(
        _ appointment: AppointmentRecord,
        reminders: [AppointmentReminderRecord]
    ) async throws {
        try await database.writer.write { db in
            try appointment.upsert(db)
            try db.execute(sql: Self.deleteRemindersForSql, arguments: [appointment.id])
            for reminder in reminders {
                try reminder.upsert(db)
            }
        }
    }

    /// `AppointmentDao.kt:30-31`.
    public func getById(_ id: String) async throws -> AppointmentRecord? {
        try await database.reader.read { db in
            try AppointmentRecord.fetchOne(
                db,
                sql: "SELECT * FROM appointments WHERE id = ?",
                arguments: [id]
            )
        }
    }

    /// One appointment, and nothing once it is deleted — which is what closes the detail screen
    /// (`AppointmentDao.kt:33-34`).
    public func observeById(_ id: String) -> AsyncThrowingStream<AppointmentRecord?, any Error> {
        let observation = ValueObservation.tracking { db in
            try AppointmentRecord.fetchOne(
                db,
                sql: "SELECT * FROM appointments WHERE id = ?",
                arguments: [id]
            )
        }
        return Self.conflatedStream(observation.values(in: database.reader))
    }

    /// `AppointmentDao.kt:36-37`.
    public func observeRemindersFor(
        appointmentId: String
    ) -> AsyncThrowingStream<[AppointmentReminderRecord], any Error> {
        let observation = ValueObservation.tracking { db in
            try AppointmentReminderRecord.fetchAll(db, sql: Self.remindersForSql, arguments: [appointmentId])
        }
        return Self.conflatedStream(observation.values(in: database.reader))
    }

    /// One profile's still-scheduled appointments from an instant onward, soonest first
    /// (`AppointmentDao.kt:39-46`). The bound is inclusive: an appointment starting exactly at
    /// `fromEpochMs` is upcoming.
    public func observeUpcoming(
        profileId: String,
        fromEpochMs: Int64
    ) -> AsyncThrowingStream<[AppointmentRecord], any Error> {
        let observation = ValueObservation.tracking { db in
            try AppointmentRecord.fetchAll(
                db,
                sql: """
                SELECT * FROM appointments
                WHERE profile_id = ? AND starts_at_epoch_ms >= ? AND status = 'SCHEDULED'
                ORDER BY starts_at_epoch_ms ASC
                """,
                arguments: [profileId, fromEpochMs]
            )
        }
        return Self.conflatedStream(observation.values(in: database.reader))
    }

    /// The complement of `observeUpcoming`, newest first (`AppointmentDao.kt:48-55`). The `OR`
    /// is deliberate: a `COMPLETED` or `CANCELLED` appointment is past however far in the future
    /// it starts, which is why the two queries partition the profile's rows between them.
    public func observePast(
        profileId: String,
        beforeEpochMs: Int64
    ) -> AsyncThrowingStream<[AppointmentRecord], any Error> {
        let observation = ValueObservation.tracking { db in
            try AppointmentRecord.fetchAll(
                db,
                sql: """
                SELECT * FROM appointments
                WHERE profile_id = ? AND (starts_at_epoch_ms < ? OR status != 'SCHEDULED')
                ORDER BY starts_at_epoch_ms DESC
                """,
                arguments: [profileId, beforeEpochMs]
            )
        }
        return Self.conflatedStream(observation.values(in: database.reader))
    }

    /// `AppointmentDao.kt:57-58`.
    public func getRemindersFor(appointmentId: String) async throws -> [AppointmentReminderRecord] {
        try await database.reader.read { db in
            try AppointmentReminderRecord.fetchAll(db, sql: Self.remindersForSql, arguments: [appointmentId])
        }
    }

    /// `AppointmentDao.kt:60-61`.
    public func deleteRemindersFor(appointmentId: String) async throws {
        try await database.writer.write { db in
            try db.execute(sql: Self.deleteRemindersForSql, arguments: [appointmentId])
        }
    }

    /// `AppointmentDao.kt:63-64`. The reminder rows go with it — `appointment_reminders`'
    /// foreign key cascades and `SalusDatabase` keeps foreign keys on.
    public func deleteById(_ id: String) async throws {
        try await database.writer.write { db in
            try db.execute(sql: "DELETE FROM appointments WHERE id = ?", arguments: [id])
        }
    }

    /// Every still-scheduled appointment of one profile, in no promised order — what the reminder
    /// scheduler enumerates (`AppointmentDao.kt:66-67`).
    public func getScheduled(profileId: String) async throws -> [AppointmentRecord] {
        try await database.reader.read { db in
            try AppointmentRecord.fetchAll(
                db,
                sql: "SELECT * FROM appointments WHERE profile_id = ? AND status = 'SCHEDULED'",
                arguments: [profileId]
            )
        }
    }

    /// The reminder rows of several appointments in one read (`AppointmentDao.kt:69-70`), so a
    /// caller holding a list of appointments does not pay a round trip each.
    ///
    /// An empty list answers empty without touching the database: Room expands `IN (:ids)` into a
    /// query that matches no row, while the SQL that expansion would produce here — `IN ()` — is
    /// not something SQLite will parse.
    public func getRemindersForAppointments(ids: [String]) async throws -> [AppointmentReminderRecord] {
        guard !ids.isEmpty else { return [] }
        let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ", ")
        return try await database.reader.read { db in
            try AppointmentReminderRecord.fetchAll(
                db,
                sql: "SELECT * FROM appointment_reminders WHERE appointment_id IN (\(placeholders))",
                arguments: StatementArguments(ids)
            )
        }
    }

    /// Every reminder row belonging to one profile's appointments (`AppointmentDao.kt:72-79`).
    /// `appointment_reminders` carries no `profile_id` of its own, so the join is what scopes it.
    public func observeRemindersForProfile(
        profileId: String
    ) -> AsyncThrowingStream<[AppointmentReminderRecord], any Error> {
        let observation = ValueObservation.tracking { db in
            try AppointmentReminderRecord.fetchAll(
                db,
                sql: """
                SELECT appointment_reminders.* FROM appointment_reminders
                INNER JOIN appointments ON appointments.id = appointment_reminders.appointment_id
                WHERE appointments.profile_id = ?
                """,
                arguments: [profileId]
            )
        }
        return Self.conflatedStream(observation.values(in: database.reader))
    }

    /// `AppointmentDao.kt:36-37` and `:57-58` are the same query, observed once and read once.
    private static let remindersForSql = "SELECT * FROM appointment_reminders WHERE appointment_id = ?"

    /// `AppointmentDao.kt:60-61`, written twice: `deleteRemindersFor` is a statement of its own and
    /// also the middle of `upsertWithReminders`, which cannot call it because that would open a
    /// second write inside the transaction.
    private static let deleteRemindersForSql = "DELETE FROM appointment_reminders WHERE appointment_id = ?"

    /// The bridge from a GRDB observation to the conflated, throwing stream a ported `Flow` is —
    /// see `ProfileDao.observeDefaultProfile` for why it conflates and why it throws.
    private static func conflatedStream<Value: Sendable>(
        _ values: AsyncValueObservation<Value>
    ) -> AsyncThrowingStream<Value, any Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                do {
                    for try await value in values {
                        continuation.yield(value)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            // A consumer that stops reading must stop the observation too, or it keeps
            // re-querying for nobody.
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
