import Foundation
import Testing

@testable import SalusSmoking

// One or more tests per bullet of `smoking-domain-contract.md` §4 and its §8.8 / §8.9 readings
// (iOS-M17 plan, ruling P1: written from the contract text, not ported from Kotlin). Every expected
// instant is worked out by hand in the comment above its assertion; none was read back from the
// scheduler. Europe/Istanbul is a permanent UTC+3, so local wall-clock arithmetic there is plain
// addition. Day 20 000 (`Fixture.day0`) is 2024-10-04, so day 20 000 + n is the date in each key.

private let dayMs = Fixture.dayMs
private let hourMs = Fixture.hourMs
private let minuteMs = Fixture.minuteMs
private let day0 = Fixture.day0

// MARK: - Kinds

@Suite("MilestoneScheduler — kinds")
struct MilestoneSchedulerKindsTests {
    @Test("day zero: stages, days, units and money land per local day, in the order they are true")
    func dayZero() {
        // Start = now = day 0 09:00, baseline 20, 1 000 minor a unit: 20 000 minor a day.
        //  - h_20m 09:20 and h_12h 21:00 share day 0, which overlaps the first 48 h: two notifications.
        //  - day 1 09:00 alone.
        //  - h_48h 09:00 and 500 TRY (50 000 minor = 2.5 days) 21:00 share day 2 (still inside the
        //    first 48 h by its 00:00 start): two notifications.
        //  - h_72h and day 3 are the same instant, day 3 09:00: Stage sorts before Days, one note.
        //  - 100 units (100 / 20 = 5 days) and 1 000 TRY (100 000 / 20 000 = 5 days) both day 5 09:00:
        //    Units sorts before Money.
        let start = milestoneAt(0, 9)
        let planned = milestoneSchedule(milestoneQuitData(start: start), now: start)

        #expect(Array(planned.prefix(7)) == [
            milestoneNote("q:a1:2024-10-04:early", milestoneAt(0, 9, 20), .stage("h_20m")),
            milestoneNote("q:a1:2024-10-04", milestoneAt(0, 21), .stage("h_12h")),
            milestoneNote("q:a1:2024-10-05", milestoneAt(1, 9), .days(1)),
            milestoneNote("q:a1:2024-10-06:early", milestoneAt(2, 9), .stage("h_48h")),
            milestoneNote("q:a1:2024-10-06", milestoneAt(2, 21), .money(50000)),
            milestoneNote("q:a1:2024-10-07", milestoneAt(3, 9), .stage("h_72h"), .days(3)),
            milestoneNote("q:a1:2024-10-09", milestoneAt(5, 9), .units(100), .money(100_000))
        ])
    }

    @Test("an instant exactly at now is already reached")
    func instantAtNowIsReached() {
        // Now = start + 72 h: h_72h and day 3 fall exactly on now and are skipped, and 3 x 20 000 =
        // 60 000 minor is past the 500 TRY step. Units: 60 now, 100 is 40 / 20 = 2 days away. Money:
        // 100 000 - 60 000 = 40 000 at 20 000 a day = 2 days. Both day 5 09:00.
        let start = milestoneAt(0, 9)
        let planned = milestoneSchedule(milestoneQuitData(start: start), now: start + 3 * dayMs)
        #expect(planned.first == milestoneNote("q:a1:2024-10-09", milestoneAt(5, 9), .units(100), .money(100_000)))
    }

    @Test("a slip moves the stage instants back to the slip")
    func slipMovesStages() throws {
        // Start day 0 09:00, now day 9 15:00, baseline 10. A slip at day 7 03:00 restarts the stage
        // clock: h_48h = day 9 03:00 is past, h_72h = day 10 03:00 is planned (moved to 08:00).
        // Without the slip h_72h (day 3) is long past and h_2w (day 14 09:00) is the first stage.
        let start = milestoneAt(0, 9)
        let slip = Fixture.smoked("s1", at: milestoneAt(7, 3), units: 2)
        let now = milestoneAt(9, 15)

        let clean = milestoneSchedule(milestoneQuitData(start: start, baseline: 10), now: now).flatMap(\.kinds)
        let slipped = milestoneSchedule(milestoneQuitData(start: start, baseline: 10, events: [slip]), now: now)

        #expect(!clean.contains(.stage("h_72h")))
        let first = try #require(slipped.first)
        #expect(first.kinds.first == .stage("h_72h"))
        #expect(slipped.flatMap(\.kinds).contains(.stage("h_2w")))
    }

    @Test("a slip delays units and money but not the day milestones")
    func slipDelaysUnitsAndMoneyNotDays() {
        // Same scene. Elapsed 9.25 days.
        //  - Units: 92 not smoked (9.25 x 10 = 92.5, floored) - 2 slip units = 90, so 100 is 10 units
        //    = 1 day away: day 10 15:00.
        //  - Money: 9.25 days x 10 000 = 92 500 accrued - 2 x 1 000 = 90 500, so 100 000 is 9 500
        //    away at 10 000 a day = 22 h 48 min: day 10 13:48.
        //  - The 03:00 stage moves to 08:00. Past the first 48 h the day carries one notification,
        //    fired at its latest instant (15:00), kinds in order of their own instants:
        //    stage 03:00, money 13:48, units 15:00.
        //  - Day 14 still counts from the attempt start: days(14) at day 14 09:00, and h_2w, which
        //    would have shared that instant, is gone with the slip.
        let start = milestoneAt(0, 9)
        let slip = Fixture.smoked("s1", at: milestoneAt(7, 3), units: 2)
        let input = milestoneQuitData(start: start, baseline: 10, events: [slip])

        let planned = milestoneSchedule(input, now: milestoneAt(9, 15))

        #expect(planned.first == milestoneNote(
            "q:a1:2024-10-14", milestoneAt(10, 15), .stage("h_72h"), .money(100_000), .units(100)
        ))
        #expect(planned.first { $0.key == "q:a1:2024-10-18" } == milestoneNote(
            "q:a1:2024-10-18",
            milestoneAt(14, 9),
            .days(14)
        ))
        let clean = milestoneSchedule(milestoneQuitData(start: start, baseline: 10), now: milestoneAt(9, 15))
        #expect(clean.first { $0.key == "q:a1:2024-10-18" } == milestoneNote(
            "q:a1:2024-10-18", milestoneAt(14, 9), .stage("h_2w"), .days(14)
        ))
    }

    @Test("money is projected at today's unit cost, not the start price")
    func moneyAtTodaysCost() {
        // Start day 0 09:00, baseline 10. 1 000 minor from day 0, 2 000 from day 4. Now day 5 09:00.
        // Saved: day 0 15 h = 6 250; days 1-3 = 30 000; day 4 at 2 000 = 20 000; day 5 9 h at 2 000 =
        // 7 500; total 63 750. 100 000 is 36 250 away at today's 10 x 2 000 = 20 000 a day =
        // 43.5 h: day 7 04:30, moved to 08:00, sharing the day with days(7) (09:00), which sets the
        // trigger. At the start price it would land on day 9.
        let start = milestoneAt(0, 9)
        let input = milestoneQuitData(
            start: start,
            baseline: 10,
            prices: [Fixture.price(1000, from: day0), Fixture.price(2000, from: day0 + 4, id: "p2")]
        )

        let planned = milestoneSchedule(input, now: milestoneAt(5, 9))

        #expect(planned.first == milestoneNote("q:a1:2024-10-11", milestoneAt(7, 9), .money(100_000), .days(7)))
    }

    @Test("a zero unit cost plans no money milestones")
    func zeroCost() {
        let planned = milestoneSchedule(milestoneQuitData(start: milestoneAt(0, 9), cost: 0), now: milestoneAt(0, 9))
        #expect(!planned.isEmpty)
        #expect(!planned.flatMap(\.kinds).contains(where: milestoneIsMoney))
    }

    @Test("a zero baseline plans no units or money and does not divide by zero")
    func zeroBaseline() {
        // The contract keeps the baseline at 1 or more; a corrupt row must not crash a background resync.
        let kinds = milestoneSchedule(milestoneQuitData(start: milestoneAt(0, 9), baseline: 0), now: milestoneAt(0, 9))
            .flatMap(\.kinds)
        #expect(!kinds.contains(where: milestoneIsUnitsOrMoney))
        #expect(kinds.contains(.days(1)))
    }
}

// MARK: - Currency steps

@Suite("MilestoneScheduler — TRY and EUR money steps")
struct MilestoneSchedulerCurrencyTests {
    @Test("EUR projects its own first step, 50 EUR")
    func eurFirstStep() throws {
        // Start day 0 22:50, baseline 10, 40 minor a unit: 400 minor a day. 50 EUR = 5 000 minor
        // is 12.5 days away: day 13 10:50, outside quiet hours.
        let start = milestoneAt(0, 22, 50)
        let planned = milestoneSchedule(
            milestoneQuitData(start: start, baseline: 10, cost: 40, currency: "EUR"), now: start, limit: 100
        )
        let first = try #require(planned.first { $0.kinds.contains(where: milestoneIsMoney) })
        #expect(first == milestoneNote("q:a1:2024-10-17", milestoneAt(13, 10, 50), .money(5000)))
    }

    @Test("TRY skips the small steps: its first step is 500 TRY")
    func tryFirstStep() throws {
        // Same scene in TRY at 40 minor a unit: 500 TRY = 50 000 minor at 400 a day = 125 days:
        // day 125 22:50 is inside quiet hours and moves to day 126 08:00 (2025-02-07).
        let start = milestoneAt(0, 22, 50)
        let planned = milestoneSchedule(
            milestoneQuitData(start: start, baseline: 10, cost: 40, currency: "TRY"), now: start, limit: 100
        )
        let money = planned.flatMap(\.kinds).compactMap { kind -> Int64? in
            if case let .money(minor) = kind {
                minor
            } else {
                nil
            }
        }
        #expect(money.first == 50000)
        #expect(!money.contains(5000))
        let entry = try #require(planned.first { $0.kinds.contains(.money(50000)) })
        #expect(entry.key == "q:a1:2025-02-07")
        #expect(entry.triggerAtMs == milestoneAt(126, 8))
    }
}

// MARK: - Quiet hours

@Suite("MilestoneScheduler — quiet hours 22:00 to 08:00")
struct MilestoneSchedulerQuietHoursTests {
    @Test("an instant at ten past eleven in the evening moves to eight the next morning")
    func lateEvening() {
        // Start = now = day 0 22:50, baseline 10, 40 EUR minor. h_20m = 23:10 moves to day 1 08:00:
        // the early note of a first-48 h day whose late one is h_12h (day 1 10:50). Day 1 = day 1
        // 22:50 moves to day 2 08:00.
        let start = milestoneAt(0, 22, 50)
        let planned = milestoneSchedule(
            milestoneQuitData(start: start, baseline: 10, cost: 40, currency: "EUR"),
            now: start
        )

        #expect(Array(planned.prefix(3)) == [
            milestoneNote("q:a1:2024-10-05:early", milestoneAt(1, 8), .stage("h_20m")),
            milestoneNote("q:a1:2024-10-05", milestoneAt(1, 10, 50), .stage("h_12h")),
            milestoneNote("q:a1:2024-10-06", milestoneAt(2, 8), .days(1))
        ])
    }

    @Test("22:00 sharp is inside quiet hours")
    func tenSharp() {
        // Start = now = day 0 10:00. h_20m 10:20 stands alone on day 0. h_12h is exactly 22:00 and
        // moves to day 1 08:00, the early note of day 1, whose late one is days(1) at 10:00.
        let start = milestoneAt(0, 10)
        let planned = milestoneSchedule(milestoneQuitData(start: start), now: start)

        #expect(Array(planned.prefix(3)) == [
            milestoneNote("q:a1:2024-10-04", milestoneAt(0, 10, 20), .stage("h_20m")),
            milestoneNote("q:a1:2024-10-05:early", milestoneAt(1, 8), .stage("h_12h")),
            milestoneNote("q:a1:2024-10-05", milestoneAt(1, 10), .days(1))
        ])
    }

    @Test("the boundaries: 07:59 and 22:00 shift, 08:00 and 21:59 do not")
    func boundaries() throws {
        /// Days(1) is start + 24 h, so it lands at the start's own wall-clock time the next day.
        func dayOneTrigger(startingAt start: Int64) throws -> Int64 {
            let planned = milestoneSchedule(milestoneQuitData(start: start), now: start)
            return try #require(planned.first { $0.kinds.contains(.days(1)) }).triggerAtMs
        }
        #expect(try dayOneTrigger(startingAt: milestoneAt(0, 7, 59)) == milestoneAt(1, 8))
        #expect(try dayOneTrigger(startingAt: milestoneAt(0, 8)) == milestoneAt(1, 8))
        // Seconds count: 08:00:30 is already past the end of quiet hours and must not move back.
        #expect(try dayOneTrigger(startingAt: milestoneAt(0, 8) + 30000) == milestoneAt(1, 8) + 30000)
        #expect(try dayOneTrigger(startingAt: milestoneAt(0, 21, 59)) == milestoneAt(1, 21, 59))
        #expect(try dayOneTrigger(startingAt: milestoneAt(0, 22)) == milestoneAt(2, 8))
    }
}

// MARK: - Merging, the 48 h cap, limit, keys

@Suite("MilestoneScheduler — merging, the 48 h cap, limit and keys")
struct MilestoneSchedulerMergeTests {
    @Test("a first-48 h day splits into its earliest instant and the rest; the rest carry in instant order")
    func firstFortyEightHoursSplit() {
        // Baseline 7 200, no price (so no money): 100 units = 100 / 7 200 day = 20 min, 500 = 100 min,
        // 1 000 = 200 min, 5 000 = 1 000 min after 09:00. Day 0: 09:20 holds h_20m and units(100)
        // (the earliest instant, so the early note carries both), then units(500) 10:40, units(1000)
        // 12:20 and h_12h 21:00 (the late note, fired at 21:00, kinds ordered by their own instants).
        let start = milestoneAt(0, 9)
        let planned = milestoneSchedule(milestoneQuitData(start: start, baseline: 7200, cost: 0), now: start)

        #expect(Array(planned.prefix(2)) == [
            milestoneNote("q:a1:2024-10-04:early", milestoneAt(0, 9, 20), .stage("h_20m"), .units(100)),
            milestoneNote("q:a1:2024-10-04", milestoneAt(0, 21), .units(500), .units(1000), .stage("h_12h"))
        ])
    }

    @Test("a first-48 h day whose kinds share one instant carries one notification")
    func sharedInstantInsideFirstFortyEightHours() {
        // Baseline 100 (100 000 minor a day): day 1 09:00 holds days(1), 100 units (1 day) and
        // 100 000 minor (1 day), all one instant inside the first 48 h: one note, no :early.
        let start = milestoneAt(0, 9)
        let planned = milestoneSchedule(milestoneQuitData(start: start, baseline: 100), now: start)

        #expect(planned.contains(
            milestoneNote("q:a1:2024-10-05", milestoneAt(1, 9), .days(1), .units(100), .money(100_000))
        ))
        #expect(!planned.contains { $0.key.hasSuffix(":early") && $0.key.contains("2024-10-05") })
    }

    @Test("a day after the first 48 h fires once, at its latest instant")
    func afterFortyEightHoursOneNote() {
        // Start day 0 15:00, slip day 6 21:00, now day 6 22:00. h_12h counts from the slip: day 7
        // 09:00. Days(7) is day 7 15:00. Day 7 is far outside the first 48 h: one note, at 15:00,
        // with the earlier kind first.
        let start = milestoneAt(0, 15)
        let slip = Fixture.smoked("s1", at: milestoneAt(6, 21), units: 1)
        let planned = milestoneSchedule(milestoneQuitData(start: start, events: [slip]), now: milestoneAt(6, 22))

        let day = planned.filter { $0.key.hasPrefix("q:a1:2024-10-11") }
        #expect(day == [milestoneNote("q:a1:2024-10-11", milestoneAt(7, 15), .stage("h_12h"), .days(7))])
    }

    @Test("the cap: at most two notifications on a first-48 h day, one on any other")
    func fortyEightHourCap() {
        let start = milestoneAt(0, 9)
        let planned = milestoneSchedule(milestoneQuitData(start: start), now: start, limit: 200)

        let perDay = Dictionary(grouping: planned) { $0.key.split(separator: ":")[2] }
        let firstTwoDays: Set<Substring> = ["2024-10-04", "2024-10-05", "2024-10-06"]
        for (date, notes) in perDay {
            #expect(notes.count <= (firstTwoDays.contains(date) ? 2 : 1), "\(date): \(notes.map(\.key))")
        }
        // The first 48 h end day 2 09:00, so day 2 is the last date that may carry two; every later
        // date carries exactly one.
        #expect(perDay.filter { !firstTwoDays.contains($0.key) }.values.allSatisfy { $0.count == 1 })
    }

    @Test("nothing is announced before it is true: a notification never fires before any of its kinds")
    func neverEarly() {
        // Day 0 scene: the early note of day 2 carries only h_48h (09:00); money(50 000) is true only
        // at 21:00, and it rides the late note, never the early one.
        let start = milestoneAt(0, 9)
        let planned = milestoneSchedule(milestoneQuitData(start: start), now: start)
        let early = planned.first { $0.key == "q:a1:2024-10-06:early" }
        #expect(early?.kinds == [.stage("h_48h")])
        let late = planned.first { $0.key == "q:a1:2024-10-06" }
        #expect(late?.triggerAtMs == milestoneAt(2, 21))
    }

    @Test("a limit keeps the nearest notifications")
    func limitKeepsNearest() {
        let start = milestoneAt(0, 9)
        let input = milestoneQuitData(start: start)

        let three = milestoneSchedule(input, now: start, limit: 3)
        #expect(three.map(\.key) == ["q:a1:2024-10-04:early", "q:a1:2024-10-04", "q:a1:2024-10-05"])

        let twenty = milestoneSchedule(input, now: start)
        let wide = milestoneSchedule(input, now: start, limit: 500)
        #expect(twenty.count == 20)
        #expect(Array(wide.prefix(20)) == twenty)
        #expect(twenty.map(\.triggerAtMs) == twenty.map(\.triggerAtMs).sorted())
        #expect(Set(twenty.map(\.key)).count == 20)
    }

    @Test("a limit of zero or less plans nothing instead of trapping")
    func nonPositiveLimit() {
        let start = milestoneAt(0, 9)
        #expect(milestoneSchedule(milestoneQuitData(start: start), now: start, limit: 0).isEmpty)
        #expect(milestoneSchedule(milestoneQuitData(start: start), now: start, limit: -1).isEmpty)
        #expect(milestoneSchedule(milestoneReduceData(evening: true), now: milestoneAt(0, 12), limit: Int.min).isEmpty)
    }

    @Test("the largest limit neither overflows nor plans without bound")
    func hugeLimit() {
        // 365 x (Int.max + 1) would wrap Int64; the scheduler caps the limit instead of trapping.
        let start = milestoneAt(0, 9)
        let planned = milestoneSchedule(milestoneQuitData(start: start), now: start, limit: Int.max)
        #expect(planned.count > 20)
        #expect(planned.count <= MilestoneScheduler.maximumLimit)
        #expect(planned.map(\.triggerAtMs) == planned.map(\.triggerAtMs).sorted())
    }

    @Test("a duration is 24 h, not a calendar day: days(3) across a daylight-saving change")
    func daysAcrossDaylightSaving() throws {
        // Europe/Berlin, start 2024-10-26 12:00 (UTC+2) = 1 729 936 800 000. The clocks go back on
        // 2024-10-27, so start + 72 h is 2024-10-29 11:00 local, one hour earlier on the wall clock
        // than a calendar-day reading (12:00). 1 729 936 800 000 + 259 200 000 = 1 730 196 000 000.
        let berlin = Fixture.berlin
        let start: Int64 = 1_729_936_800_000
        let input = SmokingInput(
            plan: milestonePlan(baseline: 1),
            prices: [Fixture.price(100, from: 20022)],
            attempts: [Fixture.attempt(start: start, tz: "Europe/Berlin")],
            events: [],
            goal: nil
        )

        let planned = milestoneSchedule(input, now: start, zone: berlin, limit: 100)

        let dayThree = try #require(planned.first { $0.kinds.contains(.days(3)) })
        #expect(dayThree == milestoneNote("q:a1:2024-10-29", 1_730_196_000_000, .stage("h_72h"), .days(3)))
    }
}
