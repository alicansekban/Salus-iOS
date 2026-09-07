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

/// A `ReminderEnvironment` whose three answers a test sets, and which counts what it was asked.
final class FakeReminderEnvironment: ReminderEnvironment, @unchecked Sendable {
    private let lock = NSLock()

    private let notifications: Bool
    private let alarmKit: Bool
    private let backgroundRefresh: Bool

    private var reads: [Read: Int] = [:]

    /// Which of the three answers the editor asked for, so a test can prove the as-needed
    /// medication never asks. Per method rather than one total, and the same shape as
    /// `FeatureHomeTests/FakeReminderEnvironment.swift`: a single counter that only rose in
    /// `notificationsAuthorized()` could not tell "never asked" apart from "asked one of the other
    /// two", which is the whole point of the assertion.
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

    /// How many times one of the three answers was asked for.
    func readCount(of read: Read) -> Int {
        lock.withLock { reads[read, default: 0] }
    }
}
