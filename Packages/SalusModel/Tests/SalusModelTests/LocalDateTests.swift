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
