// Ported 1:1 from `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/
// appointments/data/AppointmentMapper.kt`.
//
// The Kotlin functions are `internal`; so are these, which is the same reach — a Swift module is
// the unit Gradle calls a module. This file is the only place an `AppointmentRecord` becomes an
// `Appointment`, which is what keeps `SalusDatabase`'s records inside the repository as
// `CLAUDE.md` requires.

import Foundation
import SalusCommon
import SalusDatabase
import SalusModel

/// A stored value this platform cannot read back.
///
/// Kotlin reads the two columns below with `LocalDateTime.parse` and `AppointmentStatus.valueOf`,
/// both of which throw an `IllegalArgumentException` on a value they do not recognise
/// (`AppointmentMapper.kt:21`, `:24`). Swift's twins are failable initialisers, so the failure has
/// to be raised here. It is a separate type from `IllegalTimeZoneError` because Kotlin raises a
/// separate type there too, and because that one is thrown from more than this file.
enum MalformedAppointmentRecordError: Error, Equatable {
    /// `starts_at_local` did not parse as an ISO-8601 local date-time.
    case startsAtLocal(String)
    /// `status` is not one of `AppointmentStatus`'s stored spellings.
    case status(String)
}

/// `AppointmentMapper.kt:14-29`.
extension AppointmentRecord {
    /// - Throws: `IllegalTimeZoneError.unknownTimeZone` when `tz_id` names a zone this platform
    ///   cannot resolve (`AppointmentMapper.kt:22`, `TimeZone.of`), or
    ///   `MalformedAppointmentRecordError` for a `starts_at_local` or `status` it cannot read.
    ///   Degrading to a default instead would be quieter and wrong: the zone and the wall clock
    ///   together are *when the appointment is*, so a silent substitution moves it to another
    ///   hour or another day with nothing to show for it, and a defaulted status would resurrect
    ///   a cancelled appointment as a scheduled one. The repository's streams finish with the
    ///   error, the way a Kotlin `Flow.map` whose lambda throws does.
    ///
    ///   Recorded, not fixed here: Foundation's `TimeZone(identifier:)` rejects the fixed-offset
    ///   spellings (`"+03:00"`, `"UTC+03:00"`) that `kotlinx.datetime.TimeZone.of` accepts — the
    ///   same difference `WeightEntryMapper` records, and reachable the same way, through a backup
    ///   written by a future Android build.
    func toDomain(reminders: [AppointmentReminderRecord]) throws -> Appointment {
        guard let startsAt = LocalDateTime(isoLocalString: startsAtLocal) else {
            throw MalformedAppointmentRecordError.startsAtLocal(startsAtLocal)
        }
        guard let timeZone = TimeZone(identifier: timeZoneId) else {
            throw IllegalTimeZoneError.unknownTimeZone(timeZoneId)
        }
        guard let status = AppointmentStatus(rawValue: status) else {
            throw MalformedAppointmentRecordError.status(status)
        }
        return Appointment(
            id: id,
            title: title,
            doctorName: doctorName,
            specialty: specialty,
            location: location,
            notes: notes,
            startsAt: startsAt,
            timeZone: timeZone,
            durationMinutes: durationMinutes,
            status: status,
            reminderOffsetsMinutes: reminders
                .filter(\.enabled)
                .map(\.offsetMinutes)
                .sorted()
        )
    }
}

extension Appointment {
    /// `AppointmentMapper.kt:32-53`.
    func toRecord(profileId: String, createdAtEpochMs: Int64, updatedAtEpochMs: Int64) -> AppointmentRecord {
        AppointmentRecord(
            id: id,
            profileId: profileId,
            title: title,
            doctorName: doctorName,
            specialty: specialty,
            location: location,
            notes: notes,
            // `LocalDateTime.isoLocalString` is the twin of `LocalDateTime.toString()`: ISO-8601
            // without an offset, which is the column's contract.
            startsAtLocal: startsAt.isoLocalString,
            timeZoneId: timeZone.identifier,
            // Derived query cache; recomputed by the reschedule pipeline on a system time or
            // time-zone change.
            startsAtEpochMs: startsAt.instant(in: timeZone).epochMilliseconds,
            durationMinutes: durationMinutes,
            status: status.rawValue,
            createdAtEpochMs: createdAtEpochMs,
            updatedAtEpochMs: updatedAtEpochMs
        )
    }

    /// `AppointmentMapper.kt:55-65`.
    ///
    /// The id is deterministic — `"<appointmentId>:<offset>"` — because rows are fully replaced on
    /// every save: the same offset on the same appointment always names the same row, so no
    /// generator is needed and no duplicate can accumulate. `enabled` is always `true` for the
    /// same reason; the model carries only the offsets that are on.
    func toReminderRecords() -> [AppointmentReminderRecord] {
        reminderOffsetsMinutes.map { offsetMinutes in
            AppointmentReminderRecord(
                id: "\(id):\(offsetMinutes)",
                appointmentId: id,
                offsetMinutes: offsetMinutes,
                enabled: true
            )
        }
    }
}
