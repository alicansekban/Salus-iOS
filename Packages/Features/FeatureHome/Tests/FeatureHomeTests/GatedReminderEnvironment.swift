// No Android twin: Kotlin's environment read is blocking, so two arrivals can never be in flight
// at once there. On iOS `notificationsAuthorized()` is `async` — `UNUserNotificationCenter` answers
// through a callback — and `HomeEvent.appeared` starts an unstructured `Task`, so two reads can
// overlap and finish in either order. This fake is how a test picks that order.
//
// Separate from `FakeReminderEnvironment` rather than a mode of it: that one exists to be *set*
// between arrivals and to answer immediately, which is what every other case wants, and folding a
// suspension into it would put a continuation in the path of six cases that have no use for one.
//
// `@unchecked Sendable` over a lock for `FakeReminderEnvironment`'s reason:
// `ReminderEnvironment.backgroundRefreshAvailable()` is synchronous, so an actor would not conform.

import Foundation
import SalusReminder

/// A `ReminderEnvironment` whose reads park until the test lets them through, one by one.
///
/// Only `notificationsAuthorized()` is gated, and that is enough to order two whole
/// `readiness(alarmKitSupported:)` calls: it is the first question that call asks, so a read held
/// there has not yet asked either of the other two, and releasing it runs the rest of that call to
/// completion without another suspension the test would have to steer.
final class GatedReminderEnvironment: ReminderEnvironment, @unchecked Sendable {
    private let lock = NSLock()

    /// The notification answer each read gets, by the order the reads started in.
    private let answers: [Bool]

    private var started = 0
    private var waiting: [Int: CheckedContinuation<Void, Never>] = [:]
    private var released: Set<Int> = []

    /// How many reads have begun. A test waits on this before starting the next arrival, so
    /// "read 0" and "read 1" name the same two reads however the pool schedules them.
    var startedReads: Int {
        lock.withLock { started }
    }

    init(notifications: [Bool]) {
        answers = notifications
    }

    func notificationsAuthorized() async -> Bool {
        let index = lock.withLock { () -> Int in
            let index = started
            started += 1
            return index
        }
        await waitForRelease(of: index)
        return lock.withLock { answers[index] }
    }

    /// Ungated: a read that has passed the notification gate is meant to run to its end.
    func alarmKitAuthorized() async -> Bool {
        true
    }

    func backgroundRefreshAvailable() -> Bool {
        true
    }

    /// Lets the `index`-th read finish. Safe to call before that read has started — it is recorded
    /// and the read passes straight through.
    func release(_ index: Int) {
        let continuation = lock.withLock { () -> CheckedContinuation<Void, Never>? in
            released.insert(index)
            return waiting.removeValue(forKey: index)
        }
        continuation?.resume()
    }

    private func waitForRelease(of index: Int) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let alreadyReleased = lock.withLock { () -> Bool in
                if released.contains(index) {
                    return true
                }
                waiting[index] = continuation
                return false
            }
            if alreadyReleased {
                continuation.resume()
            }
        }
    }
}
