// Ported 1:1 from Android
// `core/model/src/main/kotlin/com/alicansekban/salus/core/model/Reminder.kt`.

/// What a scheduled reminder is for.
///
/// Raw values are the Kotlin constant names (`Reminder.kt:3-8`), which is what is persisted.
public enum ReminderType: String, CaseIterable, Equatable, Hashable, Sendable {
    case medicationDose = "MEDICATION_DOSE"
    case appointment = "APPOINTMENT"
    case snooze = "SNOOZE"
    case cyclePeriod = "CYCLE_PERIOD"
}

/// The lifecycle of one alarm slot.
///
/// Raw values are the Kotlin constant names (`Reminder.kt:10-17`).
public enum AlarmState: String, CaseIterable, Equatable, Hashable, Sendable {
    case scheduled = "SCHEDULED"
    case fired = "FIRED"
    /// A `scheduled` alarm whose trigger time is already in the past when the window is
    /// re-synced (device was off, app force-stopped, alarm dropped by the OS).
    case missed = "MISSED"
    case cancelled = "CANCELLED"
}
