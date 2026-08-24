// Where the engine records that it actually ran.
//
// Android never needed this: WorkManager keeps its own work history, and Reminder health reads the
// last successful run out of it. iOS has no such ledger — a `BGAppRefreshTask` that the system
// chose not to run leaves no trace at all — so "when did the window last get refilled?" has to be
// written down by the engine itself. It is the honesty signal behind Reminder Health's
// "app hasn't run since …" line (spec §"risk table"): a screen that shows three green rows while
// nothing has synced for a week is worse than no screen.
//
// **The key is deliberately outside the 13 Android-verbatim settings keys** (CLAUDE.md "Port
// fidelity rules", spec §9). It is an iOS-only operational value with no Android twin to agree
// with, it is never written into a backup's `settings` block, and adding it to
// `SalusPreferencesDataSource` would mean widening the ported `UserSettings` shape and giving
// `SalusReminder` a dependency on `SalusSettings` that Android's `:core:reminder` does not have
// (it depends on `:core:model`, `:core:common`, `:core:database` and `:core:notifications`, and
// on no datastore module). So it lives here, in the same `UserDefaults` domain, under a name that
// says which side of the contract it is on. `ReminderSyncStateStoreTests` pins the string.

import Foundation
import SalusCommon

/// The one fact the engine remembers about itself between launches.
public protocol ReminderSyncStateStore: Sendable {
    /// When the last reconciliation pass completed, or nil if none ever has on this install.
    var lastSyncCompletedAt: Date? { get }

    /// Records a completed pass. Called by ``BackgroundRefreshScheduler`` after every one.
    func recordSyncCompleted(at instant: Date)
}

/// The real store, over the app's own `UserDefaults` domain.
public struct UserDefaultsReminderSyncStateStore: ReminderSyncStateStore {
    /// iOS-local, and not one of the 13 Android keys — see the file header.
    public static let lastSyncKey = "reminder_last_sync_epoch_ms"

    /// See the note on `SalusPreferencesDataSource.defaults`: `UserDefaults` is documented
    /// thread-safe but carries no `Sendable` annotation, so the exemption is spelled out on the
    /// one property that needs it. Package-visible rather than `private` for the same reason it is
    /// there — SwiftFormat and SwiftLint order `nonisolated(unsafe)` and `private` in opposite
    /// ways, and neither gate may be silenced.
    nonisolated(unsafe) let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var lastSyncCompletedAt: Date? {
        // `object(forKey:)` rather than `integer(forKey:)`, which answers 0 for an absent key —
        // and 0 epoch milliseconds is 1970, i.e. "synced 56 years ago" instead of "never".
        guard let stored = defaults.object(forKey: Self.lastSyncKey) as? Int else { return nil }
        return Date(epochMilliseconds: Int64(stored))
    }

    public func recordSyncCompleted(at instant: Date) {
        // Epoch milliseconds, the wire every other instant in this port is stored on
        // (`ReminderAlarmRecord.triggerAtEpochMs`).
        defaults.set(Int(instant.epochMilliseconds), forKey: Self.lastSyncKey)
    }
}
