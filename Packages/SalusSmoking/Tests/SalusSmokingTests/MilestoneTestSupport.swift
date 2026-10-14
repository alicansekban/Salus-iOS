import Foundation

@testable import SalusSmoking

// Builders shared by the milestone suites (`MilestoneSchedulerTests`, `MilestonePlanningTests`).
// Names carry a `milestone` prefix because they are module-wide. Europe/Istanbul is a permanent
// UTC+3, so local wall-clock arithmetic there is plain addition; day 20 000 (`Fixture.day0`) is
// 2024-10-04, so day 20 000 + n is the date in each key.

private let hourMs = Fixture.hourMs
private let minuteMs = Fixture.minuteMs
private let day0 = Fixture.day0

func milestoneAt(_ offset: Int64, _ hour: Int64, _ minute: Int64 = 0) -> Int64 {
    Fixture.midnight(day0 + offset) + hour * hourMs + minute * minuteMs
}

func milestonePlan(
    mode: SmokingMode = .quit,
    baseline: Int64 = 20,
    limit: Int64? = nil,
    currency: String = "TRY",
    notifications: Bool = true,
    evening: Bool = false
) -> SmokingPlan {
    SmokingPlan(
        id: "plan",
        mode: mode,
        productType: .cigarette,
        baselineUnitsPerDay: baseline,
        dailyLimit: limit,
        currencyCode: currency,
        reason: nil,
        notificationsEnabled: notifications,
        eveningReminderEnabled: evening,
        createdAtMs: Fixture.midnight(day0),
        tzId: "Europe/Istanbul"
    )
}

/// A QUIT input with one active attempt "a1" starting at `start`.
func milestoneQuitData(
    start: Int64,
    baseline: Int64 = 20,
    cost: Int64 = 1000,
    currency: String = "TRY",
    events: [SmokingEvent] = [],
    notifications: Bool = true,
    evening: Bool = false,
    prices: [PricePeriod]? = nil
) -> SmokingInput {
    SmokingInput(
        plan: milestonePlan(baseline: baseline, currency: currency, notifications: notifications, evening: evening),
        prices: prices ?? [Fixture.price(cost)],
        attempts: [Fixture.attempt(start: start)],
        events: events,
        goal: nil
    )
}

func milestoneReduceData(evening: Bool, notifications: Bool = true) -> SmokingInput {
    SmokingInput(
        plan: milestonePlan(mode: .reduce, baseline: 20, limit: 15, notifications: notifications, evening: evening),
        prices: [Fixture.price(1000)],
        attempts: [],
        events: [Fixture.smoked("e1", at: milestoneAt(0, 10), units: 4, attempt: nil)],
        goal: nil
    )
}

func milestoneSchedule(
    _ input: SmokingInput,
    now: Int64,
    zone: TimeZone = Fixture.istanbul,
    limit: Int = 20
) -> [PlannedNotification] {
    MilestoneScheduler.plan(input, nowMs: now, zone: zone, limit: limit)
}

func milestoneIsMoney(_ kind: MilestoneKind) -> Bool {
    if case .money = kind {
        return true
    }
    return false
}

func milestoneIsEvening(_ kind: MilestoneKind) -> Bool {
    if case .evening = kind {
        return true
    }
    return false
}

func milestoneIsUnitsOrMoney(_ kind: MilestoneKind) -> Bool {
    switch kind {
    case .money, .units: true
    default: false
    }
}

func milestoneNote(_ key: String, _ triggerAtMs: Int64, _ kinds: MilestoneKind...) -> PlannedNotification {
    PlannedNotification(key: key, triggerAtMs: triggerAtMs, kinds: kinds)
}
