// Ported from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// ui/MedicationFormatting.kt`.
//
// THREE OF THE KOTLIN FILE'S FIVE HELPERS ARE HERE; the two that are not are the two that map a
// `MedicationForm` onto an icon and onto a label, and they land with the screens that draw them
// (iOS-M5 Task 10) — a form-to-SF-Symbol table is a design-system decision, and this file must
// stay importable by the reminder handler, which draws nothing.
//
// `formatAmount` is the SINGLE copy of the trim-".0" rule. Android spells it three times (here,
// in the reminder handler and in the editor); the port keeps one, and the other two call it.
//
// Kotlin's `scheduleSummary` is a `@Composable` that resolves each label with `stringResource`.
// A Swift accessor already *is* the resolved string, so the labels travel in as a value instead —
// see ``ScheduleSummaryStrings`` for why they travel at all rather than being read here.
//
// Foundation only — not even `SalusModel`: every recurrence case is reached through
// `MedicationSchedule.recurrence`, so nothing here has to name the enum. No view framework
// either, which is what lets the reminder handler call `formatAmount` from a background actor.

import Foundation

/// The four recurrence labels and the empty-list fallback ``scheduleSummary(schedules:strings:locale:)``
/// can return (`MedicationFormatting.kt:49-63`).
///
/// They travel as a value rather than being read from ``MedicationsStrings`` inside the function
/// for one reason: `swift test` copies a `.xcstrings` into the resource bundle verbatim instead of
/// compiling it, so a live lookup under the test gate answers with the key and an assertion on the
/// composed sentence would stop describing the composition rule. ``localized`` is the shipped set
/// and is the only thing production passes.
struct ScheduleSummaryStrings: Sendable {
    let noSchedule: String
    let daily: String
    let daysOfWeek: String
    let asNeeded: String
    let everyNDays: @Sendable (Int) -> String

    /// Read from the feature's catalog on every access, so a locale change is picked up.
    static var localized: ScheduleSummaryStrings {
        ScheduleSummaryStrings(
            noSchedule: MedicationsStrings.noSchedule,
            daily: MedicationsStrings.recurrenceDaily,
            daysOfWeek: MedicationsStrings.recurrenceDaysOfWeek,
            asNeeded: MedicationsStrings.recurrenceAsNeeded,
            everyNDays: { MedicationsStrings.recurrenceEveryNDays(days: $0) }
        )
    }
}

/// Whole numbers lose their ".0": "1 tablet", not "1.0 tablet"
/// (`MedicationFormatting.kt:41-42`).
func formatAmount(_ value: Double) -> String {
    // Kotlin is `if (value % 1.0 == 0.0) value.toInt().toString() else value.toString()`. The
    // `Int(exactly:)` is the one thing added, and it is added because Swift traps where Kotlin
    // does not: `Double.toInt()` saturates at `Int.MAX_VALUE`, while `Int(_: Double)` crashes the
    // app for anything past `Int.max` — and a decimal keypad can produce twenty digits. A dose
    // that large is nonsense on both platforms, so the fallback prints the Double as it is rather
    // than inventing a clamp Android never shows either.
    guard value.truncatingRemainder(dividingBy: 1.0) == 0.0, let whole = Int(exactly: value) else {
        return String(value)
    }
    return String(whole)
}

/// `MedicationFormatting.kt:44-45`.
func formatTime(minuteOfDay: Int, locale: Locale) -> String {
    String(format: "%02d:%02d", locale: locale, minuteOfDay / 60, minuteOfDay % 60)
}

/// "Every day · 09:00, 21:00" — recurrence from the first schedule, times from all of them
/// (`MedicationFormatting.kt:47-66`).
func scheduleSummary(
    schedules: [MedicationSchedule],
    strings: ScheduleSummaryStrings,
    locale: Locale
) -> String {
    guard let first = schedules.first else { return strings.noSchedule }
    if first.recurrence == .asNeeded {
        return strings.asNeeded
    }
    let times = schedules.map(\.timeOfDayMinutes).sorted()
        .map { formatTime(minuteOfDay: $0, locale: locale) }
        .joined(separator: ", ")
    let recurrenceLabel = switch first.recurrence {
    case .daily: strings.daily
    case .daysOfWeek: strings.daysOfWeek
    case .intervalDays: strings.everyNDays(first.intervalDays ?? 1)
    case .asNeeded: strings.asNeeded
    }
    return "\(recurrenceLabel) · \(times)"
}
