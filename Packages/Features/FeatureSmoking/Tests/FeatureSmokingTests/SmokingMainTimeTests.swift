// Ported from `SmokingMainTimeTest.kt`, plus the live-counter schedule that replaces the
// ViewModel's `runClock` (a `TimelineView` has no coroutine to delay in, so the cadence is a
// `TimelineSchedule` whose entries are pinned here).

import Foundation
import Testing

@testable import FeatureSmoking

@Suite("Main screen time")
struct SmokingMainTimeTests {
    @Test("the clock ticks every second inside the first hour and every minute after it")
    func tickCadence() {
        #expect(tickDelayMs(sinceLastSmokeMs: 0) == 1000)
        #expect(tickDelayMs(sinceLastSmokeMs: hourMs - 1) == 1000)
        #expect(tickDelayMs(sinceLastSmokeMs: hourMs) == 60000)
        #expect(tickDelayMs(sinceLastSmokeMs: 42 * dayMs) == 60000)
    }

    @Test("an elapsed time of days reads as days, hours and minutes")
    func daysLabel() {
        #expect(
            timeLabelOf(42 * dayMs + 6 * hourMs + 12 * minuteMs + 59000)
                == .days(days: 42, hours: 6, minutes: 12)
        )
        #expect(timeLabelOf(dayMs) == .days(days: 1, hours: 0, minutes: 0))
    }

    @Test("an elapsed time of hours reads as hours and minutes")
    func hoursLabel() {
        #expect(timeLabelOf(6 * hourMs + 12 * minuteMs) == .hours(hours: 6, minutes: 12))
        #expect(timeLabelOf(hourMs) == .hours(hours: 1, minutes: 0))
        #expect(timeLabelOf(dayMs - 1) == .hours(hours: 23, minutes: 59))
    }

    @Test("the first hour reads as minutes and seconds")
    func minSecLabel() {
        #expect(timeLabelOf(13 * minuteMs + 28000) == .minSec(minutes: 13, seconds: 28))
        #expect(timeLabelOf(hourMs - 1) == .minSec(minutes: 59, seconds: 59))
        #expect(timeLabelOf(0) == .minSec(minutes: 0, seconds: 0))
    }

    @Test("a negative elapsed time is zero, never a negative label")
    func negativeIsZero() {
        #expect(timeLabelOf(-5000) == .minSec(minutes: 0, seconds: 0))
    }

    @Test("the schedule steps by a second until the last smoke is an hour old, then by a minute")
    func scheduleSlowsDownAtTheHour() {
        // The last smoke was 2 s short of an hour before the schedule's start.
        let lastSmokeAtMs: Int64 = 1_000_000
        let startMs = lastSmokeAtMs + hourMs - 2000
        let entries = LiveCounterEntries(startMs: startMs, lastSmokeAtMs: lastSmokeAtMs)

        let steps = entries.prefix(5).map { $0 - startMs }

        // +0 and +1 s are inside the first hour; at +2 s the hour is full, so the rest are minutes.
        #expect(steps == [0, 1000, 2000, 2000 + 60000, 2000 + 120_000])
    }

    @Test("an old last smoke ticks by the minute from the first entry")
    func scheduleStartsOnTheMinuteCadence() {
        let entries = LiveCounterEntries(startMs: 5 * hourMs, lastSmokeAtMs: 0)

        #expect(entries.prefix(3).map { $0 - 5 * hourMs } == [0, 60000, 120_000])
    }
}
