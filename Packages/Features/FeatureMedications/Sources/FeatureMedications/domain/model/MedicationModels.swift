// Ported 1:1 from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/
// medications/domain/model/MedicationModels.kt`.
//
// Kotlin keeps the five types in one file and so does this port: they are one vocabulary, and
// splitting them here would put the file-per-type rule above the 1:1 shape the Android table
// tests read against.
//
// The models live in the feature rather than in `SalusModel` because Android puts them there:
// `:core:model` holds only the cross-module vocabulary, which for medications is the
// `MedicationForm` / `Recurrence` / `IntakeStatus` enums and `RecurrenceRule`.
//
// Kotlin's `data class` gives value equality and a hash; the `struct` gives both, plus `Sendable`
// for free. `remindersEnabled` is the one field with a default, exactly as Kotlin has it — the
// column defaults to 1, so an editor that never mentions the flag creates a medication that
// reminds.

import SalusModel

/// A medication the user is taking (`MedicationModels.kt:7-27`).
public struct Medication: Equatable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let form: MedicationForm
    public let strengthValue: Double?
    public let strengthUnit: String?
    public let instructions: String?
    public let stockCount: Double?
    public let stockThreshold: Double?
    public let startDateEpochDay: Int
    public let endDateEpochDay: Int?
    public let isActive: Bool
    /// Off silences this medication's alarms only. It stays active, its doses still appear
    /// on Home and still accept Taken/Skipped — otherwise this would be a second, hidden way
    /// to deactivate a medication.
    public let remindersEnabled: Bool

    /// `MedicationModels.kt:25-26` — both columns must be set; stock tracking is off when either
    /// is null, and "off" never reads as "low".
    public var isLowOnStock: Bool {
        guard let stockCount, let stockThreshold else { return false }
        return stockCount <= stockThreshold
    }

    public init(
        id: String,
        name: String,
        form: MedicationForm,
        strengthValue: Double?,
        strengthUnit: String?,
        instructions: String?,
        stockCount: Double?,
        stockThreshold: Double?,
        startDateEpochDay: Int,
        endDateEpochDay: Int?,
        isActive: Bool,
        remindersEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.form = form
        self.strengthValue = strengthValue
        self.strengthUnit = strengthUnit
        self.instructions = instructions
        self.stockCount = stockCount
        self.stockThreshold = stockThreshold
        self.startDateEpochDay = startDateEpochDay
        self.endDateEpochDay = endDateEpochDay
        self.isActive = isActive
        self.remindersEnabled = remindersEnabled
    }
}

/// One repeating dose slot of a medication (`MedicationModels.kt:29-42`).
public struct MedicationSchedule: Equatable, Hashable, Sendable {
    public let id: String
    public let medicationId: String
    public let recurrence: Recurrence
    /// bit 0 = Monday .. bit 6 = Sunday; only meaningful for DAYS_OF_WEEK
    public let daysOfWeekMask: Int
    public let intervalDays: Int?
    public let anchorDateEpochDay: Int
    /// Local time-of-day semantics — survives DST.
    public let timeOfDayMinutes: Int
    public let doseAmount: Double
    public let isActive: Bool

    public init(
        id: String,
        medicationId: String,
        recurrence: Recurrence,
        daysOfWeekMask: Int,
        intervalDays: Int?,
        anchorDateEpochDay: Int,
        timeOfDayMinutes: Int,
        doseAmount: Double,
        isActive: Bool
    ) {
        self.id = id
        self.medicationId = medicationId
        self.recurrence = recurrence
        self.daysOfWeekMask = daysOfWeekMask
        self.intervalDays = intervalDays
        self.anchorDateEpochDay = anchorDateEpochDay
        self.timeOfDayMinutes = timeOfDayMinutes
        self.doseAmount = doseAmount
        self.isActive = isActive
    }
}

/// A medication with the schedules it is taken on (`MedicationModels.kt:44-47`).
public struct MedicationWithSchedules: Equatable, Hashable, Sendable {
    public let medication: Medication
    public let schedules: [MedicationSchedule]

    public init(medication: Medication, schedules: [MedicationSchedule]) {
        self.medication = medication
        self.schedules = schedules
    }
}

/// One concrete dose slot: schedule × calendar day. The (scheduleId, epochDay, minutes) triple
/// is the idempotency key everywhere (DB unique index, reminder occurrenceKey).
///
/// (`MedicationModels.kt:49-55`.)
public struct DoseOccurrence: Equatable, Hashable, Sendable {
    public let scheduleId: String
    public let medicationId: String
    public let epochDay: Int
    public let minuteOfDay: Int

    public init(scheduleId: String, medicationId: String, epochDay: Int, minuteOfDay: Int) {
        self.scheduleId = scheduleId
        self.medicationId = medicationId
        self.epochDay = epochDay
        self.minuteOfDay = minuteOfDay
    }
}

/// What the user recorded for one dose occurrence (`MedicationModels.kt:57-68`).
///
/// The two timestamps are absolute instants and stay `Int64` epoch milliseconds, the width the
/// column has on both platforms — the day the row belongs to travels beside them as `epochDay`.
public struct IntakeLog: Equatable, Hashable, Sendable {
    public let id: String
    public let scheduleId: String
    public let medicationId: String
    public let epochDay: Int
    public let minuteOfDay: Int
    public let status: IntakeStatus
    public let takenAtEpochMs: Int64?
    public let snoozedUntilEpochMs: Int64?
    public let doseAmount: Double
    public let note: String?

    public init(
        id: String,
        scheduleId: String,
        medicationId: String,
        epochDay: Int,
        minuteOfDay: Int,
        status: IntakeStatus,
        takenAtEpochMs: Int64?,
        snoozedUntilEpochMs: Int64?,
        doseAmount: Double,
        note: String?
    ) {
        self.id = id
        self.scheduleId = scheduleId
        self.medicationId = medicationId
        self.epochDay = epochDay
        self.minuteOfDay = minuteOfDay
        self.status = status
        self.takenAtEpochMs = takenAtEpochMs
        self.snoozedUntilEpochMs = snoozedUntilEpochMs
        self.doseAmount = doseAmount
        self.note = note
    }
}
