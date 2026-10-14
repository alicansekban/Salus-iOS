// Shared fixtures of the smoking reminder suites: an Istanbul wall-clock reader (UTC+3 all year),
// a repository whose input a test can swap between calls, and strings that name what they were asked
// for. Ported from the helpers of Android's `SmokingReminderHandlerTest.kt` /
// `SmokingNotificationTextTest.kt`.

import Foundation
import SalusCommon
import SalusModel
import SalusReminder
import SalusSmoking
import SalusTesting

@testable import FeatureSmoking

enum SmokingReminderFixtures {
    static let zone = TimeZone(identifier: "Europe/Istanbul") ?? .gmt

    /// `2026-03-10T09:05` or `2026-03-10T09:05:30` as epoch milliseconds in ``zone``.
    static func ms(_ local: String, in zone: TimeZone = zone) -> Int64 {
        let parts = local.split(separator: "T")
        let date = parts[0].split(separator: "-").compactMap { Int($0) }
        let time = parts[1].split(separator: ":").compactMap { Int($0) }
        let seconds = time.count > 2 ? time[2] : 0
        let instant = LocalDateTime(
            date: LocalDate(year: date[0], month: date[1], day: date[2]),
            minuteOfDay: time[0] * 60 + time[1]
        ).instant(in: zone)
        return instant.epochMilliseconds + Int64(seconds) * 1000
    }

    static func at(_ local: String, in zone: TimeZone = zone) -> Date {
        Date(epochMilliseconds: ms(local, in: zone))
    }

    static func epochDay(_ text: String) -> Int64 {
        let date = text.split(separator: "-").compactMap { Int($0) }
        return Int64(LocalDate(year: date[0], month: date[1], day: date[2]).epochDay)
    }

    static func plan(
        mode: SmokingMode,
        notifications: Bool = true,
        evening: Bool = false,
        baseline: Int64 = 20,
        currency: String = "TRY"
    ) -> SmokingPlan {
        SmokingPlan(
            id: "p1",
            mode: mode,
            productType: .cigarette,
            baselineUnitsPerDay: baseline,
            dailyLimit: mode == .reduce ? 10 : nil,
            currencyCode: currency,
            reason: nil,
            notificationsEnabled: notifications,
            eveningReminderEnabled: evening,
            createdAtMs: ms("2026-03-01T10:00"),
            tzId: zone.identifier
        )
    }

    static let price = PricePeriod(id: "price1", effectiveFromEpochDay: epochDay("2026-03-01"), unitCostMinor: 1000)

    static func quitInput(
        notifications: Bool = true,
        startMs: Int64 = ms("2026-03-10T09:00"),
        events: [SmokingEvent] = [],
        baseline: Int64 = 20,
        earlierAttempts: [QuitAttempt] = []
    ) -> SmokingInput {
        SmokingInput(
            plan: plan(mode: .quit, notifications: notifications, baseline: baseline),
            prices: [price],
            attempts: earlierAttempts + [QuitAttempt(
                id: "a1", startedAtMs: startMs, tzId: zone.identifier, endedAtMs: nil, endReason: nil
            )],
            events: events,
            goal: nil
        )
    }

    static func reduceInput(
        evening: Bool,
        events: [SmokingEvent] = [],
        attempts: [QuitAttempt] = []
    ) -> SmokingInput {
        SmokingInput(
            plan: plan(mode: .reduce, evening: evening),
            prices: [price],
            attempts: attempts,
            events: events,
            goal: nil
        )
    }

    static let empty = SmokingInput(plan: nil, prices: [], attempts: [], events: [], goal: nil)

    static func smoked(_ id: String, _ atMs: Int64, attemptId: String? = "a1", units: Int64 = 1) -> SmokingEvent {
        event(id, .smoked, atMs, attemptId, units)
    }

    static func craving(_ id: String, _ atMs: Int64) -> SmokingEvent {
        event(id, .cravingResisted, atMs, "a1", nil)
    }

    private static func event(
        _ id: String,
        _ type: SmokingEventType,
        _ atMs: Int64,
        _ attemptId: String?,
        _ units: Int64?
    ) -> SmokingEvent {
        SmokingEvent(
            id: id,
            type: type,
            occurredAtMs: atMs,
            tzId: zone.identifier,
            epochDay: SalusCommon.epochDay(of: atMs, in: zone),
            units: units,
            trigger: type == .cravingResisted ? .stress : nil,
            intensity: nil,
            productType: .cigarette,
            attemptId: attemptId
        )
    }

    static func ref(_ key: String, entityId: String = "smoking") -> ReminderRef {
        ReminderRef(type: .smoking, entityId: entityId, occurrenceKey: key)
    }
}

/// Reads the latest ``input`` on every collection, so a test can change the data between calls.
final class InputSwappingSmokingRepository: SmokingRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: SmokingInput

    init(_ input: SmokingInput) {
        stored = input
    }

    var input: SmokingInput {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }

    func observeInput() -> AsyncStream<SmokingInput> {
        let current = input
        return AsyncStream { continuation in
            continuation.yield(current)
            continuation.finish()
        }
    }

    func observeSnapshot() -> AsyncStream<SmokingSnapshot> {
        AsyncStream { $0.finish() }
    }

    func snapshotNow() async -> SmokingSnapshot {
        .notSetUp
    }
}

/// Texts that name what they were asked for, so a test asserts which milestone was announced.
struct FakeSmokingNotificationStrings: SmokingNotificationStrings {
    func stageReached(stageId: String) -> String? {
        "stage:\(stageId)"
    }
    func daysReached(_ days: Int64) -> String {
        "days:\(days)"
    }
    func unitsSkipped(_ units: Int64) -> String {
        "units:\(units)"
    }
    func moneySaved(minor: Int64, currencyCode: String) -> String {
        "money:\(minor):\(currencyCode)"
    }
    func stageHint() -> String {
        "stage-hint"
    }
    func cheer() -> String {
        "cheer"
    }
    func eveningTitle() -> String {
        "evening-title"
    }
    func eveningText() -> String {
        "evening-text"
    }
}
