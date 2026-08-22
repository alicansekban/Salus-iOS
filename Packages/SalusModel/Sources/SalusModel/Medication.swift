// Ported 1:1 from Android
// `core/model/src/main/kotlin/com/alicansekban/salus/core/model/Medication.kt`.
//
// Every raw value is the Kotlin constant name verbatim: Room persists the enum `name` and the
// backup format carries the same string across platforms (spec §9), so these are wire format,
// not display strings.

/// The physical form of a medication.
///
/// Raw values are the Kotlin constant names (`Medication.kt:3-12`).
public enum MedicationForm: String, CaseIterable, Equatable, Hashable, Sendable {
    case tablet = "TABLET"
    case capsule = "CAPSULE"
    case syrup = "SYRUP"
    case injection = "INJECTION"
    case drop = "DROP"
    case inhaler = "INHALER"
    case cream = "CREAM"
    case other = "OTHER"
}

/// How often a schedule repeats. `RecurrenceRule` turns this into per-day occurrences.
///
/// Raw values are the Kotlin constant names (`Medication.kt:14-19`).
public enum Recurrence: String, CaseIterable, Equatable, Hashable, Sendable {
    case daily = "DAILY"
    case daysOfWeek = "DAYS_OF_WEEK"
    case intervalDays = "INTERVAL_DAYS"
    case asNeeded = "AS_NEEDED"
}

/// What happened to a single dose occurrence.
///
/// Raw values are the Kotlin constant names (`Medication.kt:21-26`).
public enum IntakeStatus: String, CaseIterable, Equatable, Hashable, Sendable {
    case pending = "PENDING"
    case taken = "TAKEN"
    case skipped = "SKIPPED"
    case missed = "MISSED"
}
