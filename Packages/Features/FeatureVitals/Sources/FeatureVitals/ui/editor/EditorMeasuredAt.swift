// Ported 1:1 from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/editor/EditorMeasuredAt.kt`.

import Foundation
import SalusCommon
import SalusModel

/// `EditorMeasuredAt.kt:13` — `LocalTime(12, 0)`, as the minute of day the port stores times in.
private let middayMinuteOfDay = 12 * 60

/// Resolves the instant to persist for an editor save: keeps the original timestamp when the date
/// was not changed, uses the current time for today, and midday for past dates
/// (`EditorMeasuredAt.kt:15-38`).
///
/// Both instant↔day conversions here are the ones `CLAUDE.md` allows and no others: the day the
/// existing reading falls on is integer arithmetic over `epochMs + tz` (`Date.wallClock(in:)`), and
/// composing the saved timestamp is `SalusClock.instant(of:minuteOfDay:)`, the second and last
/// member of the calendar carve-out. Kotlin's `LocalTime` is a minute of day here, so
/// `clock.localTimeNow()` reads as `clock.minuteOfDayNow()` (`SalusClock.swift:8-12`).
func resolveEditorMeasuredAt(
    clock: any SalusClock,
    selectedEpochDay: Int?,
    existingMeasuredAt: Date?,
    existingTimeZone: TimeZone?
) -> Date {
    let zone = clock.timeZone()
    // `EditorMeasuredAt.kt:27-31` — read in the zone the reading was *taken* in, falling back to
    // the clock's only when the entry carries none.
    let existingDay = existingMeasuredAt?.wallClock(in: existingTimeZone ?? zone).date.epochDay

    if let existingMeasuredAt, selectedEpochDay == nil || selectedEpochDay == existingDay {
        return existingMeasuredAt
    }

    let today = clock.today()
    let date = selectedEpochDay.map { LocalDate(epochDay: $0) } ?? today
    let minuteOfDay = date == today ? clock.minuteOfDayNow() : middayMinuteOfDay
    return clock.instant(of: date, minuteOfDay: minuteOfDay)
}
