import Foundation
import Testing

@testable import SalusSmoking

// One test per rule of `smoking-domain-contract.md` §3 (iOS-M17 plan, ruling P1: written from the
// contract text, not ported from Kotlin). Numbers are small enough to check by hand; the comment
// above each expectation shows the arithmetic.

private let day = Fixture.dayMs
private let hour = Fixture.hourMs

@Suite("SmokingStatsCalculator — NotSetUp (rule 1)")
struct NotSetUpTests {
    @Test("no plan is not set up")
    func noPlan() {
        let input = SmokingInput(plan: nil, prices: [], attempts: [], events: [], goal: nil)
        #expect(SmokingStatsCalculator.snapshot(input, nowMs: Fixture.start, zone: Fixture.istanbul) == .notSetUp)
    }

    @Test("a QUIT plan whose attempts are all closed is not set up")
    func quitWithoutActiveAttempt() {
        let closed = Fixture.attempt(end: Fixture.start + day, reason: .restarted)
        let input = Fixture.quitInput(attempts: [closed])
        #expect(SmokingStatsCalculator
            .snapshot(input, nowMs: Fixture.start + 2 * day, zone: Fixture.istanbul) == .notSetUp)
    }

    @Test("a REDUCE plan needs no attempt")
    func reduceNeedsNoAttempt() {
        let snapshot = SmokingStatsCalculator.snapshot(
            Fixture.reduceInput(),
            nowMs: Fixture.start,
            zone: Fixture.istanbul
        )
        guard case .reduce = snapshot else {
            Issue.record("expected a REDUCE snapshot, got \(snapshot)")
            return
        }
    }
}

@Suite("SmokingStatsCalculator — QUIT figures (rules 2 to 9)")
struct QuitFigureTests {
    @Test("day 0: the moment of the quit is all zeros with the first stage at zero progress")
    func dayZero() throws {
        let snapshot = try quitSnapshot(Fixture.quitInput(), now: Fixture.start)
        #expect(snapshot.attemptElapsedMs == 0)
        #expect(snapshot.sinceLastSmokeMs == 0)
        #expect(snapshot.unitsNotSmoked == 0)
        #expect(snapshot.unitsNotSmokedToday == 0)
        #expect(snapshot.savedMinor == 0)
        #expect(snapshot.timeRegainedMinutes == 0)
        #expect(snapshot.slipCount == 0)
        #expect(snapshot.nextStage?.stageId == "h_20m")
        #expect(snapshot.nextStage?.permille == 0)
    }

    @Test("day 42 and a half: units, money, minutes, today and the next stage")
    func dayFortyTwo() throws {
        let now = Fixture.start + 42 * day + 12 * hour
        let snapshot = try quitSnapshot(Fixture.quitInput(), now: now)
        #expect(snapshot.attemptElapsedMs == 42 * day + 12 * hour)
        // 42.5 days x 20 per day.
        #expect(snapshot.unitsNotSmoked == 850)
        // Noon to now is half of today: 12 h x 20 / 24 h.
        #expect(snapshot.unitsNotSmokedToday == 10)
        // 42 whole days x 20 x 1 000 plus half a day: 12 h x 20 x 1 000 / 24 h.
        #expect(snapshot.savedMinor == 840_000 + 10000)
        // 850 x 11 minutes.
        #expect(snapshot.timeRegainedMinutes == 9350)
        #expect(snapshot.sinceLastSmokeMs == 42 * day + 12 * hour)
        // 30 days is done, 365 days is next: 42.5 d x 1 000 / 365 d.
        #expect(snapshot.nextStage?.stageId == "h_1y")
        #expect(snapshot.nextStage?.permille == 116)
        #expect(snapshot.nextStage?.remainingMs == 365 * day - (42 * day + 12 * hour))
    }

    @Test("a slip is deducted at the price of the day it happened, not today's")
    func slipAtItsOwnDaysPrice() throws {
        let input = SmokingInput(
            plan: Fixture.plan(),
            prices: [Fixture.price(1000), Fixture.price(2000, from: Fixture.day0 + 5, id: "p2")],
            attempts: [Fixture.attempt()],
            events: [Fixture.smoked("s1", at: Fixture.midnight(Fixture.day0 + 2) + 12 * hour, units: 3)],
            goal: nil
        )
        let snapshot = try quitSnapshot(input, now: Fixture.start + 10 * day)
        // Days 0-4 at 1 000 and days 5-9 at 2 000: 100 000 + 200 000; the slip is 3 x 1 000, not 3 x 2 000.
        #expect(snapshot.savedMinor == 297_000)
        #expect(snapshot.unitsNotSmoked == 10 * 20 - 3)
        #expect(snapshot.slipCount == 1)
        // From the slip at day 2 noon to day 10.
        #expect(snapshot.sinceLastSmokeMs == 7 * day + 12 * hour)
    }

    @Test("a price change mid-attempt applies from its own day, never backwards")
    func priceChangeMidAttempt() throws {
        let input = SmokingInput(
            plan: Fixture.plan(),
            prices: [Fixture.price(1000), Fixture.price(1500, from: Fixture.day0 + 3, id: "p2")],
            attempts: [Fixture.attempt()],
            events: [],
            goal: nil
        )
        let snapshot = try quitSnapshot(input, now: Fixture.start + 6 * day)
        // 3 days x 20 x 1 000 plus 3 days x 20 x 1 500.
        #expect(snapshot.savedMinor == 60000 + 90000)
    }

    @Test("a day before the first price period is priced at the earliest period")
    func dayBeforeFirstPeriodUsesEarliest() throws {
        let input = SmokingInput(
            plan: Fixture.plan(),
            prices: [Fixture.price(1000, from: Fixture.day0 + 2)],
            attempts: [Fixture.attempt()],
            events: [],
            goal: nil
        )
        let snapshot = try quitSnapshot(input, now: Fixture.start + 4 * day)
        // Days 0 and 1 precede the only period and still cost 1 000: 4 x 20 x 1 000.
        #expect(snapshot.savedMinor == 80000)
    }

    @Test("VAPE: baseline 1, one deduction per distinct slip day, no minutes regained")
    func vape() throws {
        let events = [
            Fixture.smoked("s1", at: Fixture.midnight(Fixture.day0 + 3) + 9 * hour, product: .vape),
            Fixture.smoked("s2", at: Fixture.midnight(Fixture.day0 + 3) + 15 * hour, product: .vape),
            Fixture.smoked("s3", at: Fixture.midnight(Fixture.day0 + 5) + 9 * hour, product: .vape)
        ]
        let input = Fixture.quitInput(baseline: 1, cost: 2000, product: .vape, events: events)
        let snapshot = try quitSnapshot(input, now: Fixture.start + 10 * day)
        // 10 days x 1 x 2 000, less 2 000 for each of the two distinct slip days (3 slips).
        #expect(snapshot.savedMinor == 20000 - 4000)
        // 10 sessions not had, less the three slip units.
        #expect(snapshot.unitsNotSmoked == 7)
        #expect(snapshot.timeRegainedMinutes == nil)
        #expect(snapshot.slipCount == 3)
    }

    @Test("a device clock set behind the start clamps every figure to zero")
    func clockSetBack() throws {
        let attempt = Fixture.attempt(start: Fixture.midnight(Fixture.day0 + 1))
        let slip = Fixture.smoked("s1", at: Fixture.midnight(Fixture.day0 + 1) + hour)
        let snapshot = try quitSnapshot(Fixture.quitInput(attempts: [attempt], events: [slip]), now: Fixture.start)
        #expect(snapshot.attemptElapsedMs == 0)
        #expect(snapshot.sinceLastSmokeMs == 0)
        #expect(snapshot.unitsNotSmoked == 0)
        #expect(snapshot.unitsNotSmokedToday == 0)
        #expect(snapshot.savedMinor == 0)
        #expect(snapshot.timeRegainedMinutes == 0)
        #expect(snapshot.nextStage?.permille == 0)
        #expect(snapshot.nextStage?.remainingMs ?? -1 >= 0)
    }

    @Test("Europe/Berlin spring-forward day: durations are epoch differences, days bucket by the zone")
    func berlinDaylightSavingDay() throws {
        // 2026-03-29 is 23 hours long in Berlin; the second price applies from 30 March.
        let start: Int64 = 1_774_738_800_000 // 2026-03-29 00:00 CET
        let now = start + 35 * hour // 2026-03-30 12:00 CEST
        let input = SmokingInput(
            plan: Fixture.plan(baseline: 24, tz: "Europe/Berlin"),
            prices: [Fixture.price(1000, from: 20541), Fixture.price(2000, from: 20542, id: "p2")],
            attempts: [Fixture.attempt(start: start, tz: "Europe/Berlin")],
            events: [],
            goal: nil
        )
        let snapshot = try quitSnapshot(input, now: now, zone: Fixture.berlin)
        #expect(snapshot.attemptElapsedMs == 35 * hour)
        #expect(snapshot.unitsNotSmoked == 35)
        // 23 h x 24 x 1 000 / 24 h on the short day, then 12 h x 24 x 2 000 / 24 h.
        #expect(snapshot.savedMinor == 23000 + 24000)
        // Today is 30 March: midnight CEST to noon.
        #expect(snapshot.unitsNotSmokedToday == 12)
    }

    @Test("an event before the attempt started is not a slip")
    func backDatedEventIsNotASlip() throws {
        let attempt = Fixture.attempt("a1", start: Fixture.midnight(Fixture.day0 + 2))
        let backDated = Fixture.smoked("s1", at: Fixture.midnight(Fixture.day0 + 1), attempt: nil)
        // A stale `attemptId` does not make an event before the start a slip either.
        let staleLink = Fixture.smoked("s2", at: Fixture.midnight(Fixture.day0 + 1) + hour, attempt: "a1")
        let snapshot = try quitSnapshot(
            Fixture.quitInput(attempts: [attempt], events: [backDated, staleLink]),
            now: Fixture.midnight(Fixture.day0 + 3)
        )
        #expect(snapshot.slipCount == 0)
        #expect(snapshot.sinceLastSmokeMs == day)
        #expect(snapshot.unitsNotSmoked == 20)
        #expect(snapshot.savedMinor == 20000)
    }

    @Test("a none-today marker inside a back-dated quit window is not a slip (section 8.14)")
    func noneTodayMarkerInsideBackDatedWindowIsNotASlip() throws {
        // The marker (units 0, no attempt) was logged at 09:00 in REDUCE mode; the user then switched
        // to QUIT with a quit time of 00:00 that day, so its instant falls inside the new window and
        // the time-containment fallback must not attach it. 2 days: 2 x 20 = 40 units, 40 000 minor.
        let marker = Fixture.smoked("marker", at: Fixture.start + 9 * hour, units: 0, attempt: nil)
        let snapshot = try quitSnapshot(
            Fixture.quitInput(events: [marker]),
            now: Fixture.start + 2 * day
        )
        #expect(snapshot.slipCount == 0)
        #expect(snapshot.sinceLastSmokeMs == snapshot.attemptElapsedMs)
        #expect(snapshot.unitsNotSmoked == 40)
        #expect(snapshot.savedMinor == 40000)
        #expect(snapshot.attempts.first?.slipCount == 0)
    }

    @Test("a none-today marker never costs a VAPE slip day (section 8.14)")
    func noneTodayMarkerNeverCostsAVapeDay() throws {
        // Same scene with a vape: a counted marker would take one unit cost (2 000) off day 0.
        // 2 days x 1 x 2 000 = 4 000 minor, nothing deducted.
        let marker = Fixture.smoked(
            "marker", at: Fixture.start + 9 * hour, units: 0, attempt: nil, product: .vape
        )
        let snapshot = try quitSnapshot(
            Fixture.quitInput(baseline: 1, cost: 2000, product: .vape, events: [marker]),
            now: Fixture.start + 2 * day
        )
        #expect(snapshot.savedMinor == 4000)
        #expect(snapshot.slipCount == 0)
    }

    @Test("a slip larger than the units not smoked clamps units and money at zero")
    func slipLargerThanNotSmoked() throws {
        let slip = Fixture.smoked("s1", at: Fixture.start + 12 * hour, units: 100)
        let snapshot = try quitSnapshot(Fixture.quitInput(events: [slip]), now: Fixture.start + day)
        // 20 not smoked, 100 smoked; 20 000 saved, 100 000 deducted.
        #expect(snapshot.unitsNotSmoked == 0)
        #expect(snapshot.savedMinor == 0)
    }

    @Test("units not smoked uses 64-bit integer division, truncating")
    func unitsTruncate() throws {
        // 1.5 hours x 20 per day / 24 h = 1.25.
        let snapshot = try quitSnapshot(Fixture.quitInput(), now: Fixture.start + 90 * Fixture.minuteMs)
        #expect(snapshot.unitsNotSmoked == 1)
    }

    @Test("money is divided per day, so two half days do not add up to one whole")
    func moneyDividesPerDay() throws {
        let attempt = Fixture.attempt(start: Fixture.start + 12 * hour)
        let snapshot = try quitSnapshot(
            Fixture.quitInput(baseline: 3, cost: 1, attempts: [attempt]),
            now: Fixture.start + day + 12 * hour
        )
        // Each half day is 43 200 000 x 3 x 1 / 86 400 000 = 1.5, floored to 1 per day; as one
        // block it would be 3.
        #expect(snapshot.unitsNotSmoked == 3)
        #expect(snapshot.savedMinor == 2)
    }

    @Test("units not smoked today is today's overlap, less only today's slips, floored at zero")
    func unitsNotSmokedToday() throws {
        let now = Fixture.midnight(Fixture.day0 + 3) + 18 * hour
        let yesterday = Fixture.smoked("s0", at: Fixture.midnight(Fixture.day0 + 2) + 10 * hour, units: 5)
        let today = Fixture.smoked("s1", at: Fixture.midnight(Fixture.day0 + 3) + 9 * hour, units: 2)
        let input = Fixture.quitInput(baseline: 24, events: [yesterday, today])
        let snapshot = try quitSnapshot(input, now: now)
        // 18 h x 24 / 24 h = 18, less today's 2; yesterday's 5 do not count.
        #expect(snapshot.unitsNotSmokedToday == 16)

        let heavy = Fixture.smoked("s2", at: Fixture.midnight(Fixture.day0 + 3) + 10 * hour, units: 40)
        let floored = try quitSnapshot(Fixture.quitInput(baseline: 24, events: [today, heavy]), now: now)
        #expect(floored.unitsNotSmokedToday == 0)
    }

    @Test("since last smoke counts from the latest slip of the attempt")
    func sinceLastSmokeUsesLatestSlip() throws {
        let events = [
            Fixture.smoked("s2", at: Fixture.midnight(Fixture.day0 + 5)),
            Fixture.smoked("s1", at: Fixture.midnight(Fixture.day0 + 2))
        ]
        let snapshot = try quitSnapshot(Fixture.quitInput(events: events), now: Fixture.midnight(Fixture.day0 + 6))
        #expect(snapshot.sinceLastSmokeMs == day)
        #expect(snapshot.attemptElapsedMs == 6 * day)
    }

    @Test("20 years at 60 a day and 10 000 minor units a piece does not overflow")
    func twentyYears() throws {
        let now = Fixture.start + 7300 * day
        let snapshot = try quitSnapshot(Fixture.quitInput(baseline: 60, cost: 10000), now: now)
        #expect(snapshot.attemptElapsedMs == 630_720_000_000)
        #expect(snapshot.unitsNotSmoked == 438_000)
        // 7 300 days x 60 x 10 000 exceeds Int32 by a factor of two.
        #expect(snapshot.savedMinor == 4_380_000_000)
        #expect(snapshot.timeRegainedMinutes == 4_818_000)
        #expect(snapshot.nextStage == nil)
        #expect(snapshot.stages.allSatisfy { $0.state == .done })
    }
}

@Suite("SmokingStatsCalculator — stages (rule 10)")
struct StageTests {
    @Test("thirteen hours: two stages done, one in progress, the rest pending")
    func statesAfterThirteenHours() throws {
        let snapshot = try quitSnapshot(Fixture.quitInput(), now: Fixture.start + 13 * hour)
        let states = snapshot.stages.map(\.state)
        #expect(states == [.done, .done, .inProgress] + Array(repeating: .pending, count: 7))
        #expect(snapshot.stages.map(\.stageId).prefix(3) == ["h_20m", "h_12h", "h_48h"])
        // 13 h x 1 000 / 48 h.
        #expect(snapshot.stages[2].permille == 270)
        #expect(snapshot.stages[2].remainingMs == 35 * hour)
        #expect(snapshot.stages[0].permille == 1000)
        #expect(snapshot.stages[0].remainingMs == 0)
        #expect(snapshot.stages[3].permille == 0)
        #expect(snapshot.nextStage == snapshot.stages[2])
    }

    @Test("a stage is done exactly at its threshold")
    func doneExactlyAtThreshold() throws {
        let snapshot = try quitSnapshot(Fixture.quitInput(), now: Fixture.start + 20 * Fixture.minuteMs)
        #expect(snapshot.stages[0].state == .done)
        #expect(snapshot.stages[1].state == .inProgress)
        // 20 min x 1 000 / 720 min.
        #expect(snapshot.stages[1].permille == 27)
    }

    @Test("after a slip at day 100 the long stages are counting again, the short ones are not")
    func countingAgainAfterASlip() throws {
        let slipAt = Fixture.start + 100 * day
        let input = Fixture.quitInput(events: [Fixture.smoked("s1", at: slipAt)])
        let snapshot = try quitSnapshot(input, now: slipAt + hour)
        let byId = Dictionary(uniqueKeysWithValues: snapshot.stages.map { ($0.stageId, $0) })
        #expect(byId["h_20m"]?.state == .done)
        #expect(byId["h_12h"]?.state == .inProgress)
        // 60 min x 1 000 / 720 min.
        #expect(byId["h_12h"]?.permille == 83)
        // Longer than 72 h, not done, and the attempt itself has run that long.
        #expect(byId["h_2w"]?.countingAgain == true)
        #expect(byId["h_1mo"]?.countingAgain == true)
        // 72 h is not longer than 72 h.
        #expect(byId["h_72h"]?.countingAgain == false)
        #expect(byId["h_48h"]?.countingAgain == false)
        // The attempt is only 100 days old, so a year-long stage was never reached.
        #expect(byId["h_1y"]?.countingAgain == false)
        // A done stage is never "counting again".
        #expect(byId["h_20m"]?.countingAgain == false)
    }

    @Test("REDUCE previews every stage as pending at zero")
    func reducePreview() throws {
        let snapshot = try reduceSnapshot(Fixture.reduceInput(), now: Fixture.start + 12 * hour)
        #expect(snapshot.stagesPreview.count == HealthStage.catalog.count)
        #expect(snapshot.stagesPreview.allSatisfy { $0.state == .pending && $0.permille == 0 && !$0.countingAgain })
    }
}

@Suite("SmokingStatsCalculator — cravings and attempts (rules 11 and 15)")
struct CravingAndAttemptTests {
    @Test("cravings beaten counts the active attempt, all-time counts every one")
    func cravingCounts() throws {
        let closed = Fixture.attempt("a0", start: Fixture.start - 5 * day, end: Fixture.start, reason: .restarted)
        let events = [
            Fixture.craving("c1", at: Fixture.start + hour, attempt: "a1"),
            Fixture.craving("c2", at: Fixture.start + 2 * hour, attempt: "a1"),
            Fixture.craving("c3", at: Fixture.start - day, attempt: "a0"),
            Fixture.craving("c4", at: Fixture.start - 10 * day, attempt: nil)
        ]
        let snapshot = try quitSnapshot(
            Fixture.quitInput(attempts: [Fixture.attempt(), closed], events: events),
            now: Fixture.start + day
        )
        #expect(snapshot.cravingsBeaten == 2)
        #expect(snapshot.cravingsBeatenAllTime == 4)
    }

    @Test("attempts are ordinal by start, the triggering slip stays on the closed attempt")
    func attemptHistory() throws {
        let a1 = Fixture.attempt(
            "a1",
            start: Fixture.start,
            end: Fixture.midnight(Fixture.day0 + 6) + 12 * hour,
            reason: .restarted
        )
        let a2 = Fixture.attempt(
            "a2",
            start: Fixture.midnight(Fixture.day0 + 6) + 12 * hour,
            end: Fixture.midnight(Fixture.day0 + 8) + 12 * hour,
            reason: .restarted
        )
        let a3 = Fixture.attempt("a3", start: Fixture.midnight(Fixture.day0 + 8) + 12 * hour)
        // The restart slip sits exactly on the instant a1 closes and a2 opens.
        let slip = Fixture.smoked("s1", at: Fixture.midnight(Fixture.day0 + 6) + 12 * hour, units: 2, attempt: "a1")
        let craving = Fixture.craving("c1", at: Fixture.midnight(Fixture.day0 + 9), attempt: "a3")
        // Deliberately out of order: the calculator sorts.
        let input = Fixture.quitInput(attempts: [a3, a1, a2], events: [slip, craving])
        let snapshot = try quitSnapshot(input, now: Fixture.midnight(Fixture.day0 + 10) + 12 * hour)

        #expect(snapshot.attempts.map(\.id) == ["a1", "a2", "a3"])
        #expect(snapshot.attempts.map(\.ordinal) == [1, 2, 3])
        #expect(snapshot.attempts.map(\.durationMs) == [6 * day + 12 * hour, 2 * day, 2 * day])
        #expect(snapshot.attempts.map(\.isLongest) == [true, false, false])
        #expect(snapshot.attempts.map(\.slipCount) == [1, 0, 0])
        // a1: 6.5 days x 20 x 1 000, less 2 x 1 000; a2 and a3: 2 days each.
        #expect(snapshot.attempts.map(\.savedMinor) == [128_000, 40000, 40000])
        #expect(snapshot.attempts.map(\.cravingsBeaten) == [0, 0, 1])
        #expect(snapshot.attempts[0].endedAtMs == a1.endedAtMs)
        #expect(snapshot.attempts[2].endedAtMs == nil)

        #expect(snapshot.attemptId == "a3")
        #expect(snapshot.slipCount == 0)
        #expect(snapshot.sinceLastSmokeMs == 2 * day)
    }

    @Test("on a tie for the longest attempt the earliest wins")
    func longestTieGoesToTheEarliest() throws {
        let a1 = Fixture.attempt("a1", start: Fixture.start, end: Fixture.start + 2 * day, reason: .restarted)
        let a2 = Fixture.attempt("a2", start: Fixture.start + 2 * day, end: Fixture.start + 4 * day, reason: .restarted)
        let a3 = Fixture.attempt("a3", start: Fixture.start + 4 * day)
        let snapshot = try quitSnapshot(
            Fixture.quitInput(attempts: [a1, a2, a3]),
            now: Fixture.start + 5 * day
        )
        #expect(snapshot.attempts.map(\.isLongest) == [true, false, false])
    }
}

@Suite("SmokingStatsCalculator — event ownership (rule 3, contract section 8.1)")
struct EventOwnershipTests {
    @Test("an event with no attemptId inside the active attempt is a slip of it")
    func unlinkedSlipInsideTheActiveAttempt() throws {
        let unlinked = Fixture.smoked("s1", at: Fixture.start + 12 * hour, attempt: nil)
        let snapshot = try quitSnapshot(Fixture.quitInput(events: [unlinked]), now: Fixture.start + day)
        #expect(snapshot.slipCount == 1)
        #expect(snapshot.sinceLastSmokeMs == 12 * hour)
        #expect(snapshot.unitsNotSmoked == 19)
    }

    @Test("an attemptId that names no attempt falls back to time containment")
    func unknownAttemptIdFallsBackToContainment() throws {
        let ghost = Fixture.smoked("s1", at: Fixture.start + 12 * hour, attempt: "ghost")
        let snapshot = try quitSnapshot(Fixture.quitInput(events: [ghost]), now: Fixture.start + day)
        #expect(snapshot.slipCount == 1)
    }

    @Test("an unlinked event on a closed attempt's end instant belongs to the attempt that starts there")
    func unlinkedEventAtTheRestartInstantGoesToTheNewAttempt() throws {
        let restartAt = Fixture.start + 2 * day
        let a1 = Fixture.attempt("a1", start: Fixture.start, end: restartAt, reason: .restarted)
        let a2 = Fixture.attempt("a2", start: restartAt)
        let unlinked = Fixture.smoked("s1", at: restartAt, attempt: nil)
        let snapshot = try quitSnapshot(
            Fixture.quitInput(attempts: [a1, a2], events: [unlinked]),
            now: restartAt + day
        )
        #expect(snapshot.attempts.map(\.slipCount) == [0, 1])
        #expect(snapshot.slipCount == 1)
    }

    @Test("an unlinked event inside a closed attempt belongs to it, not to the active one")
    func unlinkedEventInsideAClosedAttempt() throws {
        let a1 = Fixture.attempt("a1", start: Fixture.start, end: Fixture.start + 2 * day, reason: .restarted)
        let a2 = Fixture.attempt("a2", start: Fixture.start + 2 * day)
        let unlinked = Fixture.smoked("s1", at: Fixture.start + day, attempt: nil)
        let snapshot = try quitSnapshot(
            Fixture.quitInput(attempts: [a1, a2], events: [unlinked]),
            now: Fixture.start + 3 * day
        )
        #expect(snapshot.attempts.map(\.slipCount) == [1, 0])
        #expect(snapshot.slipCount == 0)
    }

    @Test("an unlinked event on the end instant of a closed attempt with no successor there belongs to nobody")
    func unlinkedEventAtAnEndInstantWithoutSuccessor() throws {
        let a1 = Fixture.attempt("a1", start: Fixture.start, end: Fixture.start + day, reason: .restarted)
        let a2 = Fixture.attempt("a2", start: Fixture.start + 3 * day)
        let gap = Fixture.smoked("s1", at: Fixture.start + day, attempt: nil)
        let snapshot = try quitSnapshot(
            Fixture.quitInput(attempts: [a1, a2], events: [gap]),
            now: Fixture.start + 4 * day
        )
        #expect(snapshot.attempts.map(\.slipCount) == [0, 0])
    }

    @Test("when two attempts contain an unlinked event the latest-starting one owns it")
    func latestStartingAttemptWinsContainment() throws {
        let a1 = Fixture.attempt("a1", start: Fixture.start)
        let a2 = Fixture.attempt("a2", start: Fixture.start + day)
        let unlinked = Fixture.smoked("s1", at: Fixture.start + 2 * day, attempt: nil)
        let snapshot = try quitSnapshot(
            Fixture.quitInput(attempts: [a1, a2], events: [unlinked]),
            now: Fixture.start + 3 * day
        )
        #expect(snapshot.attempts.map(\.slipCount) == [0, 1])
    }

    @Test("an unlinked craving inside the active attempt counts for it")
    func unlinkedCraving() throws {
        let craving = Fixture.craving("c1", at: Fixture.start + hour, attempt: nil)
        let snapshot = try quitSnapshot(Fixture.quitInput(events: [craving]), now: Fixture.start + day)
        #expect(snapshot.cravingsBeaten == 1)
        #expect(snapshot.attempts.map(\.cravingsBeaten) == [1])
    }
}
