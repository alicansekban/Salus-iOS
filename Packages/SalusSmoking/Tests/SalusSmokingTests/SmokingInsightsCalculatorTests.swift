import Foundation
import Testing
@testable import SalusSmoking

// Written from the numbered rules of contract section 5 and the insights readings of section 8.7,
// not ported from the Kotlin tests (planner ruling P1). Day 20 040 is "today"; with the default
// 30-day window the window is days 20 011 ... 20 040. Europe/Istanbul is UTC+3 all year.

private let today: Int64 = 20040
private let now: Int64 = Fixture.midnight(today) + 12 * Fixture.hourMs

/// An event on local `day` (Istanbul) at `hour:minute`, in the Istanbul zone unless told otherwise.
private func event(
    _ id: String,
    day: Int64,
    hour: Int64 = 12,
    minute: Int64 = 0,
    type: SmokingEventType = .smoked,
    units: Int64? = 1,
    trigger: CravingTrigger? = nil,
    at instant: Int64? = nil,
    tz: String = "Europe/Istanbul"
) -> SmokingEvent {
    SmokingEvent(
        id: id,
        type: type,
        occurredAtMs: instant ?? Fixture.midnight(day) + hour * Fixture.hourMs + minute * Fixture.minuteMs,
        tzId: tz,
        epochDay: day,
        units: type == .cravingResisted ? nil : units,
        trigger: trigger,
        intensity: nil,
        productType: .cigarette,
        attemptId: "a1"
    )
}

private func insights(_ input: SmokingInput, window: Int = 30) -> SmokingInsights {
    SmokingInsightsCalculator.insights(input, nowMs: now, zone: Fixture.istanbul, windowDays: window)
}

private func quit(_ events: [SmokingEvent]) -> SmokingInput {
    Fixture.quitInput(events: events)
}

private func reduce(_ events: [SmokingEvent]) -> SmokingInput {
    Fixture.reduceInput(events: events)
}

private func row(_ band: HourBand) -> Int {
    HourBand.allCases.firstIndex(of: band) ?? -1
}

@Suite("SmokingInsightsCalculator: availability")
struct SmokingInsightsAvailabilityTests {
    @Test("no plan: empty insights, a 7x7 zero heatmap, not enough data")
    func notSetUp() {
        let result = insights(SmokingInput(plan: nil, prices: [], attempts: [], events: [], goal: nil))
        #expect(!result.hasEnoughData)
        #expect(result.triggers.isEmpty)
        #expect(result.heatmap == Array(repeating: Array(repeating: 0, count: 7), count: 7))
        #expect(result.busiestBand == nil)
        #expect(result.busiestBandPermille == 0)
        #expect(result.reductionWeekly.isEmpty)
        #expect(result.attemptDurations.isEmpty)
        #expect(result.quitMarkerEpochDays.isEmpty)
    }

    @Test("six distinct days is not enough, seven is")
    func sevenDayThreshold() {
        let six = (0 ..< 6).map { event("e\($0)", day: today - Int64($0)) }
        #expect(!insights(quit(six)).hasEnoughData)
        let seven = (0 ..< 7).map { event("e\($0)", day: today - Int64($0)) }
        #expect(insights(quit(seven)).hasEnoughData)
    }

    @Test("many events on six days still count six days")
    func distinctDaysNotEvents() {
        let events = (0 ..< 20).map { event("e\($0)", day: today - Int64($0 % 6), hour: Int64(8 + $0 % 10)) }
        #expect(!insights(quit(events)).hasEnoughData)
    }

    @Test("an event outside the window does not count toward the days")
    func windowEdges() {
        let six = (0 ..< 6).map { event("e\($0)", day: today - Int64($0)) }
        // The 31st day back is outside a 30-day window, the 30th is inside.
        #expect(!insights(quit(six + [event("old", day: today - 30)])).hasEnoughData)
        #expect(insights(quit(six + [event("edge", day: today - 29)])).hasEnoughData)
    }

    @Test("the window length is a parameter")
    func windowDaysParameter() {
        let events = (0 ..< 7).map { event("e\($0)", day: today - Int64($0)) }
        #expect(insights(quit(events), window: 7).hasEnoughData)
        #expect(!insights(quit(events), window: 6).hasEnoughData)
    }

    @Test("a zero-unit marker counts as a logged day")
    func markerCountsAsDay() {
        var events = (0 ..< 6).map { event("e\($0)", day: today - Int64($0)) }
        events.append(event("marker", day: today - 6, units: 0))
        #expect(insights(reduce(events)).hasEnoughData)
    }

    @Test("a craving counts as a day too")
    func cravingCountsAsDay() {
        var events = (0 ..< 6).map { event("e\($0)", day: today - Int64($0)) }
        events.append(event("c", day: today - 6, type: .cravingResisted))
        #expect(insights(quit(events)).hasEnoughData)
    }
}

@Suite("SmokingInsightsCalculator: heatmap")
struct SmokingInsightsHeatmapTests {
    @Test("22:30 lands in the h22_08 row")
    func lateEvening() {
        let result = insights(quit([event("e", day: today, hour: 22, minute: 30)]))
        #expect(result.heatmap[row(.h22_08)].reduce(0, +) == 1)
        #expect(result.busiestBand == .h22_08)
    }

    @Test("band boundaries", arguments: [
        (0, HourBand.h22_08), (7, .h22_08), (8, .h08_10), (9, .h08_10), (10, .h10_12), (11, .h10_12),
        (12, .h12_14), (13, .h12_14), (14, .h14_16), (15, .h14_16), (16, .h16_18), (17, .h16_18),
        (18, .h18_22), (21, .h18_22), (22, .h22_08), (23, .h22_08)
    ] as [(Int, HourBand)])
    func bands(hour: Int, band: HourBand) {
        let result = insights(quit([event("e", day: today, hour: Int64(hour))]))
        #expect(result.heatmap[row(band)].reduce(0, +) == 1)
        #expect(result.heatmap.flatMap(\.self).reduce(0, +) == 1)
    }

    @Test("07:59 is still the night band and 08:00 is not")
    func minuteBoundary() {
        let result = insights(quit([
            event("a", day: today, hour: 7, minute: 59),
            event("b", day: today, hour: 8, minute: 0)
        ]))
        #expect(result.heatmap[row(.h22_08)].reduce(0, +) == 1)
        #expect(result.heatmap[row(.h08_10)].reduce(0, +) == 1)
    }

    @Test("columns are ISO weekdays, Monday first")
    func weekdayColumns() {
        // Day 20 000 is Friday 2024-10-04, so 20 028 is a Friday, 20 030 a Sunday, 20 031 a Monday.
        let result = insights(quit([
            event("fri", day: 20028),
            event("mon", day: 20031),
            event("sun", day: 20030)
        ]))
        let band = result.heatmap[row(.h12_14)]
        #expect(band == [1, 0, 0, 0, 1, 0, 1])
    }

    @Test("the hour is read in the event's own zone, not the device zone")
    func ownZone() {
        // 19:30 UTC is 20:30 in Berlin in November (h18_22) but 22:30 in Istanbul (h22_08).
        let utc1930 = Fixture.midnight(today) + 22 * Fixture.hourMs + 30 * Fixture.minuteMs
        let result = insights(quit([event("b", day: today, at: utc1930, tz: "Europe/Berlin")]))
        #expect(result.heatmap[row(.h18_22)].reduce(0, +) == 1)
        #expect(result.heatmap[row(.h22_08)].reduce(0, +) == 0)
    }

    @Test("an unparsable tzId falls back to the zone argument")
    func unparsableZone() {
        let utc1930 = Fixture.midnight(today) + 22 * Fixture.hourMs + 30 * Fixture.minuteMs
        let result = insights(quit([event("o", day: today, at: utc1930, tz: "Not/AZone")]))
        #expect(result.heatmap[row(.h22_08)].reduce(0, +) == 1)
    }

    @Test("cravings count in the heatmap")
    func cravingsCount() {
        let result = insights(quit([event("c", day: today, hour: 9, type: .cravingResisted)]))
        #expect(result.heatmap[row(.h08_10)].reduce(0, +) == 1)
    }

    @Test("a zero-unit marker is not an occurrence")
    func markerExcluded() {
        let result = insights(reduce([event("m", day: today, hour: 9, units: 0)]))
        #expect(result.heatmap.flatMap(\.self).reduce(0, +) == 0)
        #expect(result.busiestBand == nil)
        #expect(result.busiestBandPermille == 0)
    }

    @Test("busiest band is the row with most events and its permille is floored")
    func busiest() {
        let result = insights(quit([
            event("a", day: today, hour: 9), event("b", day: today - 1, hour: 9),
            event("c", day: today, hour: 13)
        ]))
        #expect(result.busiestBand == .h08_10)
        #expect(result.busiestBandPermille == 666)
    }

    @Test("a tie goes to the earlier row")
    func busiestTie() {
        let result = insights(quit([event("late", day: today, hour: 19), event("early", day: today, hour: 11)]))
        #expect(result.busiestBand == .h10_12)
        #expect(result.busiestBandPermille == 500)
    }

    @Test("events outside the window stay out of the heatmap")
    func outsideWindow() {
        let result = insights(quit([event("old", day: today - 30), event("new", day: today)]))
        #expect(result.heatmap.flatMap(\.self).reduce(0, +) == 1)
    }
}

@Suite("SmokingInsightsCalculator: triggers")
struct SmokingInsightsTriggerTests {
    @Test("permille is relative to events that carry a trigger and is floored")
    func permille() {
        let result = insights(quit([
            event("a", day: today, trigger: .coffee), event("b", day: today - 1, trigger: .coffee),
            event("c", day: today - 2, trigger: .stress),
            event("none", day: today - 3)
        ]))
        #expect(result.triggers == [
            TriggerShare(trigger: .coffee, count: 2, permille: 666),
            TriggerShare(trigger: .stress, count: 1, permille: 333)
        ])
    }

    @Test("equal counts are ordered by enum declaration")
    func tieOrder() {
        let result = insights(quit([
            event("a", day: today, trigger: .social), event("b", day: today, trigger: .stress),
            event("c", day: today, trigger: .coffee)
        ]))
        #expect(result.triggers.map(\.trigger) == [.coffee, .stress, .social])
    }

    @Test("cravings with a trigger count, a zero-unit marker does not")
    func cravingsAndMarker() {
        let result = insights(reduce([
            event("c", day: today, type: .cravingResisted, trigger: .boredom),
            event("m", day: today - 1, units: 0, trigger: .alcohol)
        ]))
        #expect(result.triggers == [TriggerShare(trigger: .boredom, count: 1, permille: 1000)])
    }

    @Test("no triggers means an empty list")
    func none() {
        #expect(insights(quit([event("a", day: today)])).triggers.isEmpty)
    }
}

@Suite("SmokingInsightsCalculator: reduction, attempts and markers")
struct SmokingInsightsHistoryTests {
    // Setup day is 20 000 (Fixture.reduceInput's createdAt); buckets are 20 000-20 006, 20 007-20 013 ...

    @Test("weekly buckets average the logged days and round down")
    func weeklyAverage() {
        let result = insights(reduce([
            event("a", day: 20000, units: 10), event("b", day: 20001, units: 5), // bucket 0: 15 / 2 = 7
            event("c", day: 20007, units: 8) // bucket 1: 8
        ]))
        #expect(result.reductionWeekly == [7, 8])
    }

    @Test("a bucket with no logged day is nil, never 0, and the list ends at the last bucket with data")
    func weeklyGap() {
        let result = insights(reduce([event("a", day: 20000, units: 4), event("z", day: 20015, units: 2)]))
        #expect(result.reductionWeekly == [4, nil, 2])
    }

    @Test("several events on one day are summed before averaging")
    func weeklySumsPerDay() {
        let result = insights(reduce([
            event("a", day: 20000, units: 3), event("b", day: 20000, units: 3), event("c", day: 20001, units: 2)
        ]))
        #expect(result.reductionWeekly == [4]) // days: 6 and 2 -> 8 / 2
    }

    @Test("the zero-unit marker is a logged day with 0 units")
    func weeklyMarker() {
        let result = insights(reduce([event("m", day: 20000, units: 0), event("a", day: 20001, units: 5)]))
        #expect(result.reductionWeekly == [2]) // 5 / 2 rounded down
    }

    @Test("days before setup and cravings are ignored; the day after the bucket edge starts a new bucket")
    func weeklyEdges() {
        let result = insights(reduce([
            event("pre", day: 19999, units: 9), event("c", day: 20000, type: .cravingResisted),
            event("last", day: 20006, units: 6), event("next", day: 20007, units: 1)
        ]))
        #expect(result.reductionWeekly == [6, 1])
    }

    @Test("weekly buckets read the whole history, not only the window")
    func weeklyNotWindowed() {
        #expect(insights(reduce([event("a", day: 20000, units: 4)])).reductionWeekly == [4])
    }

    @Test("QUIT has no weekly series")
    func weeklyQuit() {
        #expect(insights(quit([event("a", day: 20000, units: 4)])).reductionWeekly.isEmpty)
    }

    @Test("a REDUCE plan with no events has an empty series")
    func weeklyEmpty() {
        #expect(insights(reduce([])).reductionWeekly.isEmpty)
    }

    @Test("durations are in ordinal order; closed is end minus start, active runs to now")
    func attemptDurations() {
        let first = Fixture.attempt(
            "a1",
            start: Fixture.midnight(20000),
            end: Fixture.midnight(20010),
            reason: .restarted
        )
        let second = Fixture.attempt("a2", start: Fixture.midnight(20010))
        // Stored out of order on purpose.
        let input = Fixture.quitInput(attempts: [second, first])
        let result = insights(input)
        #expect(result.attemptDurations == [
            AttemptDuration(attemptId: "a1", durationMs: 10 * Fixture.dayMs),
            AttemptDuration(attemptId: "a2", durationMs: now - Fixture.midnight(20010))
        ])
    }

    @Test("a device clock behind the start clamps the duration to 0")
    func durationClamp() {
        let future = Fixture.attempt("a1", start: now + Fixture.dayMs)
        #expect(insights(Fixture.quitInput(attempts: [future])).attemptDurations.first?.durationMs == 0)
    }

    @Test("quit markers are the local epochDay of every attempt start")
    func quitMarkers() {
        // 23:30 Istanbul on day 20 004 is 20:30 UTC the same day; 00:30 Istanbul on 20 010 is the
        // previous UTC day, so only a zone-aware conversion gives 20 010.
        let first = Fixture.attempt(
            "a1",
            start: Fixture.midnight(20004) + 23 * Fixture.hourMs + 30 * Fixture.minuteMs,
            end: Fixture.midnight(20010) + 30 * Fixture.minuteMs,
            reason: .restarted
        )
        let second = Fixture.attempt("a2", start: Fixture.midnight(20010) + 30 * Fixture.minuteMs)
        let result = insights(Fixture.quitInput(attempts: [second, first]))
        #expect(result.quitMarkerEpochDays == [20004, 20010])
    }
}

@Suite("SmokingInsightsCalculator: aiStats")
struct SmokingAiStatsTests {
    private func stats(
        _ input: SmokingInput,
        from: Int64 = 20000,
        to: Int64 = today
    ) -> SmokingAiStats? {
        SmokingInsightsCalculator.aiStats(input, fromEpochDay: from, toEpochDay: to, zone: Fixture.istanbul)
    }

    @Test("nil when not set up")
    func notSetUp() {
        #expect(stats(SmokingInput(plan: nil, prices: [], attempts: [], events: [], goal: nil)) == nil)
    }

    @Test("QUIT carries the mode, no reduction percent, and counts slips")
    func quitStats() throws {
        let result = try #require(stats(quit([
            event("a", day: today), event("b", day: today - 1), event("c", day: today - 2, type: .cravingResisted)
        ])))
        #expect(result.mode == .quit)
        #expect(result.slipCount == 2)
        #expect(result.reductionPercent == nil)
    }

    @Test("daysTracked is the inclusive range, clamped to the setup day")
    func daysTracked() throws {
        #expect(try #require(stats(quit([]), from: 20030, to: 20039)).daysTracked == 10)
        #expect(try #require(stats(quit([]), from: 19000, to: 20009)).daysTracked == 10) // setup day 20 000
        #expect(try #require(stats(quit([]), from: 20010, to: 20005)).daysTracked == 0)
    }

    @Test("events before the setup day or outside the range feed nothing")
    func rangeAndSetup() throws {
        let events = [
            event("pre", day: 19999, trigger: .coffee),
            event("in", day: 20005, trigger: .stress),
            event("after", day: 20020, trigger: .alcohol)
        ]
        let result = try #require(stats(quit(events), from: 19990, to: 20010))
        #expect(result.slipCount == 1)
        #expect(result.topTriggers.map(\.trigger) == [.stress])
    }

    @Test("a zero-unit marker is not a slip and not a trigger")
    func markerNotSlip() throws {
        let result = try #require(stats(reduce([
            event("m", day: today, hour: 9, units: 0, trigger: .coffee), event("a", day: today - 1, hour: 19)
        ])))
        #expect(result.slipCount == 1)
        #expect(result.topTriggers.isEmpty)
        #expect(result.busiestBand == .h18_22)
    }

    @Test("top triggers are limited to three, biggest first")
    func topThree() throws {
        let result = try #require(stats(quit([
            event("1", day: today, trigger: .coffee), event("2", day: today, trigger: .coffee),
            event("3", day: today, trigger: .coffee), event("4", day: today, trigger: .stress),
            event("5", day: today, trigger: .stress), event("6", day: today, trigger: .social),
            event("7", day: today, trigger: .boredom)
        ])))
        // social (declared before boredom) wins the one-event tie for the third place.
        #expect(result.topTriggers.map(\.trigger) == [.coffee, .stress, .social])
        #expect(result.topTriggers.count == 3)
        #expect(result.topTriggers[0].permille == 428) // 3 of 7
    }

    @Test("busiest band is nil without occurrences")
    func noBusiest() throws {
        #expect(try #require(stats(quit([]))).busiestBand == nil)
    }

    @Test("reduction percent is a single integer division over the logged days")
    func reductionPercent() throws {
        // Baseline 20; logged days with 10 and 6 units: 100 - 16*100/(2*20) = 60.
        let exact = try #require(stats(reduce([event("a", day: 20001, units: 10), event("b", day: 20002, units: 6)])))
        #expect(exact.reductionPercent == 60)
        // 15 units over 2 days: 1500/40 = 37 (floored) -> 63.
        let floored = try #require(stats(reduce([event("a", day: 20001, units: 10), event("b", day: 20002, units: 5)])))
        #expect(floored.reductionPercent == 63)
    }

    @Test("reduction percent is not clamped when the person smoked above baseline")
    func reductionNegative() throws {
        let result = try #require(stats(reduce([event("a", day: 20001, units: 30)])))
        #expect(result.reductionPercent == -50)
    }

    @Test("a zero-unit marker day lowers the average")
    func reductionMarker() throws {
        let result = try #require(stats(reduce([event("m", day: 20001, units: 0), event("a", day: 20002, units: 10)])))
        #expect(result.reductionPercent == 75) // 100 - 10*100/40
    }

    @Test("REDUCE with no logged day has no reduction percent")
    func reductionNoData() throws {
        #expect(try #require(stats(reduce([]))).reductionPercent == nil)
    }

    @Test("the field set is pinned: nothing about the reason, instants or money")
    func fieldSetPinned() throws {
        let result = try #require(stats(quit([])))
        let labels = Mirror(reflecting: result).children.compactMap(\.label)
        #expect(labels == ["mode", "daysTracked", "slipCount", "topTriggers", "busiestBand", "reductionPercent"])
    }
}
