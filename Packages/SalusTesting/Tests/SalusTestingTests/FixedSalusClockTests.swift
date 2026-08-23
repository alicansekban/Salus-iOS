import Foundation
import SalusCommon
import SalusModel
import Testing

@testable import SalusTesting

// Pinning tests for the fixed clock (`core/testing/.../FixedSalusClock.kt:9-25`) and, through it,
// for the `SalusClock` extension that turns an instant into a calendar day and a minute of day
// (`core/common/.../SalusClock.kt:21-23`). The two are tested together because the fixed clock is
// the only clock whose answers can be written down in advance, and it cannot live in
// `SalusCommon`'s own tests: `SalusTesting` depends on `SalusCommon`, never the reverse.
//
// HOW THE EXPECTED VALUES WERE DERIVED — none of them come from `Calendar`, which is the code
// under test:
//
//   * The instants are built by `utcInstant` from `LocalDate.epochDay` (pure integer arithmetic,
//     pinned by `SalusModel`'s own `LocalDateTests`) plus an hour/minute offset. UTC never changes
//     offset, so a UTC day is exactly 86_400 seconds and the conversion is exact.
//   * `Europe/Istanbul` has been a fixed UTC+03 with no daylight saving since September 2016, so
//     the expected local wall clock is the UTC one plus three hours, by hand.
//   * `Europe/London` is UTC+00 in winter and UTC+01 in summer; British Summer Time starts at
//     01:00 UTC on the last Sunday of March. In 2026 March has Sundays on the 1st, 8th, 15th,
//     22nd and 29th (1 March 2026 is a Sunday: epoch day 20_513, and 20_513 + 3 ≡ 6 mod 7 on
//     `LocalDate.mondayBasedWeekdayIndex`), so the change is 2026-03-29T01:00Z. The rows below
//     straddle it by half an hour on each side.
//
// The minute-of-day rows are the reason the extension exists at all: Android stores dose times as
// `minuteOfDay` (`CLAUDE.md`, date/time semantics), so `localTimeNow()` is ported as
// `minuteOfDayNow()` rather than as a `LocalTime` twin no other type would consume.

/// One row: an instant, the zone the clock is in, and the calendar day and minute of day it must
/// report there.
typealias ZoneRow = (instant: Date, zone: TimeZone, expectedDate: LocalDate, expectedMinuteOfDay: Int)

/// A UTC instant, built without `Calendar`.
func utcInstant(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    let epochDay = LocalDate(year: year, month: month, day: day).epochDay
    return Date(timeIntervalSince1970: TimeInterval(epochDay * 86400 + hour * 3600 + minute * 60))
}

// `Europe/London`'s clocks move on 2026-03-29; a fixed offset would get the second row wrong.
// The identifier is looked up once, and the lookup is the only place in this file that needs a
// bang — a missing tz database entry must fail loudly rather than fall back to some other zone.
// swiftlint:disable:next force_unwrapping
let london = TimeZone(identifier: "Europe/London")!

/// UTC, as the neutral zone the Istanbul rows are contrasted against.
let utc = TimeZone.gmt

@Suite("FixedSalusClock and the SalusClock extension")
struct FixedSalusClockTests {
    /// 23:59 and 00:00 Istanbul time, and the same two instants read in UTC.
    ///
    /// The pair straddles midnight in Istanbul but not in UTC, which is what makes the zone —
    /// rather than the instant — visibly decide the day.
    static let midnightRows: [ZoneRow] = [
        (utcInstant(2026, 3, 15, 20, 59), FixedSalusClock.defaultZone, LocalDate(year: 2026, month: 3, day: 15), 1439),
        (utcInstant(2026, 3, 15, 21, 0), FixedSalusClock.defaultZone, LocalDate(year: 2026, month: 3, day: 16), 0),
        (utcInstant(2026, 3, 15, 20, 59), utc, LocalDate(year: 2026, month: 3, day: 15), 1259),
        (utcInstant(2026, 3, 15, 21, 0), utc, LocalDate(year: 2026, month: 3, day: 15), 1260)
    ]

    /// Half an hour either side of the 2026 British Summer Time change, plus the evening before.
    static let daylightRows: [ZoneRow] = [
        (utcInstant(2026, 3, 28, 23, 30), london, LocalDate(year: 2026, month: 3, day: 28), 1410),
        (utcInstant(2026, 3, 29, 0, 30), london, LocalDate(year: 2026, month: 3, day: 29), 30),
        (utcInstant(2026, 3, 29, 1, 30), london, LocalDate(year: 2026, month: 3, day: 29), 150)
    ]

    @Test("the day and the minute of day are read in the clock's own zone", arguments: midnightRows)
    func theDayAndMinuteAreReadInTheClocksZone(row: ZoneRow) {
        let clock = FixedSalusClock(now: row.instant, timeZone: row.zone)

        #expect(clock.today() == row.expectedDate)
        #expect(clock.todayEpochDay() == row.expectedDate.epochDay)
        #expect(clock.minuteOfDayNow() == row.expectedMinuteOfDay)
    }

    @Test("a daylight saving change moves the wall clock, not just the offset", arguments: daylightRows)
    func aDaylightSavingChangeMovesTheWallClock(row: ZoneRow) {
        let clock = FixedSalusClock(now: row.instant, timeZone: row.zone)

        #expect(clock.today() == row.expectedDate)
        #expect(clock.todayEpochDay() == row.expectedDate.epochDay)
        #expect(clock.minuteOfDayNow() == row.expectedMinuteOfDay)
    }

    @Test("one hour of real time crosses the daylight change as two hours of wall clock")
    func oneHourOfRealTimeCrossesTheChangeAsTwo() {
        let clock = FixedSalusClock(now: utcInstant(2026, 3, 29, 0, 30), timeZone: london)
        let before = clock.minuteOfDayNow()

        clock.advanceTo(utcInstant(2026, 3, 29, 1, 30))

        // 00:30 GMT to 02:30 BST: the hour that the clocks skipped is the whole point of using a
        // real zone rather than a fixed offset.
        #expect(clock.minuteOfDayNow() - before == 120)
    }

    @Test("advanceTo moves the clock and nothing else")
    func advanceToMovesTheClock() {
        let clock = FixedSalusClock(now: utcInstant(2026, 3, 15, 20, 59))

        #expect(clock.today() == LocalDate(year: 2026, month: 3, day: 15))

        clock.advanceTo(utcInstant(2026, 3, 15, 21, 0))

        #expect(clock.now() == utcInstant(2026, 3, 15, 21, 0))
        #expect(clock.timeZone() == FixedSalusClock.defaultZone)
        #expect(clock.today() == LocalDate(year: 2026, month: 3, day: 16))
        #expect(clock.minuteOfDayNow() == 0)
    }

    @Test("moveToZone re-reads the same instant somewhere else")
    func moveToZoneReReadsTheSameInstant() {
        let instant = utcInstant(2026, 3, 15, 21, 0)
        let clock = FixedSalusClock(now: instant)

        #expect(clock.today() == LocalDate(year: 2026, month: 3, day: 16))
        #expect(clock.minuteOfDayNow() == 0)

        clock.moveToZone(utc)

        #expect(clock.now() == instant)
        #expect(clock.today() == LocalDate(year: 2026, month: 3, day: 15))
        #expect(clock.minuteOfDayNow() == 1260)
    }

    @Test("the default zone is the one the Android tests fix")
    func theDefaultZoneIsTheAndroidOne() {
        // FixedSalusClock.kt:11
        #expect(FixedSalusClock.defaultZone.identifier == "Europe/Istanbul")
        #expect(FixedSalusClock(now: utcInstant(2026, 3, 15, 21, 0)).timeZone() == FixedSalusClock.defaultZone)
    }
}

// MARK: - The day → instant direction

// `instant(of:minuteOfDay:)` is the inverse of `today()` / `minuteOfDayNow()` and the second and
// last instant↔day boundary in the tree (`CLAUDE.md`, the `LocalDate` rule's carve-out). Android
// spells it `LocalDateTime(date, time).toInstant(zone)` inside `resolveEditorMeasuredAt`
// (`feature/vitals/.../ui/editor/EditorMeasuredAt.kt:37`); iOS ports `localTimeNow()` as
// `minuteOfDayNow()`, so the editor composes the same answer as
// `instant(of: date, minuteOfDay: clock.minuteOfDayNow())` for today and
// `instant(of: date, minuteOfDay: 12 * 60)` for a past day (`EditorMeasuredAt.kt:13, 36`).
//
// Tested here rather than in `SalusCommon` for the same reason the rest of the extension is: the
// fixed clock is the only clock whose answers can be written down in advance, and it cannot live in
// `SalusCommon`'s tests without inverting the package dependency.
//
// HOW THE EXPECTED VALUES WERE DERIVED — again none of them come from `Calendar`: `utcInstant`
// builds them from `LocalDate.epochDay` plus an offset, and the zone offsets are the ones spelled
// out at the top of this file (Istanbul a fixed UTC+03, London UTC+00 in winter and UTC+01 from
// 2026-03-29T01:00Z).

/// One row: the day and minute of day handed to the clock, the zone it is in, and the instant that
/// wall-clock reading names there.
typealias InstantRow = (day: LocalDate, minuteOfDay: Int, zone: TimeZone, expectedInstant: Date)

@Suite("SalusClock.instant(of:minuteOfDay:)")
struct SalusClockInstantTests {
    static let instantRows: [InstantRow] = [
        // Istanbul, UTC+03 all year: midday, midnight, and the last minute of the day.
        (LocalDate(year: 2026, month: 3, day: 15), 12 * 60, FixedSalusClock.defaultZone, utcInstant(2026, 3, 15, 9, 0)),
        (LocalDate(year: 2026, month: 3, day: 16), 0, FixedSalusClock.defaultZone, utcInstant(2026, 3, 15, 21, 0)),
        (LocalDate(year: 2026, month: 3, day: 15), 1439, FixedSalusClock.defaultZone, utcInstant(2026, 3, 15, 20, 59)),
        // UTC, where the wall clock and the instant agree.
        (LocalDate(year: 2026, month: 3, day: 15), 1259, utc, utcInstant(2026, 3, 15, 20, 59)),
        // London on either side of the 2026 British Summer Time change: the same minute of day is
        // an hour apart in UTC depending on which side of 2026-03-29T01:00Z the day falls.
        (LocalDate(year: 2026, month: 3, day: 28), 12 * 60, london, utcInstant(2026, 3, 28, 12, 0)),
        (LocalDate(year: 2026, month: 3, day: 29), 12 * 60, london, utcInstant(2026, 3, 29, 11, 0)),
        (LocalDate(year: 2026, month: 3, day: 29), 30, london, utcInstant(2026, 3, 29, 0, 30)),
        (LocalDate(year: 2026, month: 3, day: 29), 150, london, utcInstant(2026, 3, 29, 1, 30))
    ]

    @Test("a day and a minute of day name one instant in the clock's zone", arguments: instantRows)
    func aDayAndMinuteNameOneInstant(row: InstantRow) {
        let clock = FixedSalusClock(now: utcInstant(2020, 1, 1, 0, 0), timeZone: row.zone)

        #expect(clock.instant(of: row.day, minuteOfDay: row.minuteOfDay) == row.expectedInstant)
    }

    /// The round trip, over every row the day→instant direction is already pinned against: reading
    /// an instant as a day plus a minute of day and composing it back must land on the same instant.
    @Test(
        "it is the exact inverse of today() and minuteOfDayNow()",
        arguments: FixedSalusClockTests.midnightRows + FixedSalusClockTests.daylightRows
    )
    func itIsTheInverseOfTodayAndMinuteOfDayNow(row: ZoneRow) {
        let clock = FixedSalusClock(now: row.instant, timeZone: row.zone)

        #expect(clock.instant(of: clock.today(), minuteOfDay: clock.minuteOfDayNow()) == clock.now())
    }

    /// The editor's two cases, composed exactly as `resolveEditorMeasuredAt` does
    /// (`EditorMeasuredAt.kt:36-37`): the current time for today, midday for a past day.
    @Test("it composes the editor's measured-at for today and for a past day")
    func itComposesTheEditorsMeasuredAt() {
        let clock = FixedSalusClock(now: utcInstant(2026, 3, 15, 12, 34))

        #expect(clock.instant(of: clock.today(), minuteOfDay: clock.minuteOfDayNow()) == clock.now())

        let pastDay = LocalDate(epochDay: clock.todayEpochDay() - 7)
        #expect(clock.instant(of: pastDay, minuteOfDay: 12 * 60) == utcInstant(2026, 3, 8, 9, 0))
    }

    /// The two wall-clock readings a daylight change makes ill-defined, pinned so a Foundation
    /// behaviour change would be caught rather than silently persisted into a measurement.
    ///
    /// Both answers are `java.time`'s (`ZonedDateTime.of`, which `kotlinx.datetime.toInstant` calls):
    /// a skipped reading resolves *forward* past the gap, and a repeated one takes the *earlier* of
    /// its two offsets. That agreement is the point — the same input must not produce two different
    /// instants on the two platforms.
    @Test("a wall-clock reading the daylight change skips or repeats resolves as java.time does")
    func aDaylightEdgeResolvesAsJavaTimeDoes() {
        let clock = FixedSalusClock(now: utcInstant(2020, 1, 1, 0, 0), timeZone: london)

        // 2026-03-29 01:30 never happens in London: the clocks go 01:00 GMT → 02:00 BST. Resolved
        // forward, it is 02:30 BST — which is 01:30 UTC, and reads back as minute of day 150.
        let skipped = clock.instant(of: LocalDate(year: 2026, month: 3, day: 29), minuteOfDay: 90)
        #expect(skipped == utcInstant(2026, 3, 29, 1, 30))
        #expect(FixedSalusClock(now: skipped, timeZone: london).minuteOfDayNow() == 150)

        // 2026-10-25 01:30 happens twice: the clocks go 02:00 BST → 01:00 GMT. The earlier of the
        // two, still on BST, is 00:30 UTC.
        let repeated = clock.instant(of: LocalDate(year: 2026, month: 10, day: 25), minuteOfDay: 90)
        #expect(repeated == utcInstant(2026, 10, 25, 0, 30))
    }

    /// The zone is the clock's, read at call time — `moveToZone` must move the answer.
    @Test("the answer follows the clock's zone, not the device's")
    func theAnswerFollowsTheClocksZone() {
        let clock = FixedSalusClock(now: utcInstant(2026, 3, 15, 12, 0))
        let day = LocalDate(year: 2026, month: 3, day: 15)

        #expect(clock.instant(of: day, minuteOfDay: 12 * 60) == utcInstant(2026, 3, 15, 9, 0))

        clock.moveToZone(utc)

        #expect(clock.instant(of: day, minuteOfDay: 12 * 60) == utcInstant(2026, 3, 15, 12, 0))
    }
}
