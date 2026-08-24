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

/// What a backend refused. The cases are the two real refusals the gateway has to survive: AlarmKit
/// with no authorization, and a notification centre that rejects the request.
enum FakeSchedulingError: Error {
    case alarmsNotAuthorized
    case requestRejected
}

/// The notification centre, in memory. `add` replaces by identifier exactly as
/// `UNUserNotificationCenter` does, which is what makes re-scheduling an occurrence idempotent.
final class FakeUserNotificationCenter: UserNotificationCenting, @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [UNNotificationRequest] = []
    private var categories: Set<UNNotificationCategory> = []
    private var addFailure: (any Error)?
    private var authorizationCalls: [UNAuthorizationOptions] = []
    private var authorizationGrant = true
    private var authorizationFailure: (any Error)?

    /// Everything the centre is holding, in insertion order.
    var pending: [UNNotificationRequest] { lock.withLock { requests } }

    /// Every option set the app asked authorization for, in order. Authorization is the
    /// composition root's business (`SystemReminderEnvironment`), so the gateway never appears
    /// here — a request recorded during a gateway case would be a bug.
    var authorizationRequests: [UNAuthorizationOptions] { lock.withLock { authorizationCalls } }

    /// The last `setNotificationCategories` argument — the centre keeps only the latest set.
    var registeredCategories: Set<UNNotificationCategory> { lock.withLock { categories } }

    /// Makes every subsequent `add` throw, the way the OS rejects a request it will not take.
    func failAdds(with error: any Error = FakeSchedulingError.requestRejected) {
        lock.withLock { addFailure = error }
    }

    func add(_ request: UNNotificationRequest) async throws {
        if let failure = lock.withLock({ addFailure }) {
            throw failure
        }
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

    /// What the next `requestAuthorization` answers — the user tapping Allow or Don't Allow.
    func grantAuthorization(_ granted: Bool) {
        lock.withLock { authorizationGrant = granted }
    }

    /// Makes every subsequent `requestAuthorization` throw, which is how the centre refuses to
    /// even ask (a second prompt in the same launch, a malformed options set).
    func failAuthorizationRequests(with error: any Error = FakeSchedulingError.requestRejected) {
        lock.withLock { authorizationFailure = error }
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        if let failure = lock.withLock({ authorizationFailure }) {
            lock.withLock { authorizationCalls.append(options) }
            throw failure
        }
        return lock.withLock {
            authorizationCalls.append(options)
            return authorizationGrant
        }
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
    private var scheduleFailure: (any Error)?

    /// Every attempt, refused ones included — so a test can tell "the gateway never asked" from
    /// "the gateway asked and was turned down".
    var scheduleCalls: [ScheduledAlarm] { lock.withLock { scheduled } }
    var cancelCalls: [Int32] { lock.withLock { cancelled } }

    /// Makes every subsequent `schedule` throw. AlarmKit refuses exactly this way when its
    /// authorization was never granted or has been revoked in Settings.
    func failSchedules(with error: any Error = FakeSchedulingError.alarmsNotAuthorized) {
        lock.withLock { scheduleFailure = error }
    }

    func schedule(
        requestCode: Int32,
        triggerAt: Date,
        content: ReminderNotificationContent,
        ref: ReminderRef
    ) async throws {
        if let failure = lock.withLock({ scheduleFailure }) {
            lock.withLock {
                scheduled.append(
                    ScheduledAlarm(requestCode: requestCode, triggerAt: triggerAt, content: content, ref: ref)
                )
            }
            throw failure
        }
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
