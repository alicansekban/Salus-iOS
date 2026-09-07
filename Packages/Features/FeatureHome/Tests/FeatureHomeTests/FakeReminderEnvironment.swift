// The same fixture `FeatureMedicationsTests/FakeReminderEnvironment.swift` is, with one difference
// the dashboard needs and the editor does not: the three answers are **settable**, because the
// whole point of `HomeEvent.appeared` is that the device can change between two arrivals — the user
// leaves for Settings, grants the permission, comes back, and the card has to go. The editor asks
// once per save and never re-asks, so its copy takes the answers in `init` and keeps them.
//
// The duplicate is the one the feature template sanctions: a test target cannot import another
// package's tests, which is why `FakeNavigator.swift` is a copy in three features too.
//
// `@unchecked Sendable` over a lock rather than an actor for `FixedSalusClock`'s reason:
// `ReminderEnvironment.backgroundRefreshAvailable()` is synchronous, so a fake that made it `async`
// would not conform.

import Foundation
import SalusReminder

/// A `ReminderEnvironment` whose three answers a test sets, before or between arrivals.
final class FakeReminderEnvironment: ReminderEnvironment, @unchecked Sendable {
    private let lock = NSLock()

    private var notifications: Bool
    private var alarmKit: Bool
    private var backgroundRefresh: Bool

    init(notifications: Bool = true, alarmKit: Bool = true, backgroundRefresh: Bool = true) {
        self.notifications = notifications
        self.alarmKit = alarmKit
        self.backgroundRefresh = backgroundRefresh
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

    /// The twin of assigning to `environment.notifications` (`HomeViewModelTest.kt:242`) — a
    /// permission the user changed while the app was in the background.
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
