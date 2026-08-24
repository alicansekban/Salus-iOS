// Ported 1:1 from `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/
// appointments/domain/model/Appointment.kt`.

import Foundation
import SalusModel

/// A doctor/clinic appointment, as the feature's domain sees it (`Appointment.kt:13-30`).
///
/// The model lives in the feature rather than in `SalusModel` because Android puts it there:
/// `:core:model` holds only cross-module vocabulary, which for appointments is the
/// `AppointmentStatus` enum alone.
///
/// `startsAt` carries **wall-clock** semantics: the appointment happens at that local time
/// whatever the device's zone later becomes, so an absolute instant is always *derived* from it
/// with the zone current at the moment of the computation — never stored as the truth. That is
/// why the type holds a `LocalDateTime` and not a `Date`, and why `starts_at_epoch_ms` is a cache
/// the save path recomputes rather than a column anything reads back into this model.
///
/// The `timeZone` beside it is the zone the appointment was created in, kept for auditing and for
/// deriving that cache — the same `local + tz_id` pair the schema stores.
///
/// Kotlin's `data class` gives value equality; the `struct` gives it, plus `Sendable` for free.
/// The conformance set is `SalusModel.Profile`'s, for the same reason it is there.
public struct Appointment: Equatable, Hashable, Sendable {
    /// `Appointment.kt:28` — the duration a new appointment gets when nothing says otherwise.
    public static let defaultDurationMinutes = 60

    public let id: String
    public let title: String
    public let doctorName: String?
    public let specialty: String?
    public let location: String?
    public let notes: String?
    public let startsAt: LocalDateTime
    public let timeZone: TimeZone
    public let durationMinutes: Int
    public let status: AppointmentStatus
    /// Enabled reminder offsets, minutes before `startsAt`, ascending (`Appointment.kt:25`).
    public let reminderOffsetsMinutes: [Int]

    public init(
        id: String,
        title: String,
        doctorName: String?,
        specialty: String?,
        location: String?,
        notes: String?,
        startsAt: LocalDateTime,
        timeZone: TimeZone,
        durationMinutes: Int,
        status: AppointmentStatus,
        reminderOffsetsMinutes: [Int]
    ) {
        self.id = id
        self.title = title
        self.doctorName = doctorName
        self.specialty = specialty
        self.location = location
        self.notes = notes
        self.startsAt = startsAt
        self.timeZone = timeZone
        self.durationMinutes = durationMinutes
        self.status = status
        self.reminderOffsetsMinutes = reminderOffsetsMinutes
    }
}
