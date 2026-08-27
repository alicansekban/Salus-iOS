// Ported 1:1 from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/
// medications/data/MedicationMappers.kt`.
//
// The Kotlin functions are `internal`; so are these, which is the same reach — a Swift module is
// the unit Gradle calls a module. This file is the only place a `MedicationRecord`,
// `MedicationScheduleRecord` or `MedicationIntakeLogRecord` becomes a domain type, which is what
// keeps `SalusDatabase`'s records inside the repository as `CLAUDE.md` requires.
//
// **The three enums fall back rather than throw** (recorded divergence (e), against M4's
// `AppointmentMapper`, which throws on an unreadable `status`). Kotlin reads them with
// `entries.firstOrNull { it.name == … } ?: DEFAULT` — `OTHER` for a form, `DAILY` for a
// recurrence, `PENDING` for an intake status — and that fallback is a *tested* behaviour
// (`MedicationMappersTest.kt:65-80`), so it is the port. The two features differ on purpose: an
// appointment's `status` and wall clock are *when it is*, so a substituted value moves it or
// resurrects a cancelled row, while a spelling this build does not know here is a future Android
// version's arriving through a backup — degrading one schedule to DAILY keeps the rest of the
// list readable, where throwing would blank it.

import SalusDatabase
import SalusModel

/// `MedicationMappers.kt:13-26`.
extension MedicationRecord {
    func toDomain() -> Medication {
        Medication(
            id: id,
            name: name,
            form: MedicationForm(rawValue: form) ?? .other,
            strengthValue: strengthValue,
            strengthUnit: strengthUnit,
            instructions: instructions,
            stockCount: stockCount,
            stockThreshold: stockThreshold,
            startDateEpochDay: startDateEpochDay,
            endDateEpochDay: endDateEpochDay,
            isActive: isActive,
            remindersEnabled: remindersEnabled
        )
    }
}

extension Medication {
    /// `MedicationMappers.kt:28-51`.
    ///
    /// `colorToken`, the two timestamps and `remindersEnabled` are parameters rather than model
    /// fields because the model does not own them: the first three are stored metadata the editor
    /// never sends, and the flag has a single write path (`setRemindersEnabled`). The repository is
    /// the one place that decides each of the four. `remindersEnabled` is passed explicitly here
    /// even though `MedicationRecord`'s initialiser defaults it — Kotlin's entity has no default
    /// for it, and a defaulted argument would let a caller silently re-enable a silenced
    /// medication.
    func toRecord(
        profileId: String,
        colorToken: String,
        createdAtEpochMs: Int64,
        updatedAtEpochMs: Int64,
        remindersEnabled: Bool
    ) -> MedicationRecord {
        MedicationRecord(
            id: id,
            profileId: profileId,
            name: name,
            form: form.rawValue,
            strengthValue: strengthValue,
            strengthUnit: strengthUnit,
            colorToken: colorToken,
            instructions: instructions,
            stockCount: stockCount,
            stockThreshold: stockThreshold,
            startDateEpochDay: startDateEpochDay,
            endDateEpochDay: endDateEpochDay,
            isActive: isActive,
            remindersEnabled: remindersEnabled,
            createdAtEpochMs: createdAtEpochMs,
            updatedAtEpochMs: updatedAtEpochMs
        )
    }
}

/// `MedicationMappers.kt:53-63`.
extension MedicationScheduleRecord {
    func toDomain() -> MedicationSchedule {
        MedicationSchedule(
            id: id,
            medicationId: medicationId,
            recurrence: Recurrence(rawValue: recurrence) ?? .daily,
            daysOfWeekMask: daysOfWeekMask,
            intervalDays: intervalDays,
            anchorDateEpochDay: anchorDateEpochDay,
            timeOfDayMinutes: timeOfDayMinutes,
            doseAmount: doseAmount,
            isActive: isActive
        )
    }
}

/// `MedicationMappers.kt:65-75`.
extension MedicationSchedule {
    func toRecord() -> MedicationScheduleRecord {
        MedicationScheduleRecord(
            id: id,
            medicationId: medicationId,
            recurrence: recurrence.rawValue,
            daysOfWeekMask: daysOfWeekMask,
            intervalDays: intervalDays,
            anchorDateEpochDay: anchorDateEpochDay,
            timeOfDayMinutes: timeOfDayMinutes,
            doseAmount: doseAmount,
            isActive: isActive
        )
    }
}

/// `MedicationMappers.kt:77-88`.
///
/// The column names and the model's differ on purpose, on both platforms: the row calls the pair
/// `scheduled_date` / `scheduled_minutes` because they say *when the dose was due*, and the model
/// calls them `epochDay` / `minuteOfDay` because that is the vocabulary `DoseOccurrence` uses.
extension MedicationIntakeLogRecord {
    func toDomain() -> IntakeLog {
        IntakeLog(
            id: id,
            scheduleId: scheduleId,
            medicationId: medicationId,
            epochDay: scheduledDateEpochDay,
            minuteOfDay: scheduledMinutes,
            status: IntakeStatus(rawValue: status) ?? .pending,
            takenAtEpochMs: takenAtEpochMs,
            snoozedUntilEpochMs: snoozedUntilEpochMs,
            doseAmount: doseAmount,
            note: note
        )
    }
}

/// `MedicationMappers.kt:90-102`.
extension IntakeLog {
    func toRecord(profileId: String) -> MedicationIntakeLogRecord {
        MedicationIntakeLogRecord(
            id: id,
            scheduleId: scheduleId,
            medicationId: medicationId,
            profileId: profileId,
            scheduledDateEpochDay: epochDay,
            scheduledMinutes: minuteOfDay,
            status: status.rawValue,
            takenAtEpochMs: takenAtEpochMs,
            snoozedUntilEpochMs: snoozedUntilEpochMs,
            doseAmount: doseAmount,
            note: note
        )
    }
}
