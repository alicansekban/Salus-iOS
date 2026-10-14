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

// MARK: - Catalog

@Suite("MilestoneCatalog and MoneySteps")
struct MilestoneCatalogTests {
    @Test("day milestones are the fixed list, then every 365 days with no upper end")
    func dayMilestones() {
        #expect(MilestoneCatalog.dayMilestones(upTo: 0).isEmpty)
        #expect(MilestoneCatalog.dayMilestones(upTo: 729) == [1, 3, 7, 14, 30, 60, 100, 180, 365])
        #expect(MilestoneCatalog.dayMilestones(upTo: 1095) == [1, 3, 7, 14, 30, 60, 100, 180, 365, 730, 1095])
    }

    @Test("the unit milestones end at 5 000 and the stages are the stage contract's ten")
    func unitsAndStages() {
        #expect(MilestoneCatalog.unitMilestones == [100, 500, 1000, 5000])
        #expect(MilestoneCatalog.healthStages == HealthStage.catalog)
        #expect(MilestoneCatalog.healthStages.map(\.id) == [
            "h_20m", "h_12h", "h_48h", "h_72h", "h_2w", "h_1mo", "h_1y", "h_5y", "h_10y", "h_15y"
        ])
    }

    @Test("EUR, USD, GBP and CHF use the small money steps")
    func smallSteps() {
        let small: [Int64] = [50, 100, 250, 500, 1000, 2500, 5000, 10000]
        for code in ["EUR", "USD", "GBP", "CHF"] {
            #expect(MoneySteps.forCurrency(code) == small, "\(code)")
        }
    }

    @Test("every other currency uses the large money steps")
    func largeSteps() {
        let large: [Int64] = [500, 1000, 2500, 5000, 10000, 25000, 50000, 100_000]
        for code in ["TRY", "JPY", "SEK", "eur", ""] {
            #expect(MoneySteps.forCurrency(code) == large, "\(code)")
        }
    }
}

// MARK: - When it plans

@Suite("MilestoneScheduler — when it plans")
struct MilestoneSchedulerWhenTests {
    @Test("not set up plans nothing")
    func notSetUp() {
        let input = SmokingInput(plan: nil, prices: [], attempts: [], events: [], goal: nil)
        #expect(milestoneSchedule(input, now: milestoneAt(0, 12)).isEmpty)
    }

    @Test("a QUIT plan with notifications off plans nothing")
    func quitNotificationsOff() {
        #expect(milestoneSchedule(
            milestoneQuitData(start: milestoneAt(0, 9), notifications: false),
            now: milestoneAt(0, 9)
        ).isEmpty)
    }

    @Test("a QUIT plan whose only attempt is closed plans nothing")
    func quitWithoutActiveAttempt() {
        let closed = SmokingInput(
            plan: milestonePlan(),
            prices: [Fixture.price(1000)],
            attempts: [Fixture.attempt(start: milestoneAt(0, 9), end: milestoneAt(1, 9), reason: .restarted)],
            events: [],
            goal: nil
        )
        #expect(milestoneSchedule(closed, now: milestoneAt(2, 9)).isEmpty)
    }

    @Test("QUIT never plans an evening reminder, whatever its flag says")
    func quitNeverEvening() {
        let planned = milestoneSchedule(
            milestoneQuitData(start: milestoneAt(0, 9), evening: true),
            now: milestoneAt(0, 9)
        )
        #expect(!planned.isEmpty)
        #expect(!planned.flatMap(\.kinds).contains(where: milestoneIsEvening))
    }
}

// MARK: - REDUCE evening

@Suite("MilestoneScheduler — REDUCE evening")
struct MilestoneSchedulerEveningTests {
    @Test("evening on plans today and the next six days at 20:30 local")
    func sevenEvenings() {
        // Now = day 0 12:00, so 20:30 on day 0 is still ahead. The day already has an entry (4 units
        // at 10:00); that is checked at fire time by the handler, never here.
        // Keys carry the local date of each day: 2024-10-04 .. 2024-10-10.
        let planned = milestoneSchedule(milestoneReduceData(evening: true), now: milestoneAt(0, 12))
        let dates = ["2024-10-04", "2024-10-05", "2024-10-06", "2024-10-07", "2024-10-08", "2024-10-09", "2024-10-10"]
        let expected = (0 ..< 7).map { offset in
            milestoneNote(
                "r:plan:\(dates[Int(offset)])",
                milestoneAt(Int64(offset), 20, 30),
                .evening(day0 + Int64(offset))
            )
        }
        #expect(planned == expected)
    }

    @Test("at or after 20:30 today is skipped: only instants strictly after now are planned")
    func eveningAtNowIsReached() {
        // Now = exactly 20:30 on day 0: that evening is reached. Six left: 2024-10-05 .. 2024-10-10.
        let planned = milestoneSchedule(milestoneReduceData(evening: true), now: milestoneAt(0, 20, 30))
        #expect(planned.count == 6)
        #expect(planned.first == milestoneNote("r:plan:2024-10-05", milestoneAt(1, 20, 30), .evening(day0 + 1)))
        #expect(planned.last?.key == "r:plan:2024-10-10")
    }

    @Test("evening off plans nothing")
    func eveningOff() {
        #expect(milestoneSchedule(milestoneReduceData(evening: false), now: milestoneAt(0, 12)).isEmpty)
    }

    @Test("evening planning depends on its own switch, not on the milestone switch")
    func eveningIgnoresMilestoneSwitch() {
        let planned = milestoneSchedule(
            milestoneReduceData(evening: true, notifications: false),
            now: milestoneAt(0, 12)
        )
        #expect(planned.count == 7)
    }

    @Test("the limit also cuts the evenings")
    func eveningLimit() {
        let planned = milestoneSchedule(milestoneReduceData(evening: true), now: milestoneAt(0, 12), limit: 2)
        #expect(planned.map(\.key) == ["r:plan:2024-10-04", "r:plan:2024-10-05"])
    }
}

// MARK: - Yearly past 15 years

@Suite("MilestoneScheduler — long horizons")
struct MilestoneSchedulerHorizonTests {
    @Test("day milestones continue every 365 days past the last health stage")
    func yearlyPastFifteenYears() {
        // UTC. Start 2010-01-01 12:00, now 2026-03-01 12:00 = 5 903 days: every stage (the last is
        // 5 475 days), unit step (59 030 not smoked) and money step (5 903 x 10 000 minor, past
        // 10 000 000) is reached. Day 365 x 16 = 5 840 is past; the next is 365 x 17 = 6 205 days =
        // 2026-12-28 12:00 UTC, then one per 365 days. The 20th is 365 x 36 = 13 140 days =
        // 2045-12-23. Epoch ms worked out with Python's datetime, not read back from the scheduler.
        let start: Int64 = 1_262_347_200_000
        let now: Int64 = 1_772_366_400_000
        let input = SmokingInput(
            plan: milestonePlan(baseline: 10),
            prices: [Fixture.price(1000, from: 14610)],
            attempts: [Fixture.attempt(start: start)],
            events: [],
            goal: nil
        )

        let planned = milestoneSchedule(input, now: now, zone: .gmt)

        #expect(planned.map(\.kinds) == (17 ... 36).map { [MilestoneKind.days(365 * Int64($0))] })
        #expect(planned.first == milestoneNote("q:a1:2026-12-28", 1_798_459_200_000, .days(6205)))
        #expect(planned.last?.key == "q:a1:2045-12-23")
        #expect(planned.last?.triggerAtMs == 2_397_643_200_000)
    }

    @Test("a 20-year horizon at 60 a day and 10 000 minor a unit does not overflow")
    func twentyYearNoOverflow() {
        // 20 years = 7 305 days. Saved = 7 305 x 60 x 10 000 = 4.38e9 minor, far inside Int64; every
        // projection stays finite and the plan is still the 20 yearly day milestones.
        let start = milestoneAt(0, 9)
        let now = start + 7305 * dayMs
        let input = milestoneQuitData(start: start, baseline: 60, cost: 10000)

        let planned = milestoneSchedule(input, now: now)

        #expect(planned.count == 20)
        #expect(planned.map(\.triggerAtMs) == planned.map(\.triggerAtMs).sorted())
        #expect(planned.first?.kinds == [.days(365 * 21)])
    }
}
