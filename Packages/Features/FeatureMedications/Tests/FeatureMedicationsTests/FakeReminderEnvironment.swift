// The same fixture `FeatureSettingsTests/FakeReminderEnvironment.swift` is, minus the two halves
// only Reminder Health drives: this feature never prompts and never reads the engine's last-pass
// stamp, so `ReminderAuthorizationRequesting` and `FakeReminderSyncStateStore` have no reader here.
// The duplicate is the one the feature template sanctions — a test target cannot import another
// package's tests, which is why `FakeNavigator.swift` is a copy too.
//
// `@unchecked Sendable` over a lock rather than an actor for `FixedSalusClock`'s reason:
// `ReminderEnvironment.backgroundRefreshAvailable()` is synchronous, so a fake that made it `async`
// would not conform.

import Foundation
import SalusReminder

/// A `ReminderEnvironment` whose three answers a test sets.
final class FakeReminderEnvironment: ReminderEnvironment, @unchecked Sendable {
    private let lock = NSLock()

    private let notifications: Bool
    private let alarmKit: Bool
    private let backgroundRefresh: Bool

    /// How many times the editor asked, so a test can prove the as-needed medication never does.
    private(set) var readCount = 0

    init(notifications: Bool = true, alarmKit: Bool = true, backgroundRefresh: Bool = true) {
        self.notifications = notifications
        self.alarmKit = alarmKit
        self.backgroundRefresh = backgroundRefresh
    }

    func notificationsAuthorized() async -> Bool {
        lock.withLock {
            readCount += 1
            return notifications
        }
    }

    func alarmKitAuthorized() async -> Bool {
        lock.withLock { alarmKit }
    }

    func backgroundRefreshAvailable() -> Bool {
        lock.withLock { backgroundRefresh }
    }
}
