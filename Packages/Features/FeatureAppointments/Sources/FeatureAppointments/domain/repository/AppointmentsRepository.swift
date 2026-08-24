// Ported 1:1 from `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/
// appointments/domain/repository/AppointmentsRepository.kt`.
//
// Kotlin's `Flow<T>` becomes `AsyncThrowingStream<T, any Error>` and its `suspend fun` becomes
// `async throws` for the reason `VitalsRepository.swift` spells out: a database-backed `Flow` lets
// a query failure reach its collector, and a non-throwing stream here would have to swallow it and
// end quietly — an empty screen where Android shows a failure. The `throws` is the port, not an
// addition, and here it also carries the mapper's failures (an unreadable `tz_id`, `status` or
// `starts_at_local`).

import Foundation

/// Read/write access to the current profile's appointments (`AppointmentsRepository.kt:9-30`).
public protocol AppointmentsRepository: Sendable {
    /// `SCHEDULED` appointments starting at or after `from`, soonest first
    /// (`AppointmentsRepository.kt:12`). The bound is inclusive, as the DAO's `>=` is.
    func observeUpcoming(from: Date) -> AsyncThrowingStream<[Appointment], any Error>

    /// Appointments that already started before `before`, or that are not `SCHEDULED`, newest
    /// first (`AppointmentsRepository.kt:15`). The `or` is what makes the two observations a
    /// partition of the profile's rows rather than two overlapping windows.
    func observePast(before: Date) -> AsyncThrowingStream<[Appointment], any Error>

    /// `AppointmentsRepository.kt:17`.
    func getAppointment(id: String) async throws -> Appointment?

    /// Emits nil once the appointment is gone, so the detail screen can close itself
    /// (`AppointmentsRepository.kt:20`).
    func observeAppointment(id: String) -> AsyncThrowingStream<Appointment?, any Error>

    /// Every `SCHEDULED` appointment whatever its date; the source of truth for the reminder
    /// handler (`AppointmentsRepository.kt:23`).
    func getScheduledAppointments() async throws -> [Appointment]

    /// Upserts the appointment and replaces its reminder offsets atomically
    /// (`AppointmentsRepository.kt:26`).
    func saveAppointment(_ appointment: Appointment) async throws

    /// `AppointmentsRepository.kt:28`.
    func deleteAppointment(id: String) async throws
}
