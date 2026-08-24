// Test doubles for the two platform seams `UserNotificationGateway` sits on: the notification
// centre and the AlarmKit manager. They live beside `Fakes.swift` rather than inside it because
// that file is a port of Kotlin's `Fakes.kt` and these have no Kotlin twin — Android's gateway
// talks to `AlarmManager`, which cannot be asked what it holds, so its tests never needed either.
//
// Both record the REAL framework objects (`UNNotificationRequest`, `UNNotificationCategory`) so a
// test asserts against what the OS would actually receive, not against a re-description of it.
// They are classes with a lock for the same reason the recording gateway is: the protocols are
// `Sendable` and a test mutates them between calls.

import Foundation
import SalusModel
import UserNotifications

@testable import SalusReminder

/// The notification centre, in memory. `add` replaces by identifier exactly as
/// `UNUserNotificationCenter` does, which is what makes re-scheduling an occurrence idempotent.
final class FakeUserNotificationCenter: UserNotificationCenting, @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [UNNotificationRequest] = []
    private var categories: Set<UNNotificationCategory> = []

    /// Everything the centre is holding, in insertion order.
    var pending: [UNNotificationRequest] { lock.withLock { requests } }

    /// The last `setNotificationCategories` argument — the centre keeps only the latest set.
    var registeredCategories: Set<UNNotificationCategory> { lock.withLock { categories } }

    func add(_ request: UNNotificationRequest) async throws {
        lock.withLock {
            requests.removeAll { $0.identifier == request.identifier }
            requests.append(request)
        }
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async {
        let dropped = Set(identifiers)
        lock.withLock { requests.removeAll { dropped.contains($0.identifier) } }
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        lock.withLock { requests }
    }

    func notificationSettings() async -> UNNotificationSettings? {
        // `UNNotificationSettings` has no public initializer, so a fake cannot produce one. The
        // seam therefore answers optionally and every caller reads nil as "unknown"; the real
        // settings are read on device.
        nil
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) async {
        lock.withLock { self.categories = categories }
    }

    func requestAuthorization(options _: UNAuthorizationOptions) async throws -> Bool {
        // The gateway never asks: authorization is the composition root's business (Task 7), and
        // this is here only because the seam declares it. A case that needs it records here.
        true
    }
}

/// One `AlarmKitScheduling.schedule` call, kept whole so a routing test can assert the payload.
struct ScheduledAlarm: Equatable {
    let requestCode: Int32
    let triggerAt: Date
    let content: ReminderNotificationContent
    let ref: ReminderRef
}

/// The AlarmKit manager, in memory. Its mere presence is what tells the gateway that the alarm
/// backend is reachable, so injecting it is how a test says "this device is iOS 26+" without
/// faking an availability check.
final class FakeAlarmKitScheduler: AlarmKitScheduling, @unchecked Sendable {
    private let lock = NSLock()
    private var scheduled: [ScheduledAlarm] = []
    private var cancelled: [Int32] = []
    private var live: Set<Int32> = []

    var scheduleCalls: [ScheduledAlarm] { lock.withLock { scheduled } }
    var cancelCalls: [Int32] { lock.withLock { cancelled } }

    func schedule(
        requestCode: Int32,
        triggerAt: Date,
        content: ReminderNotificationContent,
        ref: ReminderRef
    ) async throws {
        lock.withLock {
            scheduled.append(
                ScheduledAlarm(requestCode: requestCode, triggerAt: triggerAt, content: content, ref: ref)
            )
            live.insert(requestCode)
        }
    }

    func cancel(requestCodes: [Int32]) async {
        lock.withLock {
            cancelled += requestCodes
            live.subtract(requestCodes)
        }
    }

    func scheduledRequestCodes() async -> Set<Int32> {
        lock.withLock { live }
    }
}

/// Collects the gateway's budget-tripwire reports. A class with a lock because the gateway takes a
/// `@Sendable` closure and is free to call it from any executor.
final class OverflowRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var reported: [Int] = []

    /// Every reported pending count, in order.
    var counts: [Int] { lock.withLock { reported } }

    func record(_ count: Int) {
        lock.withLock { reported.append(count) }
    }
}

/// Everything a gateway case injects, in one value. Shared by both gateway suites — the request
/// shape and the presentation routing — which is what keeps either of them inside the file-length
/// budget without either one owning the helpers the other borrows.
struct GatewayFixture {
    /// 2025-08-24T02:26:40Z, the instant the synchronizer suites are written around.
    static let triggerAt = Date(timeIntervalSince1970: 1_756_000_000)

    let center = FakeUserNotificationCenter()

    /// - Parameter alarmScheduler: passing one is how a case says "this device rings alarms"; the
    ///   gateway routes on its presence rather than on an OS version, so no availability is faked.
    func gateway(
        alarmScheduler: (any AlarmKitScheduling)? = nil,
        onPendingBudgetExceeded: @escaping @Sendable (Int) -> Void = { _ in }
    ) -> UserNotificationGateway {
        UserNotificationGateway(
            center: center,
            alarmScheduler: alarmScheduler,
            onPendingBudgetExceeded: onPendingBudgetExceeded
        )
    }

    func ref(
        _ type: ReminderType = .medicationDose,
        _ entityId: String = "med-1",
        _ occurrenceKey: String = "2026-09-01T08:00"
    ) -> ReminderRef {
        ReminderRef(type: type, entityId: entityId, occurrenceKey: occurrenceKey)
    }

    func content(
        title: String = "t",
        text: String = "x",
        actions: [ReminderAction] = [],
        presentation: ReminderPresentation = .notification
    ) -> ReminderNotificationContent {
        ReminderNotificationContent(title: title, text: text, actions: actions, presentation: presentation)
    }
}
