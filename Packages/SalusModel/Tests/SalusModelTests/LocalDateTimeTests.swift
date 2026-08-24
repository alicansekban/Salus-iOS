import Foundation
import Testing

@testable import SalusModel

// `LocalDateTime` has no Kotlin twin to copy a test table from — Android gets the type from
// `kotlinx.datetime` — so what is pinned here is the contract the Android code relies on and the
// port must reproduce exactly:
//
//   * `Instant.toLocalDateTime(zone)`: the wall clock an instant reads as, floored, so an instant
//     before 1970 lands on the day it actually falls on rather than one day late with a negative
//     time of day.
//   * `LocalDateTime.toString()` / `LocalDateTime.parse`: the `starts_at_local` wire form, which
//     one platform writes and the other reads (`CLAUDE.md`, wall-clock semantics). Every reference
//     string below is what `kotlinx.datetime` prints for the same value.
//
// The zone-ful direction, `LocalDateTime.instant(in:)`, is pinned in `SalusCommonTests` — it is the
// half that needs the `Calendar` carve-out and so lives one package up.
//
// Fixed-offset zones are used deliberately: a named zone would make these rows depend on the host's
// tz database, and what is under test here is the arithmetic, not Foundation's zone table.

/// One wall-clock row: an instant (as seconds since the epoch), the zone it is read in, and the day
/// plus minute of day it reads as there.
typealias WallClockRow = (
    epochSeconds: Double,
    offsetHours: Int,
    year: Int,
    month: Int,
    day: Int,
    minuteOfDay: Int
)

@Suite("LocalDateTime.init(date:minuteOfDay:)")
struct LocalDateTimeInitTests {
    /// Both ends of the documented `0 ..< 1440` range construct and keep their value. The upper end
    /// is the one that matters: 1439 is a real reading (23:59), 1440 is not, and an unchecked 1440
    /// would serialise as `"…T24:00"` — text `init?(isoLocalString:)` rejects. The rejection itself
    /// is a `precondition`, so it is deliberately not exercised here: a trap is not a test case.
    @Test("the first and last minute of a day both construct", arguments: [0, 1439])
    func theEndsOfTheRangeConstruct(minuteOfDay: Int) {
        let day = LocalDate(year: 2026, month: 12, day: 31)

        let value = LocalDateTime(date: day, minuteOfDay: minuteOfDay)

        #expect(value.minuteOfDay == minuteOfDay)
        #expect(value.date == day)
    }
}

@Suite("Date.wallClock(in:)")
struct DateWallClockTests {
    static let rows: [WallClockRow] = [
        // The epoch itself, and the two zones either side of it.
        (0, 0, 1970, 1, 1, 0),
        (0, 3, 1970, 1, 1, 180),
        (0, -5, 1969, 12, 31, 19 * 60),
        // Before 1970: truncating division would answer 1970-01-01 with a negative time of day.
        (-1, 0, 1969, 12, 31, 1439),
        (-86400, 0, 1969, 12, 31, 0),
        (-1800, 2, 1970, 1, 1, 90),
        // Well before 1970: 1900-01-01T12:00Z is epoch day -25567.
        (-25567 * 86400 + 43200, 0, 1900, 1, 1, 720),
        // A present-day reading, in GMT and in Istanbul's fixed +03.
        (20689 * 86400 + 11 * 3600 + 30 * 60, 0, 2026, 8, 24, 11 * 60 + 30),
        (20689 * 86400 + 11 * 3600 + 30 * 60, 3, 2026, 8, 24, 14 * 60 + 30),
        // The last minute of a day, which must not roll over.
        (20689 * 86400 + 86399, 0, 2026, 8, 24, 1439)
    ]

    @Test("an instant reads as the wall clock its zone shows", arguments: rows)
    func anInstantReadsAsItsWallClock(row: WallClockRow) throws {
        let zone = try #require(TimeZone(secondsFromGMT: row.offsetHours * 3600))

        let wallClock = Date(timeIntervalSince1970: row.epochSeconds).wallClock(in: zone)

        #expect(wallClock.date == LocalDate(year: row.year, month: row.month, day: row.day))
        #expect(wallClock.minuteOfDay == row.minuteOfDay)
    }

    /// Sub-minute precision is dropped downwards, never rounded: a reading 999 milliseconds into a
    /// minute is still that minute, and one a millisecond before it is the previous one.
    @Test("it floors to the minute rather than rounding")
    func itFloorsToTheMinute() throws {
        let zone = try #require(TimeZone(secondsFromGMT: 0))
        let minuteStart = Double(20689 * 86400 + 11 * 3600 + 30 * 60)

        #expect(Date(timeIntervalSince1970: minuteStart + 0.999).wallClock(in: zone).minuteOfDay == 11 * 60 + 30)
        #expect(Date(timeIntervalSince1970: minuteStart - 0.001).wallClock(in: zone).minuteOfDay == 11 * 60 + 29)
    }
}

// MARK: - ISO-8601 local date-time

/// One wire row: a wall clock and the text `kotlinx.datetime.LocalDateTime.toString()` prints for it.
typealias IsoRow = (year: Int, month: Int, day: Int, minuteOfDay: Int, text: String)

@Suite("LocalDateTime ISO-8601 local text")
struct LocalDateTimeIsoTests {
    static let rows: [IsoRow] = [
        (2026, 8, 24, 14 * 60 + 30, "2026-08-24T14:30"),
        // Every component that needs zero padding, in one row.
        (2026, 3, 8, 9 * 60 + 5, "2026-03-08T09:05"),
        // Midnight and the last minute of the day: the two ends of `minuteOfDay`.
        (2026, 1, 1, 0, "2026-01-01T00:00"),
        (2026, 12, 31, 1439, "2026-12-31T23:59"),
        // A year that needs all four digits padded.
        (1, 1, 1, 0, "0001-01-01T00:00")
    ]

    @Test("it writes what kotlinx.datetime's toString() writes", arguments: rows)
    func itWritesWhatKotlinWrites(row: IsoRow) {
        let value = LocalDateTime(
            date: LocalDate(year: row.year, month: row.month, day: row.day),
            minuteOfDay: row.minuteOfDay
        )

        #expect(value.isoLocalString == row.text)
    }

    @Test("it reads back everything it writes", arguments: rows)
    func itReadsBackEverythingItWrites(row: IsoRow) {
        let value = LocalDateTime(
            date: LocalDate(year: row.year, month: row.month, day: row.day),
            minuteOfDay: row.minuteOfDay
        )

        #expect(LocalDateTime(isoLocalString: value.isoLocalString) == value)
    }

    /// Kotlin appends `:ss` only when the seconds are non-zero, and parses either form. This type
    /// has no seconds field, so the `:ss` form is accepted and the field dropped.
    @Test(
        "it accepts the seconds field kotlinx.datetime writes when seconds are non-zero",
        arguments: ["2026-08-24T14:30:00", "2026-08-24T14:30:45"]
    )
    func itAcceptsASecondsField(text: String) {
        let expected = LocalDateTime(date: LocalDate(year: 2026, month: 8, day: 24), minuteOfDay: 14 * 60 + 30)

        #expect(LocalDateTime(isoLocalString: text) == expected)
    }

    @Test(
        "it rejects anything that is not a local date-time",
        arguments: [
            // An offset or a `Z` makes it an *instant*, which this type is deliberately not: the
            // zone travels beside the value in `tz_id`.
            "2026-08-24T14:30+03:00",
            "2026-08-24T14:30:00+03:00",
            "2026-08-24T14:30Z",
            "2026-08-24T14:30:00Z",
            // Fractional seconds, which the app never writes and cannot represent.
            "2026-08-24T14:30:00.000",
            // Structure: no separator, a space instead of `T`, an unpadded field, a trailing colon.
            "2026-08-24",
            "2026-08-24 14:30",
            "2026-8-24T14:30",
            "2026-08-24T14:30:",
            "T14:30",
            "",
            // Out-of-range components, which `LocalDateTime.parse` rejects but the normalising
            // `LocalDate(year:month:day:)` would silently roll over.
            "2026-08-24T24:00",
            "2026-08-24T14:60",
            "2026-08-24T14:30:60",
            "2026-02-31T14:30",
            "2026-13-01T14:30",
            "2026-00-01T14:30",
            // Non-ASCII digits, which `Int(_:)` alone would happily accept.
            "٢٠٢٦-08-24T14:30"
        ]
    )
    func itRejectsAnythingElse(text: String) {
        #expect(LocalDateTime(isoLocalString: text) == nil)
    }
}
