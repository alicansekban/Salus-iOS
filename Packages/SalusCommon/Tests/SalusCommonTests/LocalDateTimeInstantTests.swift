import Foundation
import SalusModel
import Testing

@testable import SalusCommon

// `LocalDateTime.instant(in:)` is the twin of `kotlinx.datetime.LocalDateTime.toInstant(zone)` and
// the only place in the tree a `Calendar` is built. iOS-M4 lifted it out of
// `SalusClock.instant(of:minuteOfDay:)`, which now forwards to it, so what has to be pinned is:
//
//   * the answers themselves, against reference instants computed independently (Python's
//     `zoneinfo`, reading the same IANA tz database `java.time` reads), and
//   * that the clock still answers exactly what the extension answers, so the lift cannot have
//     moved the behaviour `SalusTesting`'s `SalusClockInstantTests` already pins.
//
// `America/New_York` on 2026-03-08 is the interesting day: the clocks go 02:00 EST → 03:00 EDT, so
// the same minute of day is an hour apart on either side of it and 02:30 never happens at all.
// `Europe/Istanbul` is the contrast — UTC+03 all year, no transition to resolve.

/// A clock fixed at one instant in one zone. `SalusTesting`'s `FixedSalusClock` is the shared one,
/// but it lives one package *above* `SalusCommon` and cannot be reached from here.
private struct StubClock: SalusClock {
    let instant: Date
    let zone: TimeZone

    func now() -> Date {
        instant
    }

    func timeZone() -> TimeZone {
        zone
    }
}

// The two named zones. A missing tz database entry must fail loudly rather than fall back to some
// other zone, which is what these two bangs are for.
// swiftlint:disable force_unwrapping
private let newYork = TimeZone(identifier: "America/New_York")!
private let istanbul = TimeZone(identifier: "Europe/Istanbul")!
// swiftlint:enable force_unwrapping

/// The instant `year-month-day hour:minute` names in UTC, built from `LocalDate`'s own arithmetic so
/// the expectation does not depend on the implementation under test.
private func utcInstant(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    let epochDay = LocalDate(year: year, month: month, day: day).epochDay
    return Date(timeIntervalSince1970: TimeInterval(epochDay * 86400 + hour * 3600 + minute * 60))
}

/// One row: the wall-clock reading, the zone it is read in, and the instant it names there.
typealias ZonedInstantRow = (day: LocalDate, minuteOfDay: Int, zone: TimeZone, expected: Date)

@Suite("LocalDateTime.instant(in:)")
struct LocalDateTimeInstantTests {
    static let rows: [ZonedInstantRow] = [
        // America/New_York, the day the clocks jump forward (2026-03-08, 02:00 EST → 03:00 EDT).
        // The day before, still on EST (UTC-5).
        (LocalDate(year: 2026, month: 3, day: 7), 12 * 60, newYork, utcInstant(2026, 3, 7, 17, 0)),
        // Midnight and 01:30, before the jump: still EST.
        (LocalDate(year: 2026, month: 3, day: 8), 0, newYork, utcInstant(2026, 3, 8, 5, 0)),
        (LocalDate(year: 2026, month: 3, day: 8), 90, newYork, utcInstant(2026, 3, 8, 6, 30)),
        // 03:30 and midday, after the jump: EDT (UTC-4).
        (LocalDate(year: 2026, month: 3, day: 8), 210, newYork, utcInstant(2026, 3, 8, 7, 30)),
        (LocalDate(year: 2026, month: 3, day: 8), 12 * 60, newYork, utcInstant(2026, 3, 8, 16, 0)),
        // The last minute of that day, which lands on the next UTC day.
        (LocalDate(year: 2026, month: 3, day: 8), 1439, newYork, utcInstant(2026, 3, 9, 3, 59)),
        // Europe/Istanbul, UTC+03 all year: the same three readings with nothing to resolve.
        (LocalDate(year: 2026, month: 3, day: 8), 0, istanbul, utcInstant(2026, 3, 7, 21, 0)),
        (LocalDate(year: 2026, month: 3, day: 8), 12 * 60, istanbul, utcInstant(2026, 3, 8, 9, 0)),
        (LocalDate(year: 2026, month: 3, day: 8), 1439, istanbul, utcInstant(2026, 3, 8, 20, 59)),
        (LocalDate(year: 2026, month: 8, day: 24), 14 * 60 + 30, istanbul, utcInstant(2026, 8, 24, 11, 30))
    ]

    @Test("a wall-clock reading names one instant in its zone", arguments: rows)
    func aReadingNamesOneInstant(row: ZonedInstantRow) {
        let value = LocalDateTime(date: row.day, minuteOfDay: row.minuteOfDay)

        #expect(value.instant(in: row.zone) == row.expected)
    }

    /// The reading the spring-forward skips. `java.time` (and so `kotlinx.datetime.toInstant`)
    /// resolves it *forward* past the gap; the same input must not produce two different instants on
    /// the two platforms, which is what this pins.
    @Test("a reading the spring-forward skips resolves forward, as java.time does")
    func aSkippedReadingResolvesForward() {
        // 2026-03-08 02:30 never happens in New York. Resolved forward it is 03:30 EDT — 07:30 UTC,
        // the same instant 03:30 itself names.
        let skipped = LocalDateTime(date: LocalDate(year: 2026, month: 3, day: 8), minuteOfDay: 150)

        #expect(skipped.instant(in: newYork) == utcInstant(2026, 3, 8, 7, 30))
    }

    /// The round trip against `Date.wallClock(in:)`, the direction that needs no calendar: over
    /// every reading a zone actually has, the two are exact inverses.
    @Test("it is the exact inverse of Date.wallClock(in:)", arguments: rows)
    func itIsTheInverseOfWallClock(row: ZonedInstantRow) {
        let value = LocalDateTime(date: row.day, minuteOfDay: row.minuteOfDay)

        let readBack = value.instant(in: row.zone).wallClock(in: row.zone)

        // The skipped rows are excluded by construction — every row above is a reading its zone has.
        #expect(readBack == value)
    }

    /// The lift itself: `SalusClock.instant(of:minuteOfDay:)` is now a forward to this, so the two
    /// must answer identically for every row `SalusTesting`'s clock suite already covers.
    @Test("SalusClock.instant(of:minuteOfDay:) forwards to it, in the clock's zone", arguments: rows)
    func theClockForwardsToIt(row: ZonedInstantRow) {
        let clock = StubClock(instant: utcInstant(2020, 1, 1, 0, 0), zone: row.zone)

        #expect(clock.instant(of: row.day, minuteOfDay: row.minuteOfDay) == row.expected)
    }
}

/// `Date.wallClock(in:)` repeats the millisecond flooring of `Date.epochMilliseconds` because
/// `SalusModel` sits below `SalusCommon` and cannot reach it. This is the drift detector for that
/// duplication: the day and minute `wallClock` answers must be exactly what the shared conversion
/// would have produced.
@Suite("Date.wallClock(in:) agrees with Date.epochMilliseconds")
struct WallClockEpochMillisecondsAgreementTests {
    @Test(
        "the two floor the same instant to the same minute",
        arguments: [-1.0, -0.001, -0.5, 0, 0.001, 0.999, 1_756_045_799.999, 1_756_045_800.0, -2_208_988_800.001]
    )
    func theTwoFloorTheSame(epochSeconds: Double) throws {
        let zone = try #require(TimeZone(secondsFromGMT: 0))
        let instant = Date(timeIntervalSince1970: epochSeconds)

        let wallClock = instant.wallClock(in: zone)

        let millis = instant.epochMilliseconds
        let epochDay = Int((Double(millis) / 86_400_000).rounded(.down))
        let minuteOfDay = Int((Double(millis - Int64(epochDay) * 86_400_000) / 60000).rounded(.down))
        #expect(wallClock.date.epochDay == epochDay)
        #expect(wallClock.minuteOfDay == minuteOfDay)
    }
}
