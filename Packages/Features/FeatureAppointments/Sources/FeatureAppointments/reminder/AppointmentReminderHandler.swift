// Ported 1:1 from `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/
// appointments/reminder/AppointmentReminderHandler.kt`.
//
// Kotlin's `suspend fun` becomes `async throws`: the repository this reads is database-backed on
// both platforms, and the iOS port carries the query failure to the caller rather than swallowing
// it (`AppointmentsRepository.swift` spells out why). A `class` becomes a `struct` — the type holds
// three injected references and no state of its own, which is what `ReminderHandler: Sendable`
// wants anyway.

import Foundation
import SalusCommon
import SalusModel
import SalusReminder

/// The feature's handler for ``ReminderType/appointment``
/// (`AppointmentReminderHandler.kt:35-77`).
///
/// Appointment date-times carry **wall-clock** semantics, so every absolute instant is recomputed
/// from the stored local date-time with the zone the clock reports *at call time* — never with the
/// `timeZone` the appointment was created in. A device that flew across zones, or a DST boundary,
/// therefore moves the reminder with the wall clock, and the window re-sync upstream is what makes
/// the move take effect.
public struct AppointmentReminderHandler: ReminderHandler {
    /// Stable, deterministic identity of one appointment reminder offset
    /// (`AppointmentReminderHandler.kt:74-75`).
    ///
    /// The separator is a **pipe**, and it is not the `appointment_reminders.id` separator: that
    /// row id is `"<appointmentId>:<offset>"` with a colon (`AppointmentMapper.swift`). Two
    /// different identities of the same pair, and confusing them would make the engine's diff
    /// mistake a stored row for an occurrence.
    public static func occurrenceKey(appointmentId: String, offsetMinutes: Int) -> String {
        "\(appointmentId)|\(offsetMinutes)"
    }

    public let type: ReminderType = .appointment

    private let repository: any AppointmentsRepository
    private let clock: any SalusClock
    private let texts: any AppointmentNotificationTexts

    public init(
        repository: any AppointmentsRepository,
        clock: any SalusClock,
        texts: any AppointmentNotificationTexts
    ) {
        self.repository = repository
        self.clock = clock
        self.texts = texts
    }

    /// `AppointmentReminderHandler.kt:41-60`.
    ///
    /// An appointment whose start is already behind `from` is skipped **whole**, offsets and all:
    /// its lead-time reminders are further in the past still, so none of them can land in a window
    /// that begins at `from`. The window is half-open — `from` included, `until` excluded — so two
    /// consecutive syncs never materialize the same trigger twice.
    public func occurrencesBetween(from: Date, until: Date) async throws -> [ReminderOccurrence] {
        let zone = clock.timeZone()
        return try await repository.getScheduledAppointments().flatMap { appointment -> [ReminderOccurrence] in
            let startsAt = appointment.startsAt.instant(in: zone)
            guard startsAt >= from else { return [] }
            return appointment.reminderOffsetsMinutes.compactMap { offsetMinutes in
                let triggerAt = startsAt.addingTimeInterval(-Double(offsetMinutes) * 60)
                guard triggerAt >= from, triggerAt < until else { return nil }
                return ReminderOccurrence(
                    entityId: appointment.id,
                    occurrenceKey: Self.occurrenceKey(appointmentId: appointment.id, offsetMinutes: offsetMinutes),
                    triggerAt: triggerAt
                )
            }
        }
    }

    /// `AppointmentReminderHandler.kt:62-70`.
    ///
    /// A reminder is materialized ahead of time and fires later, by which point the appointment may
    /// have been deleted, cancelled, completed or moved into the past — each of which means there
    /// is nothing worth saying, so the content is nil and the engine drops the notification.
    ///
    /// Neither actions nor presentation are passed: appointments declare no actions
    /// (`onAction` is left at the protocol's empty default) and are **never** alarms, so the
    /// defaults `[]` and `.notification` are exactly the Kotlin behaviour.
    public func notificationContent(for ref: ReminderRef) async throws -> ReminderNotificationContent? {
        guard let appointment = try await repository.getAppointment(id: ref.entityId),
              isStillRelevant(appointment)
        else {
            return nil
        }
        return ReminderNotificationContent(
            title: texts.title(appointmentTitle: appointment.title),
            text: texts.body(
                startsAt: appointment.startsAt,
                doctorName: appointment.doctorName,
                location: appointment.location
            )
        )
    }

    /// `AppointmentReminderHandler.kt:72`.
    private func isStillRelevant(_ appointment: Appointment) -> Bool {
        appointment.status == .scheduled && appointment.startsAt.instant(in: clock.timeZone()) >= clock.now()
    }
}
