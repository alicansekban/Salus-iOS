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
