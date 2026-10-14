// Ported from the `remainingLabel` branch table of
// `feature/smoking/.../ui/timeline/SmokingTimelineScreen.kt` (and `NextStageCard`'s twin): which
// unit a stage's "n left" line is spoken in, as a pure function of the milliseconds left.

import Testing

@testable import FeatureSmoking

@Suite("StageRemaining")
struct StageRemainingTests {
    @Test(
        "the largest unit that fits",
        arguments: [
            (11 * dayMs + 3 * hourMs, StageRemaining.days(11)),
            (dayMs, StageRemaining.days(1)),
            (23 * hourMs + 59 * minuteMs, StageRemaining.hours(23)),
            (3 * hourMs + 10 * minuteMs, StageRemaining.hours(3)),
            (hourMs, StageRemaining.hours(1)),
            (59 * minuteMs + 59000, StageRemaining.minutes(59)),
            (5 * minuteMs, StageRemaining.minutes(5))
        ]
    )
    func largestUnit(remainingMs: Int64, expected: StageRemaining) {
        #expect(StageRemaining(remainingMs: remainingMs) == expected)
    }

    @Test("under a minute still reads one minute, never zero", arguments: [Int64(0), 1, 45000, -5000])
    func underAMinuteReadsOne(remainingMs: Int64) {
        // Zero minutes left on a stage that has not unlocked looks like a bug.
        #expect(StageRemaining(remainingMs: remainingMs) == .minutes(1))
    }
}
