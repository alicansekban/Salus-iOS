// The zone-ful half of `SalusModel.LocalDateTime`: the twin of
// `kotlinx.datetime.LocalDateTime.toInstant(TimeZone)`.
//
// It lives here rather than beside the type because it is the one direction that cannot be done
// with integer arithmetic — a wall-clock reading only becomes an instant through a calendar in a
// zone — and `CLAUDE.md`'s `LocalDate` rule allows exactly one place in the tree where a `Calendar`
// is built for that boundary. `SalusClock.today()`, `minuteOfDayNow()` and `instant(of:minuteOfDay:)`
// all read the calendar constructed below, so the carve-out is still a single site.

import Foundation
import SalusModel

extension LocalDateTime {
    /// The instant at which this wall clock is read in `zone` — the twin of
    /// `LocalDateTime.toInstant(zone)`, which is how Android composes the timestamp an editor saves
    /// (`feature/vitals/.../ui/editor/EditorMeasuredAt.kt:37`) and the start of an appointment.
    ///
    /// The exact inverse of `Date.wallClock(in:)` on every reading a zone actually has. On a day
    /// where the clocks jump forward a `minuteOfDay` inside the skipped hour names no wall-clock
    /// time; `Calendar` resolves it forward past the gap, and a repeated reading takes the earlier
    /// of its two offsets — both of which are what `java.time`/`kotlinx.datetime` answer for the
    /// same input. That agreement is the point: the same input must not produce two different
    /// instants on the two platforms.
    public func instant(in zone: TimeZone) -> Date {
        var components = DateComponents()
        components.year = date.year
        components.month = date.month
        components.day = date.day
        components.hour = minuteOfDay / 60
        components.minute = minuteOfDay % 60

        if let instant = gregorianCalendar(in: zone).date(from: components) {
            return instant
        }

        // Unreachable for a Gregorian calendar and a real zone — `date(from:)` resolves gaps rather
        // than failing — but the API is optional and this package carries no force unwrap
        // (`CLAUDE.md`). The fallback is the same arithmetic without the calendar: the day's UTC
        // midnight from `epochDay`, plus the minutes, less the zone's offset at that instant.
        let wallClock = Date(timeIntervalSince1970: TimeInterval(date.epochDay * 86400 + minuteOfDay * 60))
        return wallClock.addingTimeInterval(-TimeInterval(zone.secondsFromGMT(for: wallClock)))
    }
}

/// A Gregorian calendar reading in `zone` — the **only** `Calendar` this package builds, and with it
/// the only one the instant↔day boundary uses anywhere in the tree.
///
/// The identifier is fixed rather than taken from the device: `Calendar.current` follows the user's
/// region, and a device set to the Hijri or Buddhist calendar would answer with a different year and
/// day for the same instant. Android has no such axis — `kotlinx.datetime` is ISO-only — so
/// following the device here would be a behaviour difference, not a feature. The locale is
/// irrelevant to the numeric components read through it, so none is set.
func gregorianCalendar(in zone: TimeZone) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    return calendar
}
