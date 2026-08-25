// The relay that breaks the composition root's one dependency cycle — see
// `ReminderSchedulerRelay`'s doc comment for why it exists at all.

import Foundation
import Testing

@testable import SalusReminder

@Suite("Reminder scheduler relay")
struct ReminderSchedulerRelayTests {
    /// Counts `requestSync()` calls. A class, because the relay holds it as `any ReminderScheduler`
    /// and the assertion reads the count back through the same instance.
    private final class CountingScheduler: ReminderScheduler, @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0

        var syncRequests: Int {
            lock.withLock { count }
        }

        func requestSync() {
            lock.withLock { count += 1 }
        }
    }

    @Test("a call before binding is dropped rather than buffered")
    func unboundCallIsANoOp() {
        let relay = ReminderSchedulerRelay()
        let target = CountingScheduler()

        relay.requestSync()
        relay.bind(target)

        #expect(target.syncRequests == 0)
    }

    @Test("a call after binding reaches the target")
    func boundCallForwards() {
        let relay = ReminderSchedulerRelay()
        let target = CountingScheduler()

        relay.bind(target)
        relay.requestSync()

        #expect(target.syncRequests == 1)
    }

    @Test("rebinding replaces the target")
    func rebindingReplacesTheTarget() {
        let relay = ReminderSchedulerRelay()
        let first = CountingScheduler()
        let second = CountingScheduler()

        relay.bind(first)
        relay.bind(second)
        relay.requestSync()

        #expect(first.syncRequests == 0)
        #expect(second.syncRequests == 1)
    }
}
