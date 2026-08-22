import Foundation

/// What the user has already spent of their AI allowance.
///
/// Ported from `core/datastore/.../AiUsageDataSource.kt:23-32`.
///
/// - `freeSummaryUsed`: whether the one-off free summary a non-premium user gets has been spent.
///   Once true it never goes back.
/// - `callsEpochDay`: the day `callsToday` belongs to. Kept alongside the count so the daily quota
///   resets without a scheduled job — the next call on a different day resets it.
/// - `callsToday`: how many AI calls were made on `callsEpochDay`.
public struct AiUsage: Equatable, Sendable {
    public let freeSummaryUsed: Bool
    public let callsEpochDay: Int
    public let callsToday: Int

    public init(freeSummaryUsed: Bool, callsEpochDay: Int, callsToday: Int) {
        self.freeSummaryUsed = freeSummaryUsed
        self.callsEpochDay = callsEpochDay
        self.callsToday = callsToday
    }

    /// Nothing spent yet: no free summary used, no call ever recorded (`AiUsageDataSource.kt:30`).
    public static let `default` = AiUsage(freeSummaryUsed: false, callsEpochDay: 0, callsToday: 0)

    /// How many AI calls count against `todayEpochDay`'s quota
    /// (`AiUsageDataSource.kt:43-44`).
    ///
    /// Readers MUST go through this and never compare `callsToday` directly: the stored count is
    /// only reset by the next *write* (`AiUsageDataSource.recordCall`), so between midnight and
    /// the day's first call the stored count still belongs to a previous day. A reader checking
    /// `callsToday >= LIMIT` on its own would lock the user out on yesterday's count.
    public func callsOn(todayEpochDay: Int) -> Int {
        callsEpochDay == todayEpochDay ? callsToday : 0
    }
}

/// The stored daily call counter: the day it belongs to plus the count for that day.
/// Kept separate from `AiUsage` so the day-reset rule can be a pure function
/// (`AiUsageDataSource.kt:50`).
struct AiCallCount: Equatable, Sendable {
    let epochDay: Int
    let count: Int

    /// The whole day-reset rule, as a pure function (`AiUsageDataSource.kt:60-65`): recording a
    /// call on the day the counter already belongs to increments it, and recording one on any
    /// other day restarts the count at 1 for that day.
    ///
    /// "Any other day" rather than "a later day" on purpose — a user who moves the device clock
    /// backwards gets a reset, not a counter frozen in the future that never expires.
    func recordedOn(todayEpochDay: Int) -> AiCallCount {
        epochDay == todayEpochDay
            ? AiCallCount(epochDay: epochDay, count: count + 1)
            : AiCallCount(epochDay: todayEpochDay, count: 1)
    }
}

/// AI allowance counters, stored in the same `UserDefaults` domain as
/// `SalusPreferencesDataSource` but read and written as a separate stream: usage is machinery for
/// gating, not a user setting, so it never widens `UserSettings`
/// (`AiUsageDataSource.kt:67-122`).
public final class AiUsageDataSource: Sendable {
    /// See the note on `SalusPreferencesDataSource.defaults`.
    nonisolated(unsafe) let defaults: UserDefaults
    private let values: DefaultsValueStream<AiUsage>

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        nonisolated(unsafe) let captured = defaults
        values = DefaultsValueStream { Self.read(from: captured) }
    }

    /// The counters, re-read on each change (`AiUsageDataSource.kt:82-93`).
    ///
    /// Android wraps its flow in `catch { emit(emptyPreferences()) }` so that an unreadable
    /// preferences file degrades to `AiUsage.DEFAULT` instead of cancelling the collector
    /// (:76-85). `UserDefaults` has no throwing read to catch: a key it cannot resolve is simply
    /// absent, and every reader below already falls back to `AiUsage.default`. The Kotlin
    /// safeguard and this one land on the same value.
    public var usage: AsyncStream<AiUsage> {
        values.makeStream()
    }

    /// Spends the one-off free summary. Writing true over true is a no-op, so calling twice is
    /// safe (`AiUsageDataSource.kt:96-98`).
    public func markFreeSummaryUsed() {
        defaults.set(true, forKey: SettingsKeys.aiFreeSummaryUsed)
        values.publish()
    }

    /// Counts one AI call made on `todayEpochDay` (`AiUsageDataSource.kt:105-115`).
    ///
    /// Android does the read and the write inside a single `edit`, which is atomic against
    /// concurrent editors. The iOS twin is a synchronous read-modify-write against one
    /// `UserDefaults` instance: each individual access is serialised by the framework, and the
    /// three of them run to completion on the calling thread with no suspension point between —
    /// so a single-threaded caller (which is what the AI repositories are, one call per user
    /// action) cannot observe a torn count.
    public func recordCall(todayEpochDay: Int) {
        let stored = AiCallCount(
            epochDay: defaults.storedInt(
                forKey: SettingsKeys.aiCallsEpochDay,
                default: AiUsage.default.callsEpochDay
            ),
            count: defaults.storedInt(
                forKey: SettingsKeys.aiCallsCount,
                default: AiUsage.default.callsToday
            )
        )
        let recorded = stored.recordedOn(todayEpochDay: todayEpochDay)

        defaults.set(recorded.epochDay, forKey: SettingsKeys.aiCallsEpochDay)
        defaults.set(recorded.count, forKey: SettingsKeys.aiCallsCount)
        values.publish()
    }

    private static func read(from defaults: UserDefaults) -> AiUsage {
        AiUsage(
            freeSummaryUsed: defaults.storedBool(
                forKey: SettingsKeys.aiFreeSummaryUsed,
                default: AiUsage.default.freeSummaryUsed
            ),
            callsEpochDay: defaults.storedInt(
                forKey: SettingsKeys.aiCallsEpochDay,
                default: AiUsage.default.callsEpochDay
            ),
            callsToday: defaults.storedInt(
                forKey: SettingsKeys.aiCallsCount,
                default: AiUsage.default.callsToday
            )
        )
    }
}
