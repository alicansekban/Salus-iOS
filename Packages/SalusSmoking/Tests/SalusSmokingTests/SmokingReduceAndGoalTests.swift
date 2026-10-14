import Foundation
import Testing

@testable import SalusSmoking

// REDUCE, goal and catalog rules of `smoking-domain-contract.md` §3 (rules 12 to 14); the QUIT
// rules are in `SmokingStatsCalculatorTests.swift`.

private let day = Fixture.dayMs
private let hour = Fixture.hourMs

@Suite("SmokingStatsCalculator — REDUCE (rules 12 and 13)")
struct ReduceTests {
    /// Day 20 010 noon. Baseline 20, limit 10, price 1 000.
    private let now = Fixture.midnight(Fixture.day0 + 10) + 12 * hour

    @Test("a day without a SMOKED event is no data, never zero")
    func noDataIsNotZero() throws {
        let events = [Fixture.smoked("s1", at: Fixture.midnight(Fixture.day0 + 8) + 9 * hour, units: 6, attempt: nil)]
        let snapshot = try reduceSnapshot(Fixture.reduceInput(events: events), now: now)
        #expect(snapshot.todayEpochDay == Fixture.day0 + 10)
        #expect(snapshot.last7Days.map(\.epochDay) == Array((Fixture.day0 + 4) ... (Fixture.day0 + 10)))
        #expect(snapshot.last7Days.map(\.units) == [nil, nil, nil, nil, 6, nil, nil])
        // Only the logged day counts: 20 - 6. A zero-filled gap would add 20 per empty day.
        #expect(snapshot.weekReductionUnits == 14)
        #expect(snapshot.weekSavedMinor == 14000)
        #expect(snapshot.todayHasEntry == false)
        #expect(snapshot.todayUnits == 0)
        #expect(snapshot.dailyLimit == 10)
    }

    @Test("the none-today marker is an entry that smoked nothing")
    func zeroMarker() throws {
        let marker = Fixture.smoked("s1", at: Fixture.midnight(Fixture.day0 + 10) + 8 * hour, units: 0, attempt: nil)
        let snapshot = try reduceSnapshot(Fixture.reduceInput(events: [marker]), now: now)
        #expect(snapshot.todayHasEntry == true)
        #expect(snapshot.todayUnits == 0)
        #expect(snapshot.last7Days.last?.units == 0)
        // The whole baseline of 20 is saved on a day the user says they smoked nothing.
        #expect(snapshot.weekReductionUnits == 20)
        #expect(snapshot.weekSavedMinor == 20000)
        #expect(snapshot.savedSinceSetupMinor == 20000)
    }

    @Test("under, at and over the limit: today's units are summed, the reduction floors at zero", arguments: [
        (units: Int64(8), reduction: Int64(12)),
        (units: Int64(10), reduction: Int64(10)),
        (units: Int64(14), reduction: Int64(6)),
        (units: Int64(25), reduction: Int64(0))
    ])
    func limitBoundaries(units: Int64, reduction: Int64) throws {
        // Two events the same day: they sum.
        let events = [
            Fixture.smoked("s1", at: Fixture.midnight(Fixture.day0 + 10) + 8 * hour, units: 4, attempt: nil),
            Fixture.smoked("s2", at: Fixture.midnight(Fixture.day0 + 10) + 10 * hour, units: units - 4, attempt: nil)
        ]
        let snapshot = try reduceSnapshot(Fixture.reduceInput(events: events), now: now)
        #expect(snapshot.todayUnits == units)
        #expect(snapshot.todayHasEntry == true)
        #expect(snapshot.weekReductionUnits == reduction)
    }

    @Test("first week: only today is logged, the six days before are no data")
    func firstWeek() throws {
        let setup = Fixture.midnight(Fixture.day0 + 10)
        let events = [Fixture.smoked("s1", at: setup + 9 * hour, units: 12, attempt: nil)]
        let snapshot = try reduceSnapshot(Fixture.reduceInput(createdAt: setup, events: events), now: now)
        #expect(snapshot.last7Days.count == 7)
        #expect(snapshot.last7Days.dropLast().allSatisfy { $0.units == nil })
        #expect(snapshot.last7Days.last == DayUnits(epochDay: Fixture.day0 + 10, units: 12))
        #expect(snapshot.weekReductionUnits == 8)
        #expect(snapshot.savedSinceSetupMinor == 8000)
    }

    @Test("saved since setup ignores a day logged before the setup day")
    func savedSinceSetupStartsAtSetup() throws {
        let setup = Fixture.midnight(Fixture.day0 + 10)
        let events = [
            Fixture.smoked("s0", at: Fixture.midnight(Fixture.day0 + 9) + 9 * hour, units: 5, attempt: nil),
            Fixture.smoked("s1", at: setup + 9 * hour, units: 12, attempt: nil)
        ]
        let snapshot = try reduceSnapshot(Fixture.reduceInput(createdAt: setup, events: events), now: now)
        #expect(snapshot.savedSinceSetupMinor == 8000)
        // The rolling week still shows it: 15 + 8.
        #expect(snapshot.weekReductionUnits == 23)
    }

    @Test("each day's reduction is priced at the price in force that day")
    func weekSavedUsesEachDaysPrice() throws {
        let prices = [Fixture.price(1000), Fixture.price(2000, from: Fixture.day0 + 9, id: "p2")]
        let events = [
            Fixture.smoked("s1", at: Fixture.midnight(Fixture.day0 + 8) + 9 * hour, units: 10, attempt: nil),
            Fixture.smoked("s2", at: Fixture.midnight(Fixture.day0 + 9) + 9 * hour, units: 15, attempt: nil)
        ]
        let snapshot = try reduceSnapshot(Fixture.reduceInput(prices: prices, events: events), now: now)
        // Day 8: 10 saved at 1 000. Day 9: 5 saved at 2 000.
        #expect(snapshot.weekSavedMinor == 10000 + 10000)
        #expect(snapshot.savedSinceSetupMinor == 20000)
    }

    @Test("a logged day outside the rolling week still counts since setup")
    func olderLoggedDaysCountSinceSetup() throws {
        let events = [Fixture.smoked("s1", at: Fixture.midnight(Fixture.day0 + 2) + 9 * hour, units: 10, attempt: nil)]
        let snapshot = try reduceSnapshot(Fixture.reduceInput(events: events), now: now)
        #expect(snapshot.weekReductionUnits == 0)
        #expect(snapshot.savedSinceSetupMinor == 10000)
    }

    @Test("cravings are counted all-time in REDUCE")
    func cravingsAllTime() throws {
        let events = [
            Fixture.craving("c1", at: Fixture.start + hour, attempt: nil),
            Fixture.craving("c2", at: Fixture.start + 2 * hour, attempt: "x")
        ]
        let snapshot = try reduceSnapshot(Fixture.reduceInput(events: events), now: now)
        #expect(snapshot.cravingsBeatenAllTime == 2)
    }
}

@Suite("SmokingStatsCalculator — goal (rule 14)")
struct GoalTests {
    @Test("QUIT mid-attempt: only money accrued after the goal counts, and only slips after it")
    func goalMidAttempt() throws {
        let before = Fixture.smoked("s0", at: Fixture.midnight(Fixture.day0 + 2) + 12 * hour, units: 1)
        let after = Fixture.smoked("s1", at: Fixture.midnight(Fixture.day0 + 7) + 12 * hour, units: 2)
        let goal = Fixture.goal(target: 300_000, createdAt: Fixture.midnight(Fixture.day0 + 4))
        let input = Fixture.quitInput(events: [before, after], goal: goal)
        let progress = try #require(try quitSnapshot(input, now: Fixture.start + 10 * day).goal)
        // Days 4 to 9 are 6 x 20 x 1 000, less the later slip's 2 x 1 000.
        #expect(progress.savedTowardMinor == 118_000)
        // 118 000 x 1 000 / 300 000.
        #expect(progress.permille == 393)
        #expect(progress.reached == false)
        #expect(progress.goal == goal)
    }

    @Test("QUIT across a restart: the closed and the new attempt both contribute")
    func goalAcrossARestart() throws {
        let restartAt = Fixture.midnight(Fixture.day0 + 5) + 12 * hour
        let a1 = Fixture.attempt("a1", start: Fixture.start, end: restartAt, reason: .restarted)
        let a2 = Fixture.attempt("a2", start: restartAt)
        let slip = Fixture.smoked("s1", at: restartAt, units: 1, attempt: "a1")
        let goal = Fixture.goal(target: 1_000_000, createdAt: Fixture.midnight(Fixture.day0 + 3))
        let input = Fixture.quitInput(attempts: [a1, a2], events: [slip], goal: goal)
        let snapshot = try quitSnapshot(input, now: Fixture.midnight(Fixture.day0 + 8) + 12 * hour)
        let progress = try #require(snapshot.goal)
        // a1 inside the goal window: 2.5 days x 20 x 1 000 = 50 000. a2: 3 days = 60 000.
        // The restart slip is inside the window: 1 x 1 000.
        #expect(progress.savedTowardMinor == 50000 + 60000 - 1000)
        #expect(progress.permille == 109)
        // The headline figure is the new attempt alone.
        #expect(snapshot.savedMinor == 60000)
    }

    @Test("QUIT: an attempt whose slips exceed its accrual contributes zero and never cancels another's savings")
    func goalFloorIsPerAttempt() throws {
        let restartAt = Fixture.start + 2 * day
        let a1 = Fixture.attempt("a1", start: Fixture.start, end: restartAt, reason: .restarted)
        let a2 = Fixture.attempt("a2", start: restartAt)
        let heavy = Fixture.smoked("s1", at: Fixture.start + day, units: 100, attempt: "a1")
        let goal = Fixture.goal(target: 1_000_000, createdAt: Fixture.start)
        let input = Fixture.quitInput(attempts: [a1, a2], events: [heavy], goal: goal)
        let progress = try #require(try quitSnapshot(input, now: restartAt + 2 * day).goal)
        // a1: 2 days = 40 000 less 100 000, floored to 0. a2: 2 days = 40 000, kept whole.
        #expect(progress.savedTowardMinor == 40000)
    }

    @Test("QUIT VAPE: a slip day is deducted once per attempt window")
    func goalVapeSlipDayIsPerAttempt() throws {
        let restartAt = Fixture.midnight(Fixture.day0 + 3) + 10 * hour
        let a1 = Fixture.attempt("a1", start: Fixture.start, end: restartAt, reason: .restarted)
        let a2 = Fixture.attempt("a2", start: restartAt)
        let events = [
            Fixture.smoked("s1", at: restartAt, attempt: "a1", product: .vape),
            Fixture.smoked("s2", at: restartAt + 5 * hour, attempt: "a2", product: .vape)
        ]
        let goal = Fixture.goal(target: 1_000_000, createdAt: Fixture.start)
        let input = Fixture.quitInput(
            baseline: 1,
            cost: 2000,
            product: .vape,
            attempts: [a1, a2],
            events: events,
            goal: goal
        )
        let progress = try #require(try quitSnapshot(input, now: Fixture.midnight(Fixture.day0 + 5)).goal)
        // a1: 3 days x 2 000 + 10 h x 2 000 / 24 h (833), less 2 000 = 4 833.
        // a2: 14 h x 2 000 / 24 h (1 166) + 2 000, less 2 000 for the same slip day = 1 166.
        #expect(progress.savedTowardMinor == 4833 + 1166)
    }

    @Test("a goal with a non-positive target shows zero progress")
    func goalWithoutATargetIsZeroProgress() throws {
        let goal = Fixture.goal(target: 0, createdAt: Fixture.start)
        let progress = try #require(try quitSnapshot(Fixture.quitInput(goal: goal), now: Fixture.start + day).goal)
        #expect(progress.permille == 0)
    }

    @Test("a goal created before nothing accrued is zero progress, not negative")
    func goalCreatedAfterNow() throws {
        let goal = Fixture.goal(target: 1000, createdAt: Fixture.start + 5 * day)
        let progress = try #require(try quitSnapshot(Fixture.quitInput(goal: goal), now: Fixture.start + day).goal)
        #expect(progress.savedTowardMinor == 0)
        #expect(progress.permille == 0)
    }

    @Test("progress is capped at 1000 permille and the goal is reached")
    func goalReachedAndCapped() throws {
        let goal = Fixture.goal(target: 10000, createdAt: Fixture.start)
        let progress = try #require(try quitSnapshot(Fixture.quitInput(goal: goal), now: Fixture.start + 2 * day).goal)
        // 40 000 saved against 10 000.
        #expect(progress.savedTowardMinor == 40000)
        #expect(progress.permille == 1000)
        #expect(progress.reached == true)
    }

    @Test("an achieved timestamp keeps the goal reached when the money fell back below target")
    func goalAchievedAtKeepsReached() throws {
        let goal = Fixture.goal(target: 1_000_000, createdAt: Fixture.start, achievedAt: Fixture.start + day)
        let progress = try #require(try quitSnapshot(Fixture.quitInput(goal: goal), now: Fixture.start + 2 * day).goal)
        #expect(progress.permille == 40)
        #expect(progress.reached == true)
    }

    @Test("REDUCE: logged days from the goal's day on, at that day's reduction and price")
    func reduceGoal() throws {
        let events = [
            Fixture.smoked("s1", at: Fixture.midnight(Fixture.day0 + 7) + 9 * hour, units: 0, attempt: nil),
            Fixture.smoked("s2", at: Fixture.midnight(Fixture.day0 + 8) + 9 * hour, units: 10, attempt: nil),
            Fixture.smoked("s3", at: Fixture.midnight(Fixture.day0 + 9) + 9 * hour, units: 15, attempt: nil)
        ]
        let goal = Fixture.goal(target: 40000, createdAt: Fixture.midnight(Fixture.day0 + 8) + 12 * hour)
        let input = Fixture.reduceInput(events: events, goal: goal)
        let snapshot = try reduceSnapshot(input, now: Fixture.midnight(Fixture.day0 + 10) + 12 * hour)
        let progress = try #require(snapshot.goal)
        // Day 7 is before the goal. Day 8: 10 saved, day 9: 5 saved, both at 1 000.
        #expect(progress.savedTowardMinor == 15000)
        #expect(progress.permille == 375)
        #expect(progress.reached == false)
    }

    @Test("no goal in the input means no goal progress")
    func noGoal() throws {
        #expect(try quitSnapshot(Fixture.quitInput(), now: Fixture.start + day).goal == nil)
    }
}

@Suite("HealthStage catalog")
struct HealthStageTests {
    @Test("ten stages, ids and thresholds exactly as smoking-health-stages.md")
    func catalogMatchesTheContract() {
        let expected: [(String, Int64)] = [
            ("h_20m", 20), ("h_12h", 720), ("h_48h", 2880), ("h_72h", 4320), ("h_2w", 20160),
            ("h_1mo", 43200), ("h_1y", 525_600), ("h_5y", 2_628_000), ("h_10y", 5_256_000),
            ("h_15y", 7_884_000)
        ]
        #expect(HealthStage.catalog.map(\.id) == expected.map(\.0))
        #expect(HealthStage.catalog.map(\.thresholdMinutes) == expected.map(\.1))
        #expect(HealthStage.catalog.map(\.thresholdMs) == expected.map { $0.1 * 60000 })
    }

    @Test("the dropped nine-month stage stays retired")
    func nineMonthStageIsRetired() {
        #expect(!HealthStage.catalog.map(\.id).contains("h_9mo"))
    }

    @Test("combustion-only flags: the 12 h and 48 h stages only")
    func combustionOnlyFlags() {
        let flagged = HealthStage.catalog.filter(\.combustionOnly).map(\.id)
        #expect(flagged == ["h_12h", "h_48h"])
    }
}
