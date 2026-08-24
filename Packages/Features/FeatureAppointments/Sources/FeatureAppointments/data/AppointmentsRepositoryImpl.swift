// Ported 1:1 from `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/
// appointments/data/AppointmentsRepositoryImpl.kt`.

import Foundation
import SalusCommon
import SalusDatabase
import SalusReminder

/// The only implementation of `AppointmentsRepository` (`AppointmentsRepositoryImpl.kt:16-74`).
///
/// A `final class` with immutable, `Sendable` storage, so the `Sendable` conformance the protocol
/// requires is checked rather than promised.
public final class AppointmentsRepositoryImpl: AppointmentsRepository {
    private let appointmentDao: AppointmentDao
    private let profileId: String
    private let reminderScheduler: any ReminderScheduler
    private let clock: any SalusClock

    /// The `profileId` default is the value Koin passes at the single construction site
    /// (`SalusDatabase.DEFAULT_PROFILE_ID`). It stays a parameter so a test can point the
    /// repository at another profile and prove the scoping is real — `VitalsRepositoryImpl`'s
    /// shape.
    public init(
        appointmentDao: AppointmentDao,
        profileId: String = SalusDatabase.defaultProfileId,
        reminderScheduler: any ReminderScheduler,
        clock: any SalusClock
    ) {
        self.appointmentDao = appointmentDao
        self.profileId = profileId
        self.reminderScheduler = reminderScheduler
        self.clock = clock
    }

    /// `AppointmentsRepositoryImpl.kt:24-25`.
    public func observeUpcoming(from: Date) -> AsyncThrowingStream<[Appointment], any Error> {
        withReminders(appointmentDao.observeUpcoming(profileId: profileId, fromEpochMs: from.epochMilliseconds))
    }

    /// `AppointmentsRepositoryImpl.kt:27-28`.
    public func observePast(before: Date) -> AsyncThrowingStream<[Appointment], any Error> {
        withReminders(appointmentDao.observePast(profileId: profileId, beforeEpochMs: before.epochMilliseconds))
    }

    /// `AppointmentsRepositoryImpl.kt:30-34`.
    public func observeAppointment(id: String) -> AsyncThrowingStream<Appointment?, any Error> {
        latestOfBoth(
            appointmentDao.observeById(id),
            appointmentDao.observeRemindersFor(appointmentId: id)
        ) { record, reminders in
            try record?.toDomain(reminders: reminders)
        }
    }

    /// `AppointmentsRepositoryImpl.kt:36-39`.
    public func getAppointment(id: String) async throws -> Appointment? {
        guard let record = try await appointmentDao.getById(id) else { return nil }
        return try await record.toDomain(reminders: appointmentDao.getRemindersFor(appointmentId: record.id))
    }

    /// `AppointmentsRepositoryImpl.kt:41-48`.
    ///
    /// The early return is not a micro-optimisation: `getRemindersForAppointments(ids: [])` would
    /// build an `IN ()` statement, and the reminder handler calls this on every sync.
    public func getScheduledAppointments() async throws -> [Appointment] {
        let records = try await appointmentDao.getScheduled(profileId: profileId)
        if records.isEmpty {
            return []
        }
        let remindersByAppointment = try await Dictionary(
            grouping: appointmentDao.getRemindersForAppointments(ids: records.map(\.id)),
            by: \.appointmentId
        )
        return try records.map { try $0.toDomain(reminders: remindersByAppointment[$0.id] ?? []) }
    }

    /// `AppointmentsRepositoryImpl.kt:50-59`.
    ///
    /// `created_at` is read from the existing row and written back, so an edit does not restamp the
    /// appointment as new; `updated_at` is always the current instant.
    public func saveAppointment(_ appointment: Appointment) async throws {
        let nowEpochMs = clock.nowEpochMilliseconds()
        let createdAtEpochMs = try await appointmentDao.getById(appointment.id)?.createdAtEpochMs ?? nowEpochMs
        try await appointmentDao.upsertWithReminders(
            appointment.toRecord(
                profileId: profileId,
                createdAtEpochMs: createdAtEpochMs,
                updatedAtEpochMs: nowEpochMs
            ),
            reminders: appointment.toReminderRecords()
        )
        // Keeps the scheduled alarms in step with the database after every mutation (no orphan
        // alarms). It runs *after* the write, so a failed write never schedules against rows that
        // were not stored.
        reminderScheduler.requestSync()
    }

    /// `AppointmentsRepositoryImpl.kt:61-65`.
    public func deleteAppointment(id: String) async throws {
        // `appointment_reminders` rows cascade with the appointment row.
        try await appointmentDao.deleteById(id)
        reminderScheduler.requestSync()
    }

    /// `AppointmentsRepositoryImpl.kt:67-73` — the appointment stream joined with the profile's
    /// reminder rows, grouped by `appointmentId`. One reminder observation serves the whole list,
    /// which is why the DAO exposes a profile-wide query rather than one per appointment.
    private func withReminders(
        _ source: AsyncThrowingStream<[AppointmentRecord], any Error>
    ) -> AsyncThrowingStream<[Appointment], any Error> {
        latestOfBoth(source, appointmentDao.observeRemindersForProfile(profileId: profileId)) { records, reminders in
            let remindersByAppointment = Dictionary(grouping: reminders, by: \.appointmentId)
            return try records.map { try $0.toDomain(reminders: remindersByAppointment[$0.id] ?? []) }
        }
    }
}
