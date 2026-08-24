// The twin of the `FakeReminderEnvironment` in
// `feature/settings/src/test/kotlin/.../reminderhealth/ReminderHealthViewModelTest.kt:12-21`, with
// the two Android-only questions dropped and the two iOS seams the screen also drives added:
// prompting (`ReminderAuthorizationRequesting`) and the engine's own last-pass stamp
// (`ReminderSyncStateStore`).
//
// `@unchecked Sendable` over a lock rather than an actor for the same reason `FixedSalusClock` is:
// `ReminderEnvironment.backgroundRefreshAvailable()` is synchronous, so a fake that made it
// `async` would not conform.

import Foundation
import SalusReminder

/// A `ReminderEnvironment` whose three answers a test sets, including between refreshes — which is
/// how "the user flipped it in Settings while we were backgrounded" is spelled.
final class FakeReminderEnvironment: ReminderEnvironment, @unchecked Sendable {
    private let lock = NSLock()

    private var notifications: Bool
    private var alarmKit: Bool
    private var backgroundRefresh: Bool

    /// What the next `requestNotificationAuthorization()` answers, and whether it flips the
    /// environment's own answer with it — a granted prompt changes what the next read reports.
    private var notificationPromptGrants: Bool
    private var alarmKitPromptGrants: Bool

    /// How many times each prompt was shown, so a test can prove the screen asks before it sends
    /// the user to Settings.
    private(set) var notificationPromptCount = 0
    private(set) var alarmKitPromptCount = 0

    init(
        notifications: Bool = true,
        alarmKit: Bool = true,
        backgroundRefresh: Bool = true,
        notificationPromptGrants: Bool = true,
        alarmKitPromptGrants: Bool = true
    ) {
        self.notifications = notifications
        self.alarmKit = alarmKit
        self.backgroundRefresh = backgroundRefresh
        self.notificationPromptGrants = notificationPromptGrants
        self.alarmKitPromptGrants = alarmKitPromptGrants
    }

    func notificationsAuthorized() async -> Bool {
        lock.withLock { notifications }
    }

    func alarmKitAuthorized() async -> Bool {
        lock.withLock { alarmKit }
    }

    func backgroundRefreshAvailable() -> Bool {
        lock.withLock { backgroundRefresh }
    }

    /// What the user just changed in Settings, outside our process.
    func set(notifications: Bool? = nil, alarmKit: Bool? = nil, backgroundRefresh: Bool? = nil) {
        lock.withLock {
            if let notifications {
                self.notifications = notifications
            }
            if let alarmKit {
                self.alarmKit = alarmKit
            }
            if let backgroundRefresh {
                self.backgroundRefresh = backgroundRefresh
            }
        }
    }
}

/// The prompting half, in an extension of its own — the shape `SystemReminderEnvironment` uses for
/// the same pair of roles.
extension FakeReminderEnvironment: ReminderAuthorizationRequesting {
    func requestNotificationAuthorization() async -> Bool {
        lock.withLock {
            notificationPromptCount += 1
            notifications = notifications || notificationPromptGrants
            return notificationPromptGrants
        }
    }

    func requestAlarmKitAuthorization() async -> Bool {
        lock.withLock {
            alarmKitPromptCount += 1
            alarmKit = alarmKit || alarmKitPromptGrants
            return alarmKitPromptGrants
        }
    }
}

/// A `ReminderSyncStateStore` that remembers what a test put in it.
final class FakeReminderSyncStateStore: ReminderSyncStateStore, @unchecked Sendable {
    private let lock = NSLock()
    private var stamp: Date?

    init(lastSyncCompletedAt: Date? = nil) {
        stamp = lastSyncCompletedAt
    }

    var lastSyncCompletedAt: Date? {
        lock.withLock { stamp }
    }

    func recordSyncCompleted(at instant: Date) {
        lock.withLock { stamp = instant }
    }
}
