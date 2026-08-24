// The `lastSyncCompletedAt` store: one stamp, written after every reconciliation pass and read by
// Reminder Health (iOS-M3 Task 8) to answer "when did the engine last actually run?".
//
// The key pinned below is deliberately OUTSIDE the 13 Android-verbatim settings keys
// (CLAUDE.md "Port fidelity rules", spec §9). It is an iOS-only operational value: Android answers
// the same question from WorkManager's own work history, so there is no Android key to match, and
// nothing on either platform reads it out of a backup. The pin exists for the opposite reason the
// settings pins do — not to keep the two platforms agreeing, but to keep a rename from silently
// resetting every installed app's "last synced" line to "never".

import Foundation
import SalusCommon
import Testing

@testable import SalusReminder

@Suite("Reminder sync state store")
struct ReminderSyncStateStoreTests {
    /// 2025-08-24T02:26:40Z.
    static let now = Date(epochMilliseconds: 1_756_000_000_000)

    @Test("the key is iOS-local and is not one of the 13 Android settings keys")
    func keyIsPinned() {
        #expect(UserDefaultsReminderSyncStateStore.lastSyncKey == "reminder_last_sync_epoch_ms")
    }

    @Test("nothing recorded reads back as never")
    func absentValueIsNil() throws {
        let defaults = try TestDefaults()

        let store = UserDefaultsReminderSyncStateStore(defaults: defaults.defaults)

        #expect(store.lastSyncCompletedAt == nil)
    }

    @Test("a recorded completion reads back at millisecond precision")
    func recordedValueRoundTrips() throws {
        let defaults = try TestDefaults()
        let store = UserDefaultsReminderSyncStateStore(defaults: defaults.defaults)

        store.recordSyncCompleted(at: Self.now)

        // Epoch milliseconds, the wire every other instant in this port is stored on
        // (`ReminderAlarmRecord.triggerAtEpochMs`), so a stamp survives a round trip exactly.
        #expect(store.lastSyncCompletedAt == Self.now)
        #expect(defaults.defaults.object(forKey: UserDefaultsReminderSyncStateStore.lastSyncKey) as? Int
            == 1_756_000_000_000)
    }

    @Test("a later completion replaces the earlier one")
    func laterValueReplacesEarlier() throws {
        let defaults = try TestDefaults()
        let store = UserDefaultsReminderSyncStateStore(defaults: defaults.defaults)

        store.recordSyncCompleted(at: Self.now)
        store.recordSyncCompleted(at: Self.now.addingTimeInterval(.hours(12)))

        #expect(store.lastSyncCompletedAt == Self.now.addingTimeInterval(.hours(12)))
    }
}

/// A throwaway `UserDefaults` suite, wiped when the test's instance goes away — the same shape
/// `SalusSettings`' `TestUserDefaults` uses, re-declared because a test helper is not a product.
final class TestDefaults {
    let suiteName: String
    let defaults: UserDefaults

    init() throws {
        let suiteName = "salus-reminder-test-\(UUID().uuidString)"
        self.suiteName = suiteName
        defaults = try #require(
            UserDefaults(suiteName: suiteName),
            "UserDefaults refused the suite name \(suiteName)"
        )
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }
}
