// The iOS twin of Android's `ReminderActionReceiver` + `HandleReminderActionUseCase`
// (`core/reminder/src/main/kotlin/.../receiver/ReminderActionReceiver.kt`,
// `.../engine/HandleReminderActionUseCase.kt`), with the post-event refill of
// `HandleFiredAlarmUseCase.kt`.
//
// Android has code of its own running when a reminder fires: a BroadcastReceiver marks the ledger
// row, posts the notification, and a second receiver takes the action taps. iOS has none of that —
// the OS presents the request alone — so the whole of the engine's reaction happens here, when the
// user has already touched the notification, and it is a strictly smaller job:
//
//  * the ledger row and the notification content were settled at sync time
//    (`ReminderWindowSynchronizer`), so there is nothing left to mark or to bake;
//  * dismissing the notification is the OS's own doing, so Kotlin's `presenter.dismiss(alarm)` has
//    no line here — what remains of Kotlin's three steps is "delegate, then refill";
//  * the occurrence identity travels in `userInfo` rather than in a request code, so the dao lookup
//    Kotlin does is a parse (``ReminderUserInfo/ref(from:)``).
//
// Which leaves the two things this type genuinely owns: the delegation ORDER (handler first, refill
// second) and the deep-link seam for a plain tap.

import Foundation
import SalusModel
import UserNotifications

/// The one thing the delegate needs from ``ReminderWindowSynchronizer``: refill the window.
///
/// A protocol rather than the concrete type because the delegate's whole contract is *when* the
/// refill happens relative to the handler, and pinning an order needs a double that records it.
public protocol ReminderWindowSyncing: Sendable {
    /// Reconciles the rolling reminder window. Never throws — see the synchronizer's delta 5.
    func sync() async
}

extension ReminderWindowSynchronizer: ReminderWindowSyncing {}

/// Receives every user interaction with a fired reminder, and decides what the engine does about it.
///
/// Installed on `UNUserNotificationCenter.current().delegate` by the composition root, which also
/// supplies `onOpen` — the app layer is the only place that knows how to navigate.
public final class ReminderNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    /// What a reminder does when it fires while the app is in the foreground.
    ///
    /// Android posts the notification whether or not the UI is open and lets Room observation update
    /// whatever screen is showing (`HandleFiredAlarmUseCase.kt:9-11`); GRDB observation plays the same
    /// part here, so the banner is never suppressed in favour of an in-app affordance that a user
    /// looking at a different tab would never see.
    static let foregroundPresentationOptions: UNNotificationPresentationOptions = [.banner, .sound, .list]

    private let handlerRegistry: ReminderHandlerRegistry
    private let synchronizer: any ReminderWindowSyncing
    private let onOpen: @Sendable (ReminderRef) -> Void

    /// - Parameter onOpen: called on a plain tap, with the occurrence the notification was about.
    ///   The app layer switches to the tab that hosts the type and then pushes the detail key it has
    ///   — an appointment lands on its detail screen since M4; a dose and a cycle period stop at the
    ///   tab root until M5 and M6 give them a key to name.
    public init(
        handlerRegistry: ReminderHandlerRegistry,
        synchronizer: any ReminderWindowSyncing,
        onOpen: @escaping @Sendable (ReminderRef) -> Void
    ) {
        self.handlerRegistry = handlerRegistry
        self.synchronizer = synchronizer
        self.onOpen = onOpen
        super.init()
    }

    /// The framework's own spelling of "the user answered a notification", taken in its
    /// completion-handler form rather than the `async` one.
    ///
    /// Not a style choice. UIKit finishes a response inside the completion block — the block reaches
    /// `-[UIApplication _updateSnapshotAndStateRestorationWithAction:windowScene:]`, which traps with
    /// `NSInternalInconsistencyException "Call must be made on main thread"` — while the `async`
    /// requirement hands that block to a compiler-generated `@objc` thunk which calls it on whatever
    /// executor the async function last resumed on. That was the iOS-M3 defect: every tap on a Salus
    /// notification killed the app. Isolating the whole delegate to `@MainActor` would put the
    /// thunk's own resume back on the main thread, but it does not compile under Swift 6 — the
    /// requirement is not isolated, so `UNUserNotificationCenter`, `UNNotificationResponse` and
    /// `UNNotification` would each have to cross an isolation boundary and none of them is
    /// `Sendable`. Holding the block by hand is the shape that is left, and it is the honest one:
    /// which thread the block is called on is this type's promise, so it is made in code here rather
    /// than inferred from an annotation.
    public func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        respond(
            to: response.notification.request.content.userInfo,
            actionIdentifier: response.actionIdentifier,
            completionHandler: completionHandler
        )
    }

    public func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Returns `foregroundPresentationOptions` for every notification the OS hands this
        // delegate, not only ones the reminder engine scheduled — deliberate, because the engine
        // is the app's only notification scheduler today. If another subsystem ever posts its own
        // notifications, add a `ReminderUserInfo.ref(from:)` guard here so a non-reminder
        // notification does not inherit this engine's presentation choice.
        //
        // Answered synchronously, on the thread the OS called this on: the main-thread invariant
        // the other method has to work for holds here for free.
        completionHandler(Self.foregroundPresentationOptions)
    }

    /// The decision behind ``userNotificationCenter(_:didReceive:withCompletionHandler:)``, taken on
    /// the two values that method reads off the response, plus the block it has to finish with.
    ///
    /// It exists as a seam because `UNNotificationResponse` and `UNNotification` both declare
    /// `init NS_UNAVAILABLE`: a test cannot build one, and the alternative — reaching for the private
    /// `responseWithNotification:actionIdentifier:` initializer — would pin the suite to an
    /// implementation detail of the framework. So the framework method stays a one-line forward and
    /// everything worth asserting, the main-thread promise included, lives on this side of it.
    func respond(
        to userInfo: [AnyHashable: Any],
        actionIdentifier: String,
        completionHandler: @escaping () -> Void
    ) {
        // Parsed here, on the thread the framework called us on, because a `userInfo` dictionary is
        // not `Sendable` and must not cross into the task below. A payload that names no occurrence
        // — a notification we did not schedule, or one from a build whose keys have since changed —
        // reads as `nil`: nothing is dispatched and nothing is refilled, but the response is still
        // finished, because iOS holds the app awake until the block is called.
        let ref = ReminderUserInfo.ref(from: userInfo)
        // UIKit's block, non-`Sendable` only because that is how an Objective-C block imports. It is
        // called exactly once, from the main actor, after the reaction below has finished.
        nonisolated(unsafe) let completion = completionHandler
        Task {
            if let ref {
                await respond(to: ref, actionIdentifier: actionIdentifier)
            }
            await MainActor.run { completion() }
        }
    }

    /// The engine's reaction to one occurrence the user has answered.
    func respond(to ref: ReminderRef, actionIdentifier: String) async {
        guard actionIdentifier != UNNotificationDefaultActionIdentifier else {
            // A tap on the body is navigation, not a reaction. Nothing about the occurrence changed,
            // so no handler runs and the window has nothing to refill.
            onOpen(ref)
            return
        }

        // The system's own swipe-away reaches us under its framework identifier; the engine knows it
        // by one name only (`ReminderActionIds.dismiss`, the id the categories are registered with),
        // so it is translated before any feature sees it.
        let actionId = actionIdentifier == UNNotificationDismissActionIdentifier
            ? ReminderActionIds.dismiss
            : actionIdentifier

        // Kotlin's `handler?.onAction(...)`: an unregistered type is a no-op.
        if let handler = handlerRegistry.forType(ref.type) {
            do {
                try await handler.onAction(ref: ref, actionId: actionId)
            } catch {
                // The OS discards whatever we throw and there is no UI to report to, so a feature
                // that failed while reacting is absorbed here. The refill below still runs: it is a
                // property of the event having happened, not of the handler having succeeded, and
                // skipping it would leave the window short by one occurrence until the next sync.
            }
        }

        // `HandleReminderActionUseCase.kt:23` — a snooze materializes its new occurrence through the
        // handler, so the refill has to come AFTER the handler wrote it. §6.1's "refill after every
        // notification action" trigger.
        await synchronizer.sync()
    }
}
