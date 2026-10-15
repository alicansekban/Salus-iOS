import Foundation
import Testing
@testable import SalusSmoking

// Edge rows of `SmokingInsightsCalculator` (contract section 5 / 8.7) kept apart from
// `SmokingInsightsCalculatorTests` to stay inside the file-length rule. Day 20 040 is "today";
// Europe/Istanbul is UTC+3 all year.

private let today: Int64 = 20040
private let now: Int64 = Fixture.midnight(today) + 12 * Fixture.hourMs

private func event(
    _ id: String,
    day: Int64,
    hour: Int64 = 12,
    units: Int64? = 1,
    trigger: CravingTrigger? = nil
) -> SmokingEvent {
    SmokingEvent(
        id: id,
        type: .smoked,
        occurredAtMs: Fixture.midnight(day) + hour * Fixture.hourMs,
        tzId: "Europe/Istanbul",
        epochDay: day,
        units: units,
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

@Suite("SmokingInsightsCalculator: window and ordering edges")
struct SmokingInsightsEdgeTests {
    @Test("a window shorter than one day is one day: only today is looked at")
    func windowBelowOneDay() {
        let events = [
            event("t", day: today, trigger: .stress),
            event("y", day: today - 1, trigger: .social)
        ]
        let one = insights(quit(events), window: 1)
        #expect(one.triggers.map(\.trigger) == [.stress])
        for window in [0, -5] {
            #expect(insights(quit(events), window: window) == one, "window \(window)")
        }
    }

    @Test("an event on the day after today is outside the window")
    func upperWindowEdge() {
        let six = (0 ..< 6).map { event("e\($0)", day: today - Int64($0)) }
        // Today + 1 is a future-dated entry (a clock set back, an import): not a seventh day, and
        // not an occurrence.
        let withTomorrow = insights(quit(six + [event("future", day: today + 1, trigger: .stress)]))
        #expect(!withTomorrow.hasEnoughData)
        #expect(withTomorrow.triggers.isEmpty)
        #expect(withTomorrow.heatmap.flatMap(\.self).reduce(0, +) == 6)
        #expect(insights(quit(six + [event("today-again", day: today, hour: 9)])).heatmap.flatMap(\.self)
            .reduce(0, +) == 7)
    }

    @Test("attempts that start at the same instant keep their stored order")
    func equalStartsKeepTheirOrder() {
        let start = Fixture.midnight(20010)
        let closed = Fixture.attempt("b", start: start, end: start + Fixture.dayMs, reason: .restarted)
        let active = Fixture.attempt("a", start: start)
        // Neither the id nor the end decides: the order the rows came in does.
        let closedFirst = insights(Fixture.quitInput(attempts: [closed, active]))
        let activeFirst = insights(Fixture.quitInput(attempts: [active, closed]))
        #expect(closedFirst.attemptDurations.map(\.attemptId) == ["b", "a"])
        #expect(activeFirst.attemptDurations.map(\.attemptId) == ["a", "b"])
        #expect(activeFirst.quitMarkerEpochDays == [20010, 20010])
    }
}

@Suite("SmokingInsightsCalculator: reduction percent guards")
struct SmokingReductionPercentGuardTests {
    private func stats(_ input: SmokingInput) -> SmokingAiStats? {
        SmokingInsightsCalculator.aiStats(input, fromEpochDay: 20000, toEpochDay: today, zone: Fixture.istanbul)
    }

    @Test("no baseline means no reduction percent")
    func reductionNoBaseline() throws {
        for baseline in [Int64(0), -3] {
            let input = SmokingInput(
                plan: Fixture.plan(mode: .reduce, baseline: baseline, limit: 10),
                prices: [Fixture.price(1000)],
                attempts: [],
                events: [event("a", day: 20001, units: 5)],
                goal: nil
            )
            #expect(try #require(stats(input)).reductionPercent == nil, "baseline \(baseline)")
        }
    }

    @Test("a percent that cannot be computed without overflow is nil, not a trap")
    func reductionOverflow() throws {
        // Units x 100 overflows Int64.
        let huge = Fixture.reduceInput(events: [event("a", day: 20001, units: Int64.max / 50)])
        #expect(try #require(stats(huge)).reductionPercent == nil)
        // Days x baseline overflows Int64.
        let wide = SmokingInput(
            plan: Fixture.plan(mode: .reduce, baseline: Int64.max, limit: 10),
            prices: [Fixture.price(1000)],
            attempts: [],
            events: [event("a", day: 20001, units: 1), event("b", day: 20002, units: 1)],
            goal: nil
        )
        #expect(try #require(stats(wide)).reductionPercent == nil)
    }
}
