// Ported from Android
// `feature/trends/src/test/kotlin/com/alicansekban/salus/feature/trends/SmokingTestData.kt`.
//
// Hand-built smoking records for the Trends tests. Every instant is a fixed number: the Trends
// mapping never reads a clock, and a test that did would drift with the day it ran on.

import Foundation
import SalusSmoking

let smokingMsPerDay: Int64 = 86_400_000

/// Noon UTC on epoch day 20 685 (2026-08-20); the `epochDay`s below are relative to it.
let smokingToday: Int64 = 20685
let smokingNowMs: Int64 = smokingToday * smokingMsPerDay + 12 * 3_600_000

func smokingPlan(mode: SmokingMode = .quit, createdDay: Int64 = smokingToday - 60) -> SmokingPlan {
    SmokingPlan(
        id: "plan",
        mode: mode,
        productType: .cigarette,
        baselineUnitsPerDay: 20,
        dailyLimit: mode == .reduce ? 10 : nil,
        currencyCode: "TRY",
        reason: nil,
        notificationsEnabled: true,
        eveningReminderEnabled: false,
        createdAtMs: createdDay * smokingMsPerDay,
        tzId: "UTC"
    )
}

func smokingAttempt(_ id: String, startDay: Int64, endDay: Int64? = nil) -> QuitAttempt {
    QuitAttempt(
        id: id,
        startedAtMs: startDay * smokingMsPerDay,
        tzId: "UTC",
        endedAtMs: endDay.map { $0 * smokingMsPerDay },
        endReason: endDay == nil ? nil : .restarted
    )
}

/// One craving event at 15:00 UTC on `day`.
func smokingEvent(
    _ id: String,
    day: Int64,
    type: SmokingEventType = .cravingResisted,
    units: Int64? = nil,
    trigger: CravingTrigger? = .stress
) -> SmokingEvent {
    SmokingEvent(
        id: id,
        type: type,
        occurredAtMs: day * smokingMsPerDay + 15 * 3_600_000,
        tzId: "UTC",
        epochDay: day,
        units: units,
        trigger: trigger,
        intensity: nil,
        productType: .cigarette,
        attemptId: nil
    )
}

/// One event on each of `days` consecutive days ending today; `smoked` makes them smoked-units
/// events, the kind a REDUCE history is counted from.
func eventsOnConsecutiveDays(_ days: Int, smoked: Bool = false) -> [SmokingEvent] {
    (0 ..< days).map { index in
        let day = smokingToday - Int64(index)
        return smoked
            ? smokingEvent("e\(index)", day: day, type: .smoked, units: 3)
            : smokingEvent("e\(index)", day: day)
    }
}

func smokingInput(
    plan: SmokingPlan? = smokingPlan(),
    attempts: [QuitAttempt] = [],
    events: [SmokingEvent] = []
) -> SmokingInput {
    SmokingInput(plan: plan, prices: [], attempts: attempts, events: events, goal: nil)
}
