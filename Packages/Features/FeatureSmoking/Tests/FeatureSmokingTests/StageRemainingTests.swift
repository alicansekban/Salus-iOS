// Twin of `StageTimeLeftTest.kt`'s Main/timeline half (contract section 8.15): which unit and which
// rounded-up count a stage's "n left" line speaks, as a pure function of the milliseconds left. The
// rounding itself is `SalusSmoking.StageTimeLeft`; these rows pin that Main and the timeline use it
// (the accessors read the catalog, which `swift test` does not compile, so the sentence is pinned
// through the typed value and the catalog render tests).

import Testing

@testable import FeatureSmoking

@Suite("StageRemaining")
struct StageRemainingTests {
    @Test(
        "the unit and the rounded-up count come from the shared rule",
        arguments: [
            (11 * dayMs + 3 * hourMs, StageRemaining.days(12)),
            (3 * dayMs, StageRemaining.days(3)),
            (3 * dayMs + 1, StageRemaining.days(4)),
            (dayMs, StageRemaining.days(1)),
            // 23 h 59 min rounds to 24 hours, which is one day: never "24 h left".
            (23 * hourMs + 59 * minuteMs, StageRemaining.days(1)),
            (3 * hourMs + 10 * minuteMs, StageRemaining.hours(4)),
            (5 * hourMs + 1, StageRemaining.hours(6)),
            (hourMs, StageRemaining.hours(1)),
            // 59 min 30 s rounds to 60 minutes, which is one hour: never "60 min left".
            (59 * minuteMs + 30000, StageRemaining.hours(1)),
            (59 * minuteMs, StageRemaining.minutes(59)),
            (20 * minuteMs + 1, StageRemaining.minutes(21)),
            (5 * minuteMs, StageRemaining.minutes(5))
        ]
    )
    func sharedRule(remainingMs: Int64, expected: StageRemaining) {
        #expect(StageRemaining(remainingMs: remainingMs) == expected)
    }

    @Test("under a minute still reads one minute, never zero", arguments: [Int64(0), 1, 45000, -5000])
    func underAMinuteReadsOne(remainingMs: Int64) {
        // Zero minutes left on a stage that has not unlocked looks like a bug.
        #expect(StageRemaining(remainingMs: remainingMs) == .minutes(1))
    }
}
