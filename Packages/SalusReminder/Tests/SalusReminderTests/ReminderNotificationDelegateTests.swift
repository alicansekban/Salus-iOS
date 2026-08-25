// The delegation contract of `ReminderNotificationDelegate`, ported from Kotlin's
// `HandleReminderActionUseCase` (delegate to the handler, then re-sync) and `HandleFiredAlarmUseCase`
// (the window is refilled after the event, whatever the event turned out to be).
//
// Everything here goes through the delegate's internal seam rather than through
// `userNotificationCenter(_:didReceive:withCompletionHandler:)`. `UNNotificationResponse` and
// `UNNotification` both declare `init NS_UNAVAILABLE`, so a test cannot build the arguments the
// framework methods take; the two framework methods are one line each and forward to the seam, which
// holds the whole decision — the completion block's main thread included.

import Foundation
import SalusModel
import Testing
import UserNotifications

@testable import SalusReminder

/// Everything the delegate is allowed to reach out to, in the order it did so. Order is the point:
/// the handler must run BEFORE the window is refilled, or a snooze would be re-materialized from
/// state the handler has not written yet.
enum DelegateEvent: Equatable {
    case action(ReminderRef, String)
    case sync
    case open(ReminderRef)
}

/// A class with a lock because the delegate is `Sendable` and free to call any of its collaborators
/// from whichever executor the notification centre handed it.
final class DelegateEventLog: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [DelegateEvent] = []

    var recorded: [DelegateEvent] { lock.withLock { events } }

    func record(_ event: DelegateEvent) {
        lock.withLock { events.append(event) }
    }
}

/// Records `onAction` into the shared log, and optionally throws afterwards — the "a feature blew up
/// while reacting" case the delegate has to survive.
final class RecordingReminderHandler: ReminderHandler {
    let type: ReminderType

    private let log: DelegateEventLog
    private let failure: (any Error)?

    init(type: ReminderType, log: DelegateEventLog, failure: (any Error)? = nil) {
        self.type = type
        self.log = log
        self.failure = failure
    }

    func occurrencesBetween(from _: Date, until _: Date) async throws -> [ReminderOccurrence] {
        []
    }

    func notificationContent(for _: ReminderRef) async throws -> ReminderNotificationContent? {
        nil
    }

    func onAction(ref: ReminderRef, actionId: String) async throws {
        log.record(.action(ref, actionId))
        if let failure {
            throw failure
        }
    }
}

/// The window synchronizer, reduced to the one thing the delegate asks of it.
final class RecordingWindowSynchronizer: ReminderWindowSyncing {
    private let log: DelegateEventLog

    init(log: DelegateEventLog) {
        self.log = log
    }

    func sync() async {
        log.record(.sync)
    }
}

/// What a handler throws when the feature behind it fails.
struct HandlerFailure: Error {}

struct DelegateFixture {
    let log = DelegateEventLog()

    func delegate(handlers: [any ReminderHandler]) -> ReminderNotificationDelegate {
        let log = log
        return ReminderNotificationDelegate(
            handlerRegistry: ReminderHandlerRegistry(all: handlers),
            synchronizer: RecordingWindowSynchronizer(log: log),
            onOpen: { ref in log.record(.open(ref)) }
        )
    }

    func handler(_ type: ReminderType = .medicationDose, failing: (any Error)? = nil) -> RecordingReminderHandler {
        RecordingReminderHandler(type: type, log: log, failure: failing)
    }

    func ref(
        _ type: ReminderType = .medicationDose,
        _ entityId: String = "med-1",
        _ occurrenceKey: String = "2026-09-01T08:00"
    ) -> ReminderRef {
        ReminderRef(type: type, entityId: entityId, occurrenceKey: occurrenceKey)
    }

    /// The real payload the gateway writes, so a rename of a key breaks this suite too.
    func userInfo(for ref: ReminderRef) -> [AnyHashable: Any] {
        ReminderUserInfo.payload(for: ref)
    }

    /// Drives the delegate exactly as `userNotificationCenter(_:didReceive:withCompletionHandler:)`
    /// does — payload in, completion block awaited — so an assertion that follows always runs after
    /// the reaction has finished.
    ///
    /// - Returns: whether the completion block was called on the main thread, which is the one thing
    ///   UIKit asserts about it.
    @discardableResult
    func respond(
        _ delegate: ReminderNotificationDelegate,
        to userInfo: [AnyHashable: Any],
        actionIdentifier: String
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            delegate.respond(to: userInfo, actionIdentifier: actionIdentifier) {
                continuation.resume(returning: Thread.isMainThread)
            }
        }
    }
}

@Suite("ReminderNotificationDelegate")
struct ReminderNotificationDelegateTests {
    private let fixture = DelegateFixture()

    // MARK: - Notification actions

    /// `HandleReminderActionUseCase.kt:19-23`: the owning feature reacts first, and only then is the
    /// rolling window refilled — §6.1's "refill after every notification action" trigger. A snooze
    /// writes its new occurrence inside `onAction`, so a sync that ran first would miss it.
    @Test("an action tap reaches the owning handler and then refills the window, in that order")
    func actionDispatchesToHandlerBeforeSync() async {
        let ref = fixture.ref()
        let delegate = fixture.delegate(handlers: [fixture.handler()])

        await fixture.respond(delegate, to: fixture.userInfo(for: ref), actionIdentifier: "TAKEN")

        #expect(fixture.log.recorded == [.action(ref, "TAKEN"), .sync])
    }

    /// The system's own swipe-away arrives under `UNNotificationDismissActionIdentifier`, which the
    /// engine names ``ReminderActionIds/dismiss``. Handlers deliberately do not implement it, but the
    /// dispatch still happens: nothing else may invent a second spelling of the same action.
    @Test("a system dismiss arrives at the handler as the engine's own dismiss id")
    func dismissMapsToEngineActionId() async {
        let ref = fixture.ref(.appointment, "appt-4", "2026-10-02T09:30")
        let delegate = fixture.delegate(handlers: [fixture.handler(.appointment)])

        await fixture.respond(
            delegate,
            to: fixture.userInfo(for: ref),
            actionIdentifier: UNNotificationDismissActionIdentifier
        )

        #expect(fixture.log.recorded == [.action(ref, ReminderActionIds.dismiss), .sync])
    }

    /// Kotlin's `handler?.onAction(...)` — an unregistered type is a no-op, but the window is refilled
    /// regardless, because the sync is a property of the event, not of the handler.
    @Test("an action for a type no feature registered still refills the window")
    func actionWithoutHandlerStillSyncs() async {
        let delegate = fixture.delegate(handlers: [])

        await fixture.respond(delegate, to: fixture.userInfo(for: fixture.ref()), actionIdentifier: "TAKEN")

        #expect(fixture.log.recorded == [.sync])
    }

    /// A handler that throws is a bug in a feature, not a reason to lose the refill: the delegate has
    /// nobody to report to (the OS discards the error), so it swallows and carries on.
    @Test("a handler that throws does not stop the window from being refilled")
    func throwingHandlerStillSyncs() async {
        let ref = fixture.ref()
        let delegate = fixture.delegate(handlers: [fixture.handler(failing: HandlerFailure())])

        await fixture.respond(delegate, to: fixture.userInfo(for: ref), actionIdentifier: "SNOOZE")

        #expect(fixture.log.recorded == [.action(ref, "SNOOZE"), .sync])
    }

    // MARK: - Opening the app

    /// Tapping the notification body is navigation, not a reaction: no handler runs and no sync is
    /// requested. The app layer switches to the tab that hosts the type and pushes the detail key it
    /// has — an appointment since M4, a dose and a cycle period once M5 and M6 name theirs.
    @Test("a default tap only hands the ref to the open callback")
    func defaultTapRoutesToOnOpen() async {
        let ref = fixture.ref(.cyclePeriod, "cycle-1", "2026-09-14")
        let delegate = fixture.delegate(handlers: [fixture.handler(.cyclePeriod)])

        await fixture.respond(
            delegate,
            to: fixture.userInfo(for: ref),
            actionIdentifier: UNNotificationDefaultActionIdentifier
        )

        #expect(fixture.log.recorded == [.open(ref)])
    }

    // MARK: - Payloads the delegate cannot read

    /// A notification whose `userInfo` does not name an occurrence — a foreign notification, or one
    /// scheduled by a build whose keys have since changed. Nothing is dispatched and nothing crashes.
    @Test("a payload that names no occurrence is ignored")
    func unreadablePayloadIsIgnored() async {
        let ref = fixture.ref()
        let unreadable: [[AnyHashable: Any]] = [
            [:],
            ["some.other.app": "hello"],
            [ReminderUserInfo.type: "MEDICATION_DOSE", ReminderUserInfo.entityId: "med-1"],
            [
                ReminderUserInfo.type: "PAYMENT_DUE",
                ReminderUserInfo.entityId: "med-1",
                ReminderUserInfo.occurrenceKey: "2026-09-01T08:00"
            ],
            [
                ReminderUserInfo.type: 7,
                ReminderUserInfo.entityId: ref.entityId,
                ReminderUserInfo.occurrenceKey: ref.occurrenceKey
            ]
        ]

        for userInfo in unreadable {
            let delegate = fixture.delegate(handlers: [fixture.handler()])
            await fixture.respond(delegate, to: userInfo, actionIdentifier: "TAKEN")
            await fixture.respond(delegate, to: userInfo, actionIdentifier: UNNotificationDefaultActionIdentifier)
        }

        #expect(fixture.log.recorded.isEmpty)
    }

    // MARK: - The main-thread invariant

    /// UIKit finishes a notification response inside the completion block — the block reaches
    /// `-[UIApplication _updateSnapshotAndStateRestorationWithAction:windowScene:]`, which traps with
    /// `NSInternalInconsistencyException "Call must be made on main thread"` if it is called from
    /// anywhere else. The engine's own reaction is `async` and resumes on the cooperative pool, so
    /// hopping back is the delegate's job, and this test is the only thing standing behind it.
    @Test("the completion handler is called on the main thread, whatever executor the reaction ran on")
    func completionHandlerRunsOnTheMainThread() async {
        let delegate = fixture.delegate(handlers: [fixture.handler()])

        let onMainThread = await fixture.respond(
            delegate,
            to: fixture.userInfo(for: fixture.ref()),
            actionIdentifier: "TAKEN"
        )

        #expect(onMainThread)
    }

    /// The response has to be finished even when there is nothing to react to: iOS keeps the app
    /// awake until the block is called, and a payload it cannot read is the one path that dispatches
    /// nothing at all.
    @Test("a payload that names no occurrence still finishes the response")
    func unreadablePayloadStillCallsTheCompletionHandler() async {
        let delegate = fixture.delegate(handlers: [fixture.handler()])

        let onMainThread = await fixture.respond(
            delegate,
            to: ["some.other.app": "hello"],
            actionIdentifier: "TAKEN"
        )

        #expect(onMainThread)
        #expect(fixture.log.recorded.isEmpty)
    }

    // MARK: - Foreground presentation

    /// Android posts the notification even while the UI is open and lets Room observation update the
    /// screens; GRDB observation does the same here, so the banner is never suppressed.
    @Test("a reminder that fires while the app is open still banners, sounds and lands in the list")
    func foregroundPresentationShowsEverything() {
        #expect(ReminderNotificationDelegate.foregroundPresentationOptions == [.banner, .sound, .list])
    }
}
