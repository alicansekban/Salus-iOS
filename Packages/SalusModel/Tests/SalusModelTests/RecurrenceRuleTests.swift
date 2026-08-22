import Testing

@testable import SalusModel

// Table test for the single source of truth of "does a schedule occur on this day"
// (`RecurrenceRule.kt:8-35`). Android has no unit test of its own for this object yet, so the
// table below is written straight against the Kotlin branches, one row per branch and per edge:
// the anchor cut-off, each weekday bit, the interval arithmetic and the two "never" answers.
//
// Weekday reference (epochDay 0 = 1970-01-01, a Thursday):
//   epochDay 3 = 1970-01-04, a Sunday   -> Monday-based index 6, bit 6 = 64
//   epochDay 4 = 1970-01-05, a Monday   -> Monday-based index 0, bit 0 = 1
//   epochDay -4 = 1969-12-28, a Sunday  -> the case Swift's `%` gets wrong and Kotlin's `mod`
//                                          gets right (RecurrenceRule.kt:25)

/// One occurrence row: the rule's inputs and the answer `occursOn` must give.
typealias OccurrenceRow = (
    recurrence: Recurrence,
    mask: Int,
    intervalDays: Int?,
    anchor: Int,
    epochDay: Int,
    expected: Bool
)

/// Only Monday's bit set (bit 0).
private let mondayOnly = 1
/// Only Sunday's bit set (bit 6).
private let sundayOnly = 64
/// All seven bits set.
private let everyDay = 127

@Suite("RecurrenceRule.occursOn (RecurrenceRule.kt:13-34)")
struct RecurrenceRuleTests {
    @Test(
        "the rule answers exactly as the Kotlin branches do",
        arguments: [
            // --- the anchor cut-off comes first, for every recurrence (RecurrenceRule.kt:21)
            (Recurrence.daily, 0, nil, 100, 99, false),
            (Recurrence.daysOfWeek, everyDay, nil, 100, 99, false),
            (Recurrence.intervalDays, 0, 1, 100, 99, false),
            (Recurrence.asNeeded, 0, nil, 100, 99, false),

            // --- DAILY: every day from the anchor on (RecurrenceRule.kt:23)
            (Recurrence.daily, 0, nil, 100, 100, true),
            (Recurrence.daily, 0, nil, 100, 101, true),
            (Recurrence.daily, 0, nil, 100, 1000, true),

            // --- DAYS_OF_WEEK: the mask bit for the day (RecurrenceRule.kt:24-27)
            (Recurrence.daysOfWeek, mondayOnly, nil, 0, 4, true), // Monday, Monday bit
            (Recurrence.daysOfWeek, mondayOnly, nil, 0, 3, false), // Sunday, Monday bit
            (Recurrence.daysOfWeek, sundayOnly, nil, 0, 3, true), // Sunday, Sunday bit
            (Recurrence.daysOfWeek, sundayOnly, nil, 0, 4, false), // Monday, Sunday bit
            (Recurrence.daysOfWeek, everyDay, nil, 0, 3, true),
            (Recurrence.daysOfWeek, everyDay, nil, 0, 4, true),
            (Recurrence.daysOfWeek, 0, nil, 0, 4, false), // an empty mask never occurs
            (Recurrence.daysOfWeek, mondayOnly, nil, 0, 11, true), // the next Monday
            // negative epoch days: `mod` keeps the index inside 0…6
            (Recurrence.daysOfWeek, sundayOnly, nil, -10, -4, true), // 1969-12-28, a Sunday
            (Recurrence.daysOfWeek, mondayOnly, nil, -10, -4, false),
            (Recurrence.daysOfWeek, mondayOnly, nil, -10, -3, true), // 1969-12-29, a Monday

            // --- INTERVAL_DAYS: every `interval`-th day from the anchor (RecurrenceRule.kt:28-31)
            (Recurrence.intervalDays, 0, 3, 100, 100, true), // the anchor day itself
            (Recurrence.intervalDays, 0, 3, 100, 103, true),
            (Recurrence.intervalDays, 0, 3, 100, 106, true),
            (Recurrence.intervalDays, 0, 3, 100, 101, false),
            (Recurrence.intervalDays, 0, 3, 100, 102, false),
            (Recurrence.intervalDays, 0, 1, 100, 137, true), // every day
            (Recurrence.intervalDays, 0, 0, 100, 100, false), // a zero interval never occurs
            (Recurrence.intervalDays, 0, -3, 100, 100, false), // nor a negative one
            (Recurrence.intervalDays, 0, nil, 100, 100, false), // nor a missing one

            // --- AS_NEEDED: never scheduled (RecurrenceRule.kt:32)
            (Recurrence.asNeeded, everyDay, 1, 100, 100, false),
            (Recurrence.asNeeded, everyDay, 1, 100, 200, false)
        ] as [OccurrenceRow]
    )
    func occursOn(_ row: OccurrenceRow) {
        let occurs = RecurrenceRule.occursOn(
            recurrence: row.recurrence,
            daysOfWeekMask: row.mask,
            intervalDays: row.intervalDays,
            anchorEpochDay: row.anchor,
            epochDay: row.epochDay
        )

        #expect(
            occurs == row.expected,
            """
            \(row.recurrence.rawValue) mask=\(row.mask) interval=\(row.intervalDays.map(String.init) ?? "nil") \
            anchor=\(row.anchor) epochDay=\(row.epochDay)
            """
        )
    }

    @Test("a full week of a DAYS_OF_WEEK mask hits exactly the days the mask names")
    func weekdayMaskCoversTheWholeWeek() {
        // Monday, Wednesday and Friday: bits 0, 2 and 4.
        let mask = 1 | (1 << 2) | (1 << 4)
        // epochDay 4…10 is 1970-01-05 (Monday) through 1970-01-11 (Sunday).
        let occurrences = (4 ... 10).map { epochDay in
            RecurrenceRule.occursOn(
                recurrence: .daysOfWeek,
                daysOfWeekMask: mask,
                intervalDays: nil,
                anchorEpochDay: 0,
                epochDay: epochDay
            )
        }

        #expect(occurrences == [true, false, true, false, true, false, false])
    }
}
