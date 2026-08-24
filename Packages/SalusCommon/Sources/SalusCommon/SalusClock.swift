// The injectable time source, ported 1:1 from Android
// `core/common/src/main/kotlin/com/alicansekban/salus/core/common/SalusClock.kt`.
//
// Kotlin's `Instant` is Foundation's `Date` and Kotlin's `kotlinx.datetime.TimeZone` is
// Foundation's `TimeZone`; the calendar date is `SalusModel.LocalDate`, the Foundation-free twin
// of `kotlinx.datetime.LocalDate` that the rest of the port is written against.
//
// One shape differs on purpose. Kotlin's `localTimeNow(): LocalTime` (`SalusClock.kt:23`) has no
// consumer that wants a `LocalTime`: every dose time in this app is stored and compared as a
// minute of day (`CLAUDE.md`, date/time semantics), which is what the reminder window and the
// cycle prediction both read. It is ported as `minuteOfDayNow()` rather than as a second date-time
// value type nothing else in the tree would use.
//
// The derived answers are an extension rather than protocol requirements with defaults, because
// they are not points of variation: a clock decides *when* it is, never how a calendar reads it.
// A fake that got them wrong would be a fake that lies about the calendar.

import Foundation
import SalusModel

/// Injectable time source. Production code must never call `Date()` directly —
/// this is what makes reminder scheduling and cycle prediction deterministic in tests.
///
/// Ported from `SalusClock.kt:11-24`.
public protocol SalusClock: Sendable {
    /// The current instant (`SalusClock.kt:17`).
    func now() -> Date

    /// The zone every calendar answer below is read in (`SalusClock.kt:19`).
    func timeZone() -> TimeZone
}

extension SalusClock {
    /// The calendar day `now()` falls on in `timeZone()`.
    ///
    /// The twin of `now().toLocalDateTime(timeZone()).date` (`SalusClock.kt:21`).
    public func today() -> LocalDate {
        let calendar = gregorianCalendar()
        let instant = now()
        return LocalDate(
            year: calendar.component(.year, from: instant),
            month: calendar.component(.month, from: instant),
            day: calendar.component(.day, from: instant)
        )
    }

    /// `today()` as the day number every persisted day column stores.
    public func todayEpochDay() -> Int {
        today().epochDay
    }

    /// Minutes since local midnight, the unit dose times are stored in.
    ///
    /// The twin of `now().toLocalDateTime(timeZone()).time` (`SalusClock.kt:23`), reduced to the
    /// one component the app actually persists.
    public func minuteOfDayNow() -> Int {
        let calendar = gregorianCalendar()
        let instant = now()
        return calendar.component(.hour, from: instant) * 60 + calendar.component(.minute, from: instant)
    }

    /// The instant at which `minuteOfDay` minutes past midnight is read on `day`, in this clock's
    /// zone — the inverse of `today()` / `minuteOfDayNow()`.
    ///
    /// The twin of `LocalDateTime(date, time).toInstant(zone)`, which is how Android composes the
    /// timestamp an editor saves (`feature/vitals/.../ui/editor/EditorMeasuredAt.kt:37`). Kotlin's
    /// `LocalTime` is ported as a minute of day, so the editor passes `clock.minuteOfDayNow()` for
    /// today and `12 * 60` for a past day (`EditorMeasuredAt.kt:13, 36`).
    ///
    /// This is the **second and last** instant↔day boundary in the tree, and it exists for the same
    /// reason `today()` does: a wall-clock reading only becomes an instant through a calendar in a
    /// zone, and doing that outside the carve-out would put a second `Calendar` in the tree
    /// (`CLAUDE.md`, the `LocalDate` rule's carve-out). Everything downstream stays `epochMs`.
    ///
    /// The conversion itself is `LocalDateTime.instant(in:)` in `LocalDateTimeInstant.swift`, which
    /// iOS-M4 lifted out of this method so a caller holding a wall-clock reading rather than a clock
    /// can run it too. This stays the clock-shaped spelling of it — the zone is the clock's, read at
    /// call time — and the calendar is still built in exactly one place.
    public func instant(of day: LocalDate, minuteOfDay: Int) -> Date {
        LocalDateTime(date: day, minuteOfDay: minuteOfDay).instant(in: timeZone())
    }

    /// `now()` as the whole milliseconds every persisted `created_at` column stores.
    ///
    /// The twin of `Instant.toEpochMilliseconds()` (and of `System.currentTimeMillis()`, which
    /// Android's seed callback writes): the sub-millisecond part is **truncated, never rounded**,
    /// so a stamp can never land in the future. Every writer of an epoch-millisecond column goes
    /// through the same conversion — `Date.epochMilliseconds` in `EpochMilliseconds.swift`, which
    /// this delegates to — so the seed row and a repository write cannot disagree by a millisecond.
    public func nowEpochMilliseconds() -> Int64 {
        now().epochMilliseconds
    }

    /// A Gregorian calendar reading in this clock's zone.
    ///
    /// The calendar is built in `LocalDateTimeInstant.swift`, which is the one place in the tree
    /// that constructs one; the reasoning for fixing the identifier lives with it.
    private func gregorianCalendar() -> Calendar {
        SalusCommon.gregorianCalendar(in: timeZone())
    }
}

/// The production clock: the device's own instant and zone (`SalusClock.kt:26-31`).
public struct SystemSalusClock: SalusClock {
    public init() {}

    public func now() -> Date {
        Date()
    }

    public func timeZone() -> TimeZone {
        TimeZone.current
    }
}
