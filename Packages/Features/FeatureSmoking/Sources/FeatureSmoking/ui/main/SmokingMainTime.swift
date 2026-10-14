// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/main/
// SmokingMainTime.kt`.
//
// The live figures on the main screen, as plain functions of milliseconds so the cadence and the
// wording thresholds are testable without a clock or a view.
//
// One shape difference: Android's ViewModel runs the ticker (`runClock`, a `delay` loop under
// `repeatOnLifecycle(STARTED)`). A `TimelineView` has no coroutine to delay in, so the same
// cadence is a `TimelineSchedule` — ``LiveCounterSchedule`` — whose entries are the instants the
// counters are redrawn at. SwiftUI stops updating a `TimelineView` that is off screen or in the
// background, which is what `repeatOnLifecycle` bought.

import Foundation
import SalusCommon
import SwiftUI

private let secondMs: Int64 = 1000
private let minuteMs: Int64 = 60 * secondMs
private let hourMs: Int64 = 60 * minuteMs
private let dayMs: Int64 = 24 * hourMs

/// How long the screen waits between two redraws of its counters. Seconds are only worth
/// redrawing while they are on screen, which is the first hour after the last smoke; from then on
/// the smallest unit shown is the minute, and a per-second tick would only burn battery.
func tickDelayMs(sinceLastSmokeMs: Int64) -> Int64 {
    sinceLastSmokeMs < hourMs ? secondMs : minuteMs
}

/// An elapsed time cut at the largest unit that fits: days with hours and minutes, hours with
/// minutes, or, inside the first hour, minutes with seconds. Which cut applies decides the wording
/// the screen uses, so it lives here rather than in the view.
enum TimeLabel: Equatable {
    case days(days: Int64, hours: Int, minutes: Int)
    case hours(hours: Int, minutes: Int)
    case minSec(minutes: Int, seconds: Int)
}

/// `elapsedMs` below zero (a device clock set behind the start) reads as zero.
func timeLabelOf(_ elapsedMs: Int64) -> TimeLabel {
    let ms = max(0, elapsedMs)
    let hours = Int((ms % dayMs) / hourMs)
    let minutes = Int((ms % hourMs) / minuteMs)
    if ms >= dayMs {
        return .days(days: ms / dayMs, hours: hours, minutes: minutes)
    }
    if ms >= hourMs {
        return .hours(hours: hours, minutes: minutes)
    }
    return .minSec(minutes: minutes, seconds: Int((ms % minuteMs) / secondMs))
}

/// The instants the counters are redrawn at: every second until the last smoke is an hour old,
/// every minute after. The first entry is the schedule's own start, so a view that appears shows
/// the time it appeared at rather than waiting a tick.
struct LiveCounterEntries: Sequence, IteratorProtocol {
    private var nextMs: Int64
    private let lastSmokeAtMs: Int64

    init(startMs: Int64, lastSmokeAtMs: Int64) {
        nextMs = startMs
        self.lastSmokeAtMs = lastSmokeAtMs
    }

    mutating func next() -> Int64? {
        let current = nextMs
        nextMs = current + tickDelayMs(sinceLastSmokeMs: current - lastSmokeAtMs)
        return current
    }
}

/// ``LiveCounterEntries`` as the `Date`s a `TimelineView` wants.
struct LiveCounterSchedule: TimelineSchedule {
    /// The instant of the last smoke: `computedAt − sinceLastSmoke` of the snapshot on screen.
    let lastSmokeAtMs: Int64

    func entries(from startDate: Date, mode: Mode) -> Entries {
        Entries(inner: LiveCounterEntries(startMs: startDate.epochMilliseconds, lastSmokeAtMs: lastSmokeAtMs))
    }

    struct Entries: Sequence, IteratorProtocol {
        fileprivate var inner: LiveCounterEntries

        mutating func next() -> Date? {
            inner.next().map { Date(epochMilliseconds: $0) }
        }
    }
}
