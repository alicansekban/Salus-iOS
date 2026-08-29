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

    /// The weekday as Monday = 1 … Sunday = 7 — `kotlinx.datetime`'s `DayOfWeek.isoDayNumber`.
    ///
    /// The Cycle month grid backs up to the Monday that opens the first week with
    /// `minus(isoDayNumber - 1, DateTimeUnit.DAY)` (`CycleViewModel.kt:163`), so this is the same
    /// weekday as `mondayBasedWeekdayIndex`, counted from one instead of from zero.
    public var isoDayNumber: Int {
        mondayBasedWeekdayIndex + 1
    }

    /// The date `days` days after this one; a negative count runs backwards.
    ///
    /// `kotlinx.datetime.LocalDate.plus(n, DateTimeUnit.DAY)` (`CycleViewModel.kt:164`). Days
    /// are all the same length in a calendar with no time of day, so this is an epoch-day shift
    /// and nothing more.
    public func plusDays(_ days: Int) -> LocalDate {
        LocalDate(epochDay: epochDay + days)
    }

    /// The date `days` days before this one; a negative count runs forwards.
    ///
    /// `kotlinx.datetime.LocalDate.minus(n, DateTimeUnit.DAY)` (`CycleViewModel.kt:163`).
    public func minusDays(_ days: Int) -> LocalDate {
        LocalDate(epochDay: epochDay - days)
    }

    /// The signed number of days from this date to `other`, i.e. `other − this`: a date in the
    /// future counts positive, one in the past negative, and the same day zero.
    ///
    /// `kotlinx.datetime.daysUntil` (`CycleViewModel.kt:140-141`, which reads it in both
    /// directions — the day number inside the current cycle, and the days to the predicted one).
    public func daysUntil(_ other: LocalDate) -> Int {
        other.epochDay - epochDay
    }

    /// The date `months` months after this one, with the day **clamped** to the month it lands
    /// in; a negative count runs backwards.
    ///
    /// `kotlinx.datetime.LocalDate.plus(n, DateTimeUnit.MONTH)` (`CycleViewModel.kt:162`, the
    /// month the grid is paged to). The year/month pair moves and the day comes along only as far
    /// as the new month reaches: 2026-01-31 + 1 month is 2026-02-28, and 2024-01-31 + 1 month is
    /// 2024-02-29.
    ///
    /// The clamp is spelled out here rather than delegated to `init(year:month:day:)`, which
    /// normalises a too-large day by *carrying* it into the following month — that initialiser
    /// would answer 2026-03-03 for the first example, three days past the right one. Both rules
    /// are correct for what they describe; they are simply not the same rule, and month paging
    /// needs this one.
    public func plusMonths(_ months: Int) -> LocalDate {
        // A month index counted from year 0, so the shift is one addition and the year falls out
        // of it. `flooredMod` rather than `%` because the index is negative before year 0.
        let monthIndex = year * 12 + (month - 1) + months
        let monthOfYear = monthIndex.flooredMod(12)
        let targetYear = (monthIndex - monthOfYear) / 12
        let targetMonth = monthOfYear + 1
        let clampedDay = min(day, Self.lengthOfMonth(year: targetYear, month: targetMonth))

        // The triple is a real day by construction, so the initialiser normalises nothing.
        return LocalDate(year: targetYear, month: targetMonth, day: clampedDay)
    }

    /// The date `months` months before this one, clamped the same way; a negative count runs
    /// forwards.
    ///
    /// `kotlinx.datetime.LocalDate.minus(n, DateTimeUnit.MONTH)` (`CycleViewModel.kt:62`).
    public func minusMonths(_ months: Int) -> LocalDate {
        plusMonths(-months)
    }

    /// The first day of this date's month — Android's `LocalDate.firstDayOfMonth()`
    /// (`CycleViewModel.kt:208-209`, spelled `minus(day - 1, DateTimeUnit.DAY)` there), the anchor
    /// the month grid is laid out from and the value every paging action moves.
    public var firstDayOfMonth: LocalDate {
        LocalDate(year: year, month: month, day: 1)
    }

    /// How many days this date's month holds: 28, 29, 30 or 31.
    public var lengthOfMonth: Int {
        Self.lengthOfMonth(year: year, month: month)
    }

    /// The days in a month, as a static because `plusMonths` has to ask about a month before it
    /// has a `LocalDate` for it.
    ///
    /// Derived from the civil conversion — the distance from this month's first day to the next
    /// month's — rather than from a hard-coded table plus a second copy of the leap-year rule:
    /// there is then only one place in the port that knows February is short. `month` must be
    /// inside `1...12`, and month 13 is exactly what the normalising initialiser turns into
    /// January of the following year, so December needs no special case.
    private static func lengthOfMonth(year: Int, month: Int) -> Int {
        let firstOfNextMonth = LocalDate(year: year, month: month + 1, day: 1).epochDay
        return firstOfNextMonth - Self.epochDay(year: year, month: month, day: 1)
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
