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

/// A `ReminderEnvironment` whose three answers a test sets, before or between arrivals, and which
/// counts what it was asked.
final class FakeReminderEnvironment: ReminderEnvironment, @unchecked Sendable {
    private let lock = NSLock()

    private var notifications: Bool
    private var alarmKit: Bool
    private var backgroundRefresh: Bool

    private var reads: [Read: Int] = [:]

    /// Which of the three answers a case asked for. The counts are per method rather than one
    /// total, because the assertion that needs them is about *which* question was asked: below
    /// iOS 26 `readiness(alarmKitSupported: false)` must skip `alarmKitAuthorized()` entirely, and
    /// a single counter could not tell that apart from a run that asked it and ignored the answer.
    enum Read: Hashable {
        case notifications
        case alarmKit
        case backgroundRefresh
    }

    init(notifications: Bool = true, alarmKit: Bool = true, backgroundRefresh: Bool = true) {
        self.notifications = notifications
        self.alarmKit = alarmKit
        self.backgroundRefresh = backgroundRefresh
    }

    func notificationsAuthorized() async -> Bool {
        lock.withLock {
            reads[.notifications, default: 0] += 1
            return notifications
        }
    }

    func alarmKitAuthorized() async -> Bool {
        lock.withLock {
            reads[.alarmKit, default: 0] += 1
            return alarmKit
        }
    }

    func backgroundRefreshAvailable() -> Bool {
        lock.withLock {
            reads[.backgroundRefresh, default: 0] += 1
            return backgroundRefresh
        }
    }

    /// How many times one of the three answers was asked for, so a case can assert on a question
    /// that was *not* asked as well as on one that was.
    func readCount(of read: Read) -> Int {
        lock.withLock { reads[read, default: 0] }
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
