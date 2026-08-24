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
    ///   In iOS-M3 the app layer routes it to the matching tab root; the detail-screen push arrives
    ///   with the M4/M5 navigation keys.
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

    public func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await respond(
            to: response.notification.request.content.userInfo,
            actionIdentifier: response.actionIdentifier
        )
    }

    public func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification
    ) async -> UNNotificationPresentationOptions {
        Self.foregroundPresentationOptions
    }

    /// The decision behind ``userNotificationCenter(_:didReceive:)``, taken on the two values that
    /// method reads off the response.
    ///
    /// It exists as a seam because `UNNotificationResponse` and `UNNotification` both declare
    /// `init NS_UNAVAILABLE`: a test cannot build one, and the alternative — reaching for the private
    /// `responseWithNotification:actionIdentifier:` initializer — would pin the suite to an
    /// implementation detail of the framework. So the framework method stays a one-line forward and
    /// everything worth asserting lives on this side of it.
    func respond(to userInfo: [AnyHashable: Any], actionIdentifier: String) async {
        // A notification we did not schedule, or one from a build whose keys have since changed:
        // there is no occurrence to react to, so nothing is dispatched and nothing is refilled.
        guard let ref = ReminderUserInfo.ref(from: userInfo) else { return }

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
