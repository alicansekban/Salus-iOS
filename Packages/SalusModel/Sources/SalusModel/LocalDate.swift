// The Swift stand-in for `kotlinx.datetime.LocalDate`, which Android's `Profile.kt:3` imports and
// which has no twin in the Swift standard library. Foundation's `Date`/`Calendar` are deliberately
// NOT used: they carry a time zone and a locale-dependent calendar, and this file links no
// framework at all (`CLAUDE.md`, layer rules). What is needed is a calendar date and nothing else.
// (`LocalDateTime.swift` does import Foundation, for the zone offsets and formatters a *wall-clock*
// reading needs; nothing in this file goes near them.)
//
// The conversion is Howard Hinnant's `days_from_civil` / `civil_from_days` (public domain), the
// same proleptic Gregorian arithmetic `java.time.LocalDate` and `kotlinx.datetime.LocalDate`
// implement. Pure integer arithmetic, so it is exact for every year Swift's `Int` can express and
// identical on every platform.
//
// The origin is the one the rest of the port is written against (`RecurrenceRule.kt:6`):
// epochDay 0 = 1970-01-01, a Thursday.

/// A calendar date with no time and no time zone: exactly a year, a month and a day.
///
/// Ordering and conversion go through `epochDay`, the unit every persisted day column uses.
public struct LocalDate: Equatable, Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    /// Builds a date from its components, **normalising** a triple that names no real day.
    ///
    /// `kotlinx.datetime.LocalDate(year, month, day)` throws on such a triple. The port normalises
    /// instead (the M1 ruling): a throwing initialiser would put a `try` in front of every date a
    /// picker or a repository builds, and the picker cannot produce an out-of-range value anyway.
    /// A month outside `1...12` carries into the year and the day is then counted from the first of
    /// that month, so 2026-02-30 is 2026-03-02 and 2026-01-00 is 2025-12-31 — the arithmetic
    /// `java.time.LocalDate.plusDays` does, one day at a time.
    ///
    /// The normalisation is what keeps `Equatable` and `Comparable` from contradicting each other:
    /// both read `epochDay`, which is total, so two triples naming the same day are one value.
    public init(year: Int, month: Int, day: Int) {
        // The month first, because `epochDay(year:month:day:)` below is only defined for 1...12;
        // then the day as an offset from the first of the normalised month.
        let monthIndex = month - 1
        let monthOfYear = monthIndex.flooredMod(12)
        let carriedYear = year + (monthIndex - monthOfYear) / 12
        let firstOfMonth = Self.epochDay(year: carriedYear, month: monthOfYear + 1, day: 1)

        self.init(epochDay: firstOfMonth + day - 1)
    }

    /// Builds the date `epochDay` days after 1970-01-01. Negative values run backwards from it.
    public init(epochDay: Int) {
        // `civil_from_days`: shift the era to start on 0000-03-01 so that the leap day is the last
        // day of the year and the 400-year cycle (146_097 days) is a flat repetition.
        let shifted = epochDay + Self.daysFromZeroMarchToEpoch
        let era = (shifted >= 0 ? shifted : shifted - 146_096) / 146_097
        let dayOfEra = shifted - era * 146_097 // 0…146_096
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100) // 0…365
        let monthPosition = (5 * dayOfYear + 2) / 153 // 0…11, March = 0
        let day = dayOfYear - (153 * monthPosition + 2) / 5 + 1 // 1…31
        let month = monthPosition + (monthPosition < 10 ? 3 : -9) // 1…12
        let year = yearOfEra + era * 400 + (month <= 2 ? 1 : 0)

        // Assigned directly rather than delegating to `init(year:month:day:)`: that initialiser now
        // normalises *through* this one, and delegating back would recurse forever.
        self.year = year
        self.month = month
        self.day = day
    }

    /// Days since 1970-01-01; negative before it.
    public var epochDay: Int {
        Self.epochDay(year: year, month: month, day: day)
    }

    /// `days_from_civil`, the inverse of `init(epochDay:)`.
    ///
    /// Static because the normalising initialiser needs it before there is a `self` to read, and
    /// its `month` must be inside `1...12` — the caller normalises the month first.
    private static func epochDay(year: Int, month: Int, day: Int) -> Int {
        let shiftedYear = year - (month <= 2 ? 1 : 0)
        let era = (shiftedYear >= 0 ? shiftedYear : shiftedYear - 399) / 400
        let yearOfEra = shiftedYear - era * 400 // 0…399
        let dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1 // 0…365
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear // 0…146_096
        return era * 146_097 + dayOfEra - Self.daysFromZeroMarchToEpoch
    }

    /// The weekday as Monday = 0 … Sunday = 6 — the indexing `Recurrence.daysOfWeek` masks use
    /// (`RecurrenceRule.kt:15`).
    public var mondayBasedWeekdayIndex: Int {
        // 1970-01-01 is a Thursday, so epochDay 0 sits at index 3.
        (epochDay + 3).flooredMod(7)
    }

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        lhs.epochDay < rhs.epochDay
    }

    /// Days between 0000-03-01 (the start of the shifted era) and 1970-01-01.
    private static let daysFromZeroMarchToEpoch = 719_468
}

extension Int {
    /// Kotlin's `Int.mod(Int)` (`RecurrenceRule.kt:25`): a floored modulo, so the result carries
    /// the sign of the divisor and a negative epoch day still lands inside `0..<divisor`.
    ///
    /// Swift's `%` is a *remainder* and keeps the sign of the dividend: `(-1) % 7 == -1`, where
    /// Kotlin's `(-1).mod(7) == 6`. Using `%` here would shift every weekday before 1970 by one
    /// week's worth of wrong answers.
    func flooredMod(_ divisor: Int) -> Int {
        let remainder = self % divisor
        return remainder < 0 ? remainder + divisor : remainder
    }
}
