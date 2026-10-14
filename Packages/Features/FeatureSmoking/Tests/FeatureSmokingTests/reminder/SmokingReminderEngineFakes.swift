// The reminder-engine stand-ins the smoking reminder suites share: a notification centre that
// remembers what it holds, an environment that authorizes everything, predictable ids, and a
// handler reduced to the occurrences a test hands it. The real synchronizer, ledger and smoking
// handler run on top of them.

import Foundation
import SalusCommon
import SalusModel
import SalusReminder

/// A feature handler reduced to the occurrences a test hands it; its content is a fixed text.
struct StubReminderHandler: ReminderHandler {
    let type: ReminderType
    let occurrences: [ReminderOccurrence]

    func occurrencesBetween(from: Date, until: Date) async throws -> [ReminderOccurrence] {
        occurrences.filter { $0.triggerAt >= from && $0.triggerAt < until }
    }

    func notificationContent(for _: ReminderRef) async throws -> ReminderNotificationContent? {
        ReminderNotificationContent(title: "stub", text: "stub")
    }
}

/// A notification centre that remembers what it was asked to hold.
final class PendingCountingGateway: NotificationGateway, @unchecked Sendable {
    struct Scheduled {
        let requestCode: Int32
        let triggerAt: Date
        let content: ReminderNotificationContent
        let ref: ReminderRef
    }

    private let lock = NSLock()
    private var calls: [Scheduled] = []
    private var pending: Set<Int32> = []

    var scheduled: [Scheduled] { lock.withLock { calls } }

    func schedule(
        requestCode: Int32,
        triggerAt: Date,
        content: ReminderNotificationContent,
        ref: ReminderRef
    ) async throws {
        lock.withLock {
            calls.append(Scheduled(requestCode: requestCode, triggerAt: triggerAt, content: content, ref: ref))
            pending.insert(requestCode)
        }
    }

    func cancel(requestCodes: [Int32]) async {
        lock.withLock { pending.subtract(requestCodes) }
    }

    func pendingRequestCodes() async -> Set<Int32> {
        lock.withLock { pending }
    }
}

struct AuthorizedEnvironment: ReminderEnvironment {
    func notificationsAuthorized() async -> Bool {
        true
    }
    func alarmKitAuthorized() async -> Bool {
        false
    }
    func backgroundRefreshAvailable() -> Bool {
        true
    }
}

final class CountingIdGenerator: IdGenerator, @unchecked Sendable {
    private let lock = NSLock()
    private var next = 0

    func newId() -> String {
        lock.withLock {
            defer { next += 1 }
            return "id-\(next)"
        }
    }
}
