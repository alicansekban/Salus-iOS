import Testing

@testable import SalusModel

// `LocalDate` has no Kotlin twin to copy a test table from: Android gets the type from
// `kotlinx.datetime` and tests the library's arithmetic nowhere. What the table below pins is the
// contract the Android code relies on and the port must reproduce exactly — the proleptic
// Gregorian calendar with epochDay 0 = 1970-01-01, the same origin `RecurrenceRule.kt:6` and every
// Room `epochDay` column are written against.
//
// The reference values were produced independently (Python's `datetime.date`, which is proleptic
// Gregorian too) and are literal here on purpose: recomputing them with the implementation under
// test would assert nothing.

/// One civil-date row: an epoch day and the date it names.
typealias CivilDateRow = (epochDay: Int, year: Int, month: Int, day: Int)

/// One weekday row: an epoch day and its Monday-based index (Monday = 0 … Sunday = 6).
typealias WeekdayRow = (epochDay: Int, mondayIndex: Int)

/// The reference table, shared by the two directions of the conversion.
let civilDateRows: [CivilDateRow] = [
    (0, 1970, 1, 1), // the epoch itself
    (-1, 1969, 12, 31), // the day before it
    (-365, 1969, 1, 1), // a full year before it
    (11016, 2000, 2, 29), // the leap day of a century that IS a leap year
    (11017, 2000, 3, 1), // the day after it
    (20687, 2026, 8, 22),
    (-25567, 1900, 1, 1), // 1900 is NOT a leap year (divisible by 100, not by 400)
    (-25509, 1900, 2, 28), // so February 1900 ends here
    (-135_081, 1600, 2, 29), // 1600 IS a leap year (divisible by 400)
    (-719_162, 1, 1, 1), // the first day of the proleptic Gregorian era
    (157_054, 2400, 1, 1)
]

@Suite("LocalDate — civil date from epoch day")
struct LocalDateFromEpochDayTests {
    @Test("an epoch day decodes to its proleptic Gregorian date", arguments: civilDateRows)
    func civilFromEpochDay(_ row: CivilDateRow) {
        let date = LocalDate(epochDay: row.epochDay)

        #expect(date.year == row.year, "epochDay \(row.epochDay) year")
        #expect(date.month == row.month, "epochDay \(row.epochDay) month")
        #expect(date.day == row.day, "epochDay \(row.epochDay) day")
    }

    @Test("a proleptic Gregorian date encodes back to its epoch day", arguments: civilDateRows)
    func epochDayFromCivil(_ row: CivilDateRow) {
        let date = LocalDate(year: row.year, month: row.month, day: row.day)

        #expect(date.epochDay == row.epochDay, "\(row.year)-\(row.month)-\(row.day)")
    }
}

@Suite("LocalDate — weekday index")
struct LocalDateWeekdayTests {
    @Test(
        "the Monday-based weekday index runs Monday = 0 … Sunday = 6, negative epoch days included",
        arguments: [
            (0, 3), // 1970-01-01 is a Thursday — the constant RecurrenceRule.kt:11 encodes
            (1, 4), // Friday
            (2, 5), // Saturday
            (3, 6), // Sunday
            (4, 0), // Monday
            (5, 1), // Tuesday
            (6, 2), // Wednesday
            (7, 3), // Thursday again, one week on
            (-1, 2), // 1969-12-31, a Wednesday
            (-4, 6), // 1969-12-28, a Sunday: Swift's `%` would return -1 here, Kotlin's `mod` 6
            (-25567, 0), // 1900-01-01, a Monday
            (20687, 5) // 2026-08-22, a Saturday
        ] as [WeekdayRow]
    )
    func mondayBasedWeekdayIndex(_ row: WeekdayRow) {
        #expect(LocalDate(epochDay: row.epochDay).mondayBasedWeekdayIndex == row.mondayIndex)
    }

    @Test("the index is always inside 0…6, over a long negative and positive sweep")
    func indexStaysInRange() {
        for epochDay in -3000 ... 3000 {
            let index = LocalDate(epochDay: epochDay).mondayBasedWeekdayIndex
            #expect((0 ... 6).contains(index), "epochDay \(epochDay) produced \(index)")
        }
    }
}

@Suite("LocalDate — round trip and ordering")
struct LocalDateRoundTripTests {
    @Test("every day of 2024, 2025 and 2026 round-trips through the civil representation")
    func roundTripOverThreeYears() {
        // 2024-01-01 through 2026-12-31 — 1096 days, including a leap day.
        var seen = 0
        for epochDay in 19723 ... 20818 {
            let date = LocalDate(epochDay: epochDay)
            #expect(date.epochDay == epochDay, "epochDay \(epochDay) did not round-trip")

            let rebuilt = LocalDate(year: date.year, month: date.month, day: date.day)
            #expect(rebuilt == date, "epochDay \(epochDay) rebuilt as \(rebuilt)")
            seen += 1
        }
        #expect(seen == 1096)
    }

    @Test("the components stay inside the calendar over the same sweep")
    func componentsAreValid() {
        for epochDay in 19723 ... 20818 {
            let date = LocalDate(epochDay: epochDay)
            #expect((1 ... 12).contains(date.month), "epochDay \(epochDay) month \(date.month)")
            #expect((1 ... 31).contains(date.day), "epochDay \(epochDay) day \(date.day)")
            #expect(date.year == 2024 || date.year == 2025 || date.year == 2026)
        }
    }

    @Test("ordering follows the epoch day")
    func ordering() {
        let earlier = LocalDate(year: 1969, month: 12, day: 31)
        let epoch = LocalDate(epochDay: 0)
        let sameDay = LocalDate(year: 1970, month: 1, day: 1)
        let later = LocalDate(year: 2026, month: 8, day: 22)

        #expect(earlier < epoch)
        #expect(epoch < later)
        #expect(earlier < later)
        // Two dates naming the same day order neither way, whichever initialiser built them.
        #expect(!(epoch < sameDay))
        #expect(!(sameDay < epoch))
        #expect(epoch == sameDay)
        #expect([later, earlier, epoch].sorted() == [earlier, epoch, later])
    }

    @Test("equal dates hash equally")
    func hashing() {
        let dates: Set<LocalDate> = [
            LocalDate(epochDay: 0),
            LocalDate(year: 1970, month: 1, day: 1),
            LocalDate(year: 2026, month: 8, day: 22)
        ]

        #expect(dates.count == 2)
    }
}

// MARK: - Normalisation of impossible component triples

// The M1 review's deferred finding, closed here. `kotlinx.datetime.LocalDate(year, month, day)`
// THROWS on a triple that names no real day; a Swift initialiser that throws would push a `try`
// into every call site, including the SwiftUI date pickers this milestone builds, so the M1 ruling
// picked normalisation instead: the triple is carried the arithmetic distance it names, exactly as
// `java.time.LocalDate.plusDays` would.
//
// The invariant that makes this safe is that `epochDay` — the wire, the storage unit and the
// ordering key — is total: every triple maps to one day, and that day is what `Equatable`,
// `Comparable` and `Hashable` all read. Before this change 2026-02-30 was a value that compared
// unequal to 2026-03-02 while ordering neither before nor after it, which is an `Equatable` /
// `Comparable` contradiction a `sorted()` or a `Set` would have shown as a bug much later.
//
// The reference values were produced independently (Python `datetime.date(y, 1, 1) + timedelta`),
// never by the implementation under test.

/// One normalisation row: the triple as written, and the real date it names.
typealias NormalisationRow = (
    year: Int, month: Int, day: Int,
    expectedYear: Int, expectedMonth: Int, expectedDay: Int
)

let normalisationRows: [NormalisationRow] = [
    // A real date is its own normal form — the overwhelmingly common case.
    (2026, 8, 22, 2026, 8, 22),
    (1970, 1, 1, 1970, 1, 1),
    // Day past the end of the month.
    (2026, 2, 30, 2026, 3, 2), // February 2026 has 28 days
    (2026, 2, 29, 2026, 3, 1), // 2026 is not a leap year
    (2024, 2, 30, 2024, 3, 1), // 2024 is, so February has one more day to spend
    (2026, 4, 31, 2026, 5, 1), // April has 30
    (2026, 12, 32, 2027, 1, 1), // and a spill past December rolls the year
    // Day at or below zero: day 0 is the last day of the previous month, by the same arithmetic.
    (2026, 3, 0, 2026, 2, 28),
    (2024, 3, 0, 2024, 2, 29),
    (2026, 1, 0, 2025, 12, 31),
    // Month out of range rolls the year, in both directions.
    (2026, 13, 1, 2027, 1, 1),
    (2026, 14, 15, 2027, 2, 15),
    (2026, 0, 1, 2025, 12, 1),
    (2026, -1, 1, 2025, 11, 1),
    (2026, 25, 1, 2028, 1, 1),
    // Month and day both out of range, and a year before the epoch.
    (1969, 13, 32, 1970, 2, 1),
    (2026, 15, 31, 2027, 3, 31)
]

@Suite("LocalDate — normalisation")
struct LocalDateNormalisationTests {
    @Test("an impossible component triple normalises to the day it names", arguments: normalisationRows)
    func normalises(_ row: NormalisationRow) {
        let date = LocalDate(year: row.year, month: row.month, day: row.day)
        let expected = LocalDate(
            year: row.expectedYear,
            month: row.expectedMonth,
            day: row.expectedDay
        )

        let written = "\(row.year)-\(row.month)-\(row.day)"
        #expect(date.year == row.expectedYear, "\(written) year")
        #expect(date.month == row.expectedMonth, "\(written) month")
        #expect(date.day == row.expectedDay, "\(written) day")
        #expect(date.epochDay == expected.epochDay, "\(written) epoch day")
    }

    /// The contradiction the normalisation removes: `==` and `<` now answer about the same day.
    @Test("Equatable and Comparable agree about a normalised date")
    func equalityAndOrderingAgree() {
        let impossible = LocalDate(year: 2026, month: 2, day: 30)
        let real = LocalDate(year: 2026, month: 3, day: 2)

        #expect(impossible == real)
        #expect(!(impossible < real))
        #expect(!(real < impossible))
        #expect(impossible.hashValue == real.hashValue)
        #expect(Set([impossible, real]).count == 1)
    }

    /// Normalising must not disturb the epoch-day round trip the whole port is written against.
    @Test("normalisation is idempotent and epoch-day stable over a long sweep")
    func idempotentOverASweep() {
        for epochDay in -3000 ... 3000 {
            let date = LocalDate(epochDay: epochDay)
            let rebuilt = LocalDate(year: date.year, month: date.month, day: date.day)

            #expect(rebuilt == date)
            #expect(rebuilt.epochDay == epochDay)
        }
    }
}

// MARK: - Day and month arithmetic

// The four operations the Cycle month grid and the predictor are written against
// (`CycleViewModel.kt:162-168`, `CyclePredictorTest.kt:30`): kotlinx-datetime's
// `plus(n, DateTimeUnit.DAY)`, `plus(n, DateTimeUnit.MONTH)`, `daysUntil` and `isoDayNumber`.
// Android gets all four from the library and tests none of them, so — as with the table at the top
// of this file — these rows pin the library contract the port reproduces, not a carried-over Kotlin
// test file. Reference values came from Python `datetime.date` / `calendar.monthrange`, never from
// the implementation under test.
//
// The month rule is worth stating out loud: it is the single place this arithmetic disagrees with
// the normalising initialiser. `plus(n, MONTH)` moves the year/month pair and then **clamps** the
// day to the month it lands in, so 2026-01-31 + 1 month is 2026-02-28, where the initialiser's
// `LocalDate(year: 2026, month: 2, day: 31)` would carry instead and answer 2026-03-03.

/// One day-shift row: a start date, a signed number of days, and the date it lands on.
typealias DayShiftRow = (start: LocalDate, days: Int, expected: LocalDate)

let dayShiftRows: [DayShiftRow] = [
    // Across a year boundary, in both directions.
    (LocalDate(year: 2025, month: 12, day: 31), 1, LocalDate(year: 2026, month: 1, day: 1)),
    (LocalDate(year: 2026, month: 1, day: 1), -1, LocalDate(year: 2025, month: 12, day: 31)),
    (LocalDate(year: 2026, month: 12, day: 31), 1, LocalDate(year: 2027, month: 1, day: 1)),
    // Across the epoch itself, which is where a sign bug shows up first.
    (LocalDate(year: 1970, month: 1, day: 1), -1, LocalDate(year: 1969, month: 12, day: 31)),
    (LocalDate(year: 1969, month: 12, day: 31), 1, LocalDate(year: 1970, month: 1, day: 1)),
    // Wholly before 1970, including a leap day and a whole year's worth of days.
    (LocalDate(year: 1968, month: 2, day: 28), 1, LocalDate(year: 1968, month: 2, day: 29)),
    (LocalDate(year: 1969, month: 1, day: 1), -365, LocalDate(year: 1968, month: 1, day: 2)),
    (LocalDate(year: 1969, month: 12, day: 31), -365, LocalDate(year: 1968, month: 12, day: 31)),
    (LocalDate(year: 1900, month: 1, day: 1), 59, LocalDate(year: 1900, month: 3, day: 1)),
    (LocalDate(year: 2024, month: 2, day: 28), 1, LocalDate(year: 2024, month: 2, day: 29)),
    (LocalDate(year: 2026, month: 2, day: 28), 1, LocalDate(year: 2026, month: 3, day: 1)),
    (LocalDate(year: 2026, month: 8, day: 22), 365, LocalDate(year: 2027, month: 8, day: 22)),
    (LocalDate(year: 2026, month: 8, day: 22), 0, LocalDate(year: 2026, month: 8, day: 22)),
    // All the way back to the first day of the proleptic Gregorian era.
    (LocalDate(year: 1970, month: 1, day: 1), -719_162, LocalDate(year: 1, month: 1, day: 1))
]

@Suite("LocalDate — day arithmetic")
struct LocalDateDayArithmeticTests {
    @Test("plusDays moves the date by a signed number of days", arguments: dayShiftRows)
    func plusDays(_ row: DayShiftRow) {
        #expect(row.start.plusDays(row.days) == row.expected, "\(row.start) + \(row.days) days")
    }

    @Test("minusDays is plusDays with the sign flipped", arguments: dayShiftRows)
    func minusDays(_ row: DayShiftRow) {
        #expect(row.start.minusDays(-row.days) == row.expected, "\(row.start) - \(-row.days) days")
    }

    @Test("a day shift is exactly an epoch-day shift, over a sweep across the epoch")
    func shiftMatchesEpochDayOverASweep() {
        for epochDay in -800 ... 800 {
            let date = LocalDate(epochDay: epochDay)
            for shift in [-400, -31, -1, 0, 1, 31, 400] {
                #expect(date.plusDays(shift).epochDay == epochDay + shift)
                #expect(date.minusDays(shift).epochDay == epochDay - shift)
            }
        }
    }
}

/// One `daysUntil` row: two dates and the signed day count from the first to the second.
typealias DaysUntilRow = (from: LocalDate, to: LocalDate, days: Int)

let daysUntilRows: [DaysUntilRow] = [
    // Positive: the direction `CycleViewModel.kt:141` reads for the days-to-next-period figure.
    (LocalDate(year: 2026, month: 8, day: 22), LocalDate(year: 2026, month: 9, day: 5), 14),
    // Negative: `other - this`, so a date in the past counts down.
    (LocalDate(year: 2026, month: 9, day: 5), LocalDate(year: 2026, month: 8, day: 22), -14),
    // Zero: the same day is nought days away from itself.
    (LocalDate(year: 2026, month: 8, day: 22), LocalDate(year: 2026, month: 8, day: 22), 0),
    // Across the epoch, where a truncating division would round the wrong way.
    (LocalDate(year: 1969, month: 12, day: 25), LocalDate(year: 1970, month: 1, day: 5), 11),
    (LocalDate(year: 2024, month: 2, day: 28), LocalDate(year: 2024, month: 3, day: 1), 2),
    (LocalDate(year: 2026, month: 2, day: 28), LocalDate(year: 2026, month: 3, day: 1), 1),
    // The epoch to a known epoch day, which the table at the top of this file already pins.
    (LocalDate(year: 1970, month: 1, day: 1), LocalDate(year: 2026, month: 8, day: 22), 20687)
]

@Suite("LocalDate — daysUntil")
struct LocalDateDaysUntilTests {
    @Test("daysUntil counts the signed days from the receiver to the argument", arguments: daysUntilRows)
    func daysUntil(_ row: DaysUntilRow) {
        #expect(row.from.daysUntil(row.to) == row.days, "\(row.from) until \(row.to)")
        // Antisymmetric: the same pair read the other way round counts the other way.
        #expect(row.to.daysUntil(row.from) == -row.days)
    }

    @Test("daysUntil is the inverse of plusDays, over a sweep across the epoch")
    func daysUntilInvertsPlusDays() {
        for epochDay in -800 ... 800 {
            let date = LocalDate(epochDay: epochDay)
            for shift in [-400, -31, -1, 0, 1, 31, 400] {
                #expect(date.daysUntil(date.plusDays(shift)) == shift)
            }
        }
    }
}

/// One month-shift row: a start date, a signed number of months, and the date it lands on.
typealias MonthShiftRow = (start: LocalDate, months: Int, expected: LocalDate)

let monthShiftRows: [MonthShiftRow] = [
    // The clamp, in every shape the calendar offers it.
    (LocalDate(year: 2026, month: 1, day: 31), 1, LocalDate(year: 2026, month: 2, day: 28)),
    (LocalDate(year: 2024, month: 1, day: 31), 1, LocalDate(year: 2024, month: 2, day: 29)),
    (LocalDate(year: 2026, month: 3, day: 31), -1, LocalDate(year: 2026, month: 2, day: 28)),
    (LocalDate(year: 2026, month: 5, day: 31), -1, LocalDate(year: 2026, month: 4, day: 30)),
    (LocalDate(year: 2026, month: 10, day: 31), 4, LocalDate(year: 2027, month: 2, day: 28)),
    // A leap day clamped by landing in a common year, and unclamped by landing in a leap one.
    (LocalDate(year: 2000, month: 2, day: 29), 12, LocalDate(year: 2001, month: 2, day: 28)),
    (LocalDate(year: 2000, month: 2, day: 29), 48, LocalDate(year: 2004, month: 2, day: 29)),
    // ±12 months is the same day one year on or back, clamp or no clamp.
    (LocalDate(year: 2026, month: 8, day: 22), 12, LocalDate(year: 2027, month: 8, day: 22)),
    (LocalDate(year: 2026, month: 8, day: 22), -12, LocalDate(year: 2025, month: 8, day: 22)),
    (LocalDate(year: 2026, month: 1, day: 31), 12, LocalDate(year: 2027, month: 1, day: 31)),
    // Zero is the identity — the month grid leans on it when the user has not paged yet.
    (LocalDate(year: 2026, month: 8, day: 22), 0, LocalDate(year: 2026, month: 8, day: 22)),
    (LocalDate(year: 2026, month: 12, day: 15), 1, LocalDate(year: 2027, month: 1, day: 15)),
    (LocalDate(year: 2026, month: 1, day: 15), -1, LocalDate(year: 2025, month: 12, day: 15)),
    (LocalDate(year: 2026, month: 8, day: 22), -14, LocalDate(year: 2025, month: 6, day: 22)),
    // Across the epoch, where the month index has to floor rather than truncate.
    (LocalDate(year: 1970, month: 1, day: 31), -1, LocalDate(year: 1969, month: 12, day: 31)),
    (LocalDate(year: 1969, month: 12, day: 31), 2, LocalDate(year: 1970, month: 2, day: 28))
]

@Suite("LocalDate — month arithmetic")
struct LocalDateMonthArithmeticTests {
    @Test("plusMonths moves the month and clamps the day to it", arguments: monthShiftRows)
    func plusMonths(_ row: MonthShiftRow) {
        #expect(row.start.plusMonths(row.months) == row.expected, "\(row.start) + \(row.months) months")
    }

    @Test("minusMonths is plusMonths with the sign flipped", arguments: monthShiftRows)
    func minusMonths(_ row: MonthShiftRow) {
        #expect(row.start.minusMonths(-row.months) == row.expected)
    }

    /// The distinction this whole table exists for, stated as one assertion.
    @Test("the clamp is a clamp, not the normalising initialiser's carry")
    func clampDoesNotCarry() {
        let clamped = LocalDate(year: 2026, month: 1, day: 31).plusMonths(1)
        let carried = LocalDate(year: 2026, month: 2, day: 31)

        #expect(clamped == LocalDate(year: 2026, month: 2, day: 28))
        #expect(carried == LocalDate(year: 2026, month: 3, day: 3))
        #expect(clamped != carried)
    }

    @Test("a month shift always lands on the named month, over a sweep of every start day")
    func landsOnTheNamedMonthOverASweep() {
        // Every day of 2024 (a leap year) shifted by every offset inside ±14 months.
        for epochDay in 19723 ... 20088 {
            let date = LocalDate(epochDay: epochDay)
            for months in -14 ... 14 {
                let shifted = date.plusMonths(months)
                let expectedIndex = (date.year * 12 + date.month - 1) + months

                #expect(shifted.year * 12 + shifted.month - 1 == expectedIndex)
                #expect(shifted.day == min(date.day, shifted.lengthOfMonth))
                #expect(shifted.minusMonths(months).month == date.month)
            }
        }
    }
}

/// One month-shape row: a year and month, and how many days that month holds.
typealias MonthLengthRow = (year: Int, month: Int, length: Int)

let monthLengthRows: [MonthLengthRow] = [
    (2026, 2, 28), // February in a common year
    (2024, 2, 29), // February in a leap year
    (2000, 2, 29), // divisible by 400, so a leap year after all
    (1900, 2, 28), // divisible by 100 but not 400, so a common one
    (2026, 1, 31), (2026, 3, 31), (2026, 5, 31), (2026, 7, 31),
    (2026, 8, 31), (2026, 10, 31), (2026, 12, 31), // the 31-day months
    (2026, 4, 30), (2026, 6, 30), (2026, 9, 30), (2026, 11, 30) // and the 30-day ones
]

@Suite("LocalDate — month shape")
struct LocalDateMonthShapeTests {
    @Test("lengthOfMonth answers the days the month holds", arguments: monthLengthRows)
    func lengthOfMonth(_ row: MonthLengthRow) {
        let date = LocalDate(year: row.year, month: row.month, day: 1)

        #expect(date.lengthOfMonth == row.length, "\(row.year)-\(row.month)")
        // Every day of the month reads the same length, not just the first.
        #expect(LocalDate(year: row.year, month: row.month, day: row.length).lengthOfMonth == row.length)
    }

    @Test("lengthOfMonth is the distance to the next month's first day", arguments: monthLengthRows)
    func lengthOfMonthMatchesTheNextMonth(_ row: MonthLengthRow) {
        let first = LocalDate(year: row.year, month: row.month, day: 1)

        #expect(first.daysUntil(first.plusMonths(1)) == row.length)
    }

    @Test("firstDayOfMonth keeps the year and month and answers day 1")
    func firstDayOfMonth() {
        #expect(LocalDate(year: 2026, month: 8, day: 22).firstDayOfMonth == LocalDate(year: 2026, month: 8, day: 1))
        #expect(LocalDate(year: 2026, month: 8, day: 1).firstDayOfMonth == LocalDate(year: 2026, month: 8, day: 1))
        #expect(LocalDate(year: 1969, month: 12, day: 31).firstDayOfMonth == LocalDate(year: 1969, month: 12, day: 1))
        #expect(LocalDate(year: 2024, month: 2, day: 29).firstDayOfMonth == LocalDate(year: 2024, month: 2, day: 1))
    }

    /// Android spells it `minus(day - 1, DateTimeUnit.DAY)` (`CycleViewModel.kt:208-209`); the two
    /// forms have to agree on every day of the sweep, or the month grid starts on the wrong cell.
    @Test("firstDayOfMonth matches Android's day-count spelling over a sweep")
    func firstDayOfMonthMatchesAndroidOverASweep() {
        for epochDay in -800 ... 20818 {
            let date = LocalDate(epochDay: epochDay)
            let first = date.firstDayOfMonth

            #expect(first == date.minusDays(date.day - 1))
            #expect(first.day == 1)
            #expect(first.year == date.year)
            #expect(first.month == date.month)
        }
    }
}

/// One ISO weekday row: a date and its ISO day number (Monday = 1 … Sunday = 7).
typealias IsoDayRow = (date: LocalDate, isoDayNumber: Int)

let isoDayRows: [IsoDayRow] = [
    (LocalDate(year: 2026, month: 8, day: 24), 1), // a known Monday
    (LocalDate(year: 2026, month: 8, day: 25), 2),
    (LocalDate(year: 2026, month: 8, day: 26), 3),
    (LocalDate(year: 2026, month: 8, day: 27), 4),
    (LocalDate(year: 2026, month: 8, day: 28), 5),
    (LocalDate(year: 2026, month: 8, day: 22), 6),
    (LocalDate(year: 2026, month: 8, day: 23), 7), // a known Sunday
    (LocalDate(year: 1970, month: 1, day: 1), 4), // the epoch, a Thursday
    (LocalDate(year: 1900, month: 1, day: 1), 1), // a Monday well before it
    (LocalDate(year: 1969, month: 12, day: 28), 7) // and a Sunday before it
]

@Suite("LocalDate — ISO day number")
struct LocalDateIsoDayNumberTests {
    @Test("isoDayNumber runs Monday = 1 … Sunday = 7", arguments: isoDayRows)
    func isoDayNumber(_ row: IsoDayRow) {
        #expect(row.date.isoDayNumber == row.isoDayNumber, "\(row.date)")
    }

    /// `CycleViewModel.kt:163` backs the grid up to the Monday of the first week with
    /// `minus(isoDayNumber - 1, DAY)`, so the two indexings must stay one apart, always.
    @Test("isoDayNumber is one past the Monday-based index, over a long sweep")
    func isoDayNumberFollowsTheMondayIndex() {
        for epochDay in -3000 ... 3000 {
            let date = LocalDate(epochDay: epochDay)

            #expect(date.isoDayNumber == date.mondayBasedWeekdayIndex + 1)
            #expect((1 ... 7).contains(date.isoDayNumber), "epochDay \(epochDay)")
            // Backing up by `isoDayNumber - 1` days always lands on a Monday.
            #expect(date.minusDays(date.isoDayNumber - 1).isoDayNumber == 1)
        }
    }
}
