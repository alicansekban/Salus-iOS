import Foundation
import SalusSmoking
import SalusTesting

// Builders for the calculator tests. Day 20 000 is 2024-10-04; Europe/Istanbul is a permanent
// UTC+3, so a local midnight is `day * dayMs - 3h` with no daylight-saving term to hide an error.

enum Fixture {
    static let dayMs: Int64 = 86_400_000
    static let hourMs: Int64 = 3_600_000
    static let minuteMs: Int64 = 60000
    static let day0: Int64 = 20000
    static let istanbul = FixedSalusClock.defaultZone
    static let berlin = TimeZone(identifier: "Europe/Berlin") ?? .gmt

    /// Local midnight of `day` in Istanbul.
    static func midnight(_ day: Int64) -> Int64 {
        day * dayMs - 3 * hourMs
    }

    /// The Istanbul calendar day an instant falls on (instants here are all after 1970).
    static func istanbulDay(_ ms: Int64) -> Int64 {
        (ms + 3 * hourMs) / dayMs
    }

    static var start: Int64 {
        midnight(day0)
    }

    static func plan(
        mode: SmokingMode = .quit,
        product: ProductType = .cigarette,
        baseline: Int64 = 20,
        limit: Int64? = nil,
        createdAt: Int64 = Fixture.midnight(Fixture.day0),
        tz: String = "Europe/Istanbul"
    ) -> SmokingPlan {
        SmokingPlan(
            id: "plan",
            mode: mode,
            productType: product,
            baselineUnitsPerDay: baseline,
            dailyLimit: limit,
            currencyCode: "TRY",
            reason: nil,
            notificationsEnabled: true,
            eveningReminderEnabled: false,
            createdAtMs: createdAt,
            tzId: tz
        )
    }

    static func price(_ cost: Int64, from day: Int64 = Fixture.day0, id: String = "p1") -> PricePeriod {
        PricePeriod(id: id, effectiveFromEpochDay: day, unitCostMinor: cost)
    }

    static func attempt(
        _ id: String = "a1",
        start: Int64 = Fixture.start,
        end: Int64? = nil,
        reason: AttemptEndReason? = nil,
        tz: String = "Europe/Istanbul"
    ) -> QuitAttempt {
        QuitAttempt(id: id, startedAtMs: start, tzId: tz, endedAtMs: end, endReason: reason)
    }

    static func smoked(
        _ id: String,
        at ms: Int64,
        units: Int64 = 1,
        attempt: String? = "a1",
        product: ProductType = .cigarette,
        day: Int64? = nil,
        tz: String = "Europe/Istanbul"
    ) -> SmokingEvent {
        SmokingEvent(
            id: id,
            type: .smoked,
            occurredAtMs: ms,
            tzId: tz,
            epochDay: day ?? istanbulDay(ms),
            units: units,
            trigger: nil,
            intensity: nil,
            productType: product,
            attemptId: attempt
        )
    }

    static func craving(_ id: String, at ms: Int64, attempt: String?) -> SmokingEvent {
        SmokingEvent(
            id: id,
            type: .cravingResisted,
            occurredAtMs: ms,
            tzId: "Europe/Istanbul",
            epochDay: istanbulDay(ms),
            units: nil,
            trigger: nil,
            intensity: nil,
            productType: .cigarette,
            attemptId: attempt
        )
    }

    static func goal(
        target: Int64,
        createdAt: Int64,
        achievedAt: Int64? = nil
    ) -> SavingsGoal {
        SavingsGoal(id: "g1", title: "Trip", targetMinor: target, createdAtMs: createdAt, achievedAtMs: achievedAt)
    }

    /// A QUIT input with one active attempt, one price and the given events.
    static func quitInput(
        baseline: Int64 = 20,
        cost: Int64 = 1000,
        product: ProductType = .cigarette,
        attempts: [QuitAttempt] = [Fixture.attempt()],
        events: [SmokingEvent] = [],
        goal: SavingsGoal? = nil
    ) -> SmokingInput {
        SmokingInput(
            plan: plan(product: product, baseline: baseline),
            prices: [price(cost)],
            attempts: attempts,
            events: events,
            goal: goal
        )
    }

    /// A REDUCE input: baseline 20, limit 10, one price.
    static func reduceInput(
        cost: Int64 = 1000,
        prices: [PricePeriod]? = nil,
        createdAt: Int64 = Fixture.midnight(Fixture.day0),
        events: [SmokingEvent] = [],
        goal: SavingsGoal? = nil
    ) -> SmokingInput {
        SmokingInput(
            plan: plan(mode: .reduce, baseline: 20, limit: 10, createdAt: createdAt),
            prices: prices ?? [price(cost)],
            attempts: [],
            events: events,
            goal: goal
        )
    }
}

struct WrongSnapshotKind: Error {}

func quitSnapshot(
    _ input: SmokingInput,
    now: Int64,
    zone: TimeZone = Fixture.istanbul
) throws -> QuitSnapshot {
    guard case let .quit(snapshot) = SmokingStatsCalculator.snapshot(input, nowMs: now, zone: zone) else {
        throw WrongSnapshotKind()
    }
    return snapshot
}

func reduceSnapshot(
    _ input: SmokingInput,
    now: Int64,
    zone: TimeZone = Fixture.istanbul
) throws -> ReduceSnapshot {
    guard case let .reduce(snapshot) = SmokingStatsCalculator.snapshot(input, nowMs: now, zone: zone) else {
        throw WrongSnapshotKind()
    }
    return snapshot
}
