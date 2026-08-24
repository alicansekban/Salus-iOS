// The iOS twin of Android's `AndroidAlarmGateway`
// (`core/reminder/src/main/kotlin/.../engine/AndroidAlarmGateway.kt`), fused with the job
// `ReminderNotificationPresenter` does there.
//
// Android splits the two: `AndroidAlarmGateway` sets an empty alarm, and when it fires a receiver
// wakes up and asks `ReminderNotificationPresenter` to build the notification. iOS runs no code of
// ours at fire time, so the two halves collapse into this one type — the request handed to the OS
// at sync time already carries the title, the body, the actions and the identity, because there is
// no later moment in which to add them.
//
// What each half contributes:
//
//  * From `AndroidAlarmGateway`: scheduling by request code, and the property that scheduling the
//    same code twice REPLACES rather than duplicates (there, re-using a PendingIntent request code;
//    here, re-using a notification identifier). That is what makes the synchronizer's
//    "re-schedule every desired occurrence, every pass" strategy idempotent.
//  * From `ReminderNotificationPresenter`: the identity extras (``ReminderUserInfo``, the
//    `ReminderIntentExtras` twin), the action wiring, and the branch on
//    `ReminderPresentation.alarm` — which hands the occurrence to a different mechanism entirely
//    rather than posting it here (`AlarmService` there, ``AlarmKitScheduling`` here).
//
// The presentation routing is spec's 2026-08-23 AlarmKit note:
//
//  * `.alarm` on iOS 26+ → AlarmKit. A real system alarm, and NOT a pending notification, so it
//    does not spend one of the 64 slots §6.1's window math is written against.
//  * `.alarm` below 26 → a notification with `interruptionLevel = .timeSensitive` (an auto-approved
//    capability) and a custom sound. Silent mode still silences it: accepted degradation. Critical
//    Alerts are deliberately not used — the entitlement needs a case-by-case Apple application with
//    no timeline guarantee.
//  * `.notification` → a plain request with the default sound, whatever the OS version.
//
// The decision is never taken from `ReminderType`: presentation is handler-owned, and this type
// reads it off the content it was given.

import Foundation
import SalusModel
import UserNotifications

/// The bundled alarm sound, shared by both `.alarm` paths.
public enum ReminderAlarmSound {
    /// The file as it sits in the app bundle. iOS ignores a custom sound longer than 30 s and
    /// falls back to the default one silently, so the asset is generated — and length-checked — by
    /// `scripts/generate-alarm-sound.sh`.
    public static let fileName = "salus_alarm.caf"
}

/// The notification categories the engine registers, one per ``ReminderType``.
///
/// A category is how a `UNNotificationRequest` carries buttons: the request names a category, and
/// the category — registered separately, app-wide — holds the actions. One per reminder type is
/// the natural grain, because the handler that owns a type declares the same actions for every
/// occurrence of it.
public enum ReminderNotificationCategories {
    /// Stable across launches, because it is written into every scheduled request and has to still
    /// mean something when that request fires days later.
    public static func identifier(for type: ReminderType) -> String {
        "salus.reminder.\(type.rawValue)"
    }

    static func category(for type: ReminderType, actions: [ReminderAction]) -> UNNotificationCategory {
        UNNotificationCategory(
            identifier: identifier(for: type),
            // No `.foreground`: Android answers a reminder action in a BroadcastReceiver without
            // showing UI, and the iOS twin of that is a background action handled by the
            // notification-centre delegate (Task 6).
            actions: actions.map { UNNotificationAction(identifier: $0.id, title: $0.label, options: []) },
            intentIdentifiers: [],
            // Swiping a reminder away is how a user silences it without answering it, and
            // ``ReminderActionIds/dismiss`` is the engine's reaction to that. iOS delivers it only
            // to a category that asked for it.
            options: [.customDismissAction]
        )
    }
}

/// The ``NotificationGateway`` the app runs on.
public final class UserNotificationGateway: NotificationGateway {
    /// What iOS actually enforces: at most 64 pending notification requests per app, with the rest
    /// dropped silently. §6.1 caps the window at 60 to leave four slots for anything scheduled
    /// outside the engine.
    public static let systemPendingBudget = 64

    /// The default tripwire. `assertionFailure` is a debug-only trap on purpose: crossing the
    /// budget is a bug in the window math, it cannot be recovered from at this level, and in a
    /// shipped build the reminders that still fit must keep working.
    public static let reportOverflowByAssertion: @Sendable (Int) -> Void = { count in
        assertionFailure(
            "Reminder engine holds \(count) pending notification requests, over the \(systemPendingBudget) "
                + "iOS keeps. The window cap in ReminderWindowConfig is supposed to make this unreachable."
        )
    }

    private let center: any UserNotificationCenting
    private let alarmScheduler: (any AlarmKitScheduling)?
    private let onPendingBudgetExceeded: @Sendable (Int) -> Void
    private let categories = CategoryRegistry()

    /// - Parameters:
    ///   - center: the notification centre seam.
    ///   - alarmScheduler: the alarm backend, or nil where there is none. Its presence IS the
    ///     "iOS 26+" answer: the composition root builds one behind `#available`, so nothing below
    ///     this line has to ask the OS version, and a routing test says "this device rings alarms"
    ///     by passing a double.
    ///   - onPendingBudgetExceeded: what to do when the budget is crossed, given the pending count.
    ///     Injected because the default is an `assertionFailure`, which a test cannot survive.
    public init(
        center: any UserNotificationCenting,
        alarmScheduler: (any AlarmKitScheduling)? = nil,
        onPendingBudgetExceeded: @escaping @Sendable (Int) -> Void = UserNotificationGateway
            .reportOverflowByAssertion
    ) {
        self.center = center
        self.alarmScheduler = alarmScheduler
        self.onPendingBudgetExceeded = onPendingBudgetExceeded
    }

    public func schedule(
        requestCode: Int32,
        triggerAt: Date,
        content: ReminderNotificationContent,
        ref: ReminderRef
    ) async throws {
        // "Adds — or replaces — the request for `requestCode`" is the gateway's contract, and with
        // two backends behind it that has to mean replacing in BOTH: a handler that changed an
        // occurrence's presentation would otherwise leave the previous backend still holding it,
        // and the user would be told twice.
        if content.presentation == .alarm, let alarmScheduler {
            await center.removePendingNotificationRequests(withIdentifiers: [String(requestCode)])
            try await alarmScheduler.schedule(
                requestCode: requestCode,
                triggerAt: triggerAt,
                content: content,
                ref: ref
            )
            return
        }

        await alarmScheduler?.cancel(requestCodes: [requestCode])
        await registerCategoryIfChanged(actions: content.actions, for: ref.type)
        try await center.add(
            UNNotificationRequest(
                identifier: String(requestCode),
                content: notificationContent(content, ref: ref),
                trigger: trigger(at: triggerAt)
            )
        )
        await reportOverflowIfNeeded()
    }

    public func cancel(requestCodes: [Int32]) async {
        guard !requestCodes.isEmpty else { return }

        // The ledger records the request code, never which backend scheduled it — and it does not
        // need to: the code addresses the request in the centre AND derives the AlarmKit id, so
        // both are told and whichever holds the occurrence drops it. Neither treats an unknown
        // code as an error.
        await center.removePendingNotificationRequests(withIdentifiers: requestCodes.map(String.init))
        await alarmScheduler?.cancel(requestCodes: requestCodes)
    }

    public func pendingRequestCodes() async -> Set<Int32> {
        var codes = await Set(center.pendingNotificationRequests().compactMap { Int32($0.identifier) })
        if let alarmScheduler {
            await codes.formUnion(alarmScheduler.scheduledRequestCodes())
        }
        return codes
    }

    // MARK: - Request construction

    private func notificationContent(
        _ content: ReminderNotificationContent,
        ref: ReminderRef
    ) -> UNMutableNotificationContent {
        let notification = UNMutableNotificationContent()
        notification.title = content.title
        notification.body = content.text
        notification.userInfo = ReminderUserInfo.payload(for: ref)
        notification.categoryIdentifier = ReminderNotificationCategories.identifier(for: ref.type)

        switch content.presentation {
        case .notification:
            notification.sound = .default
        case .alarm:
            // Reached only where there is no alarm backend — spec's AlarmKit note, case 2.
            notification.sound = UNNotificationSound(named: UNNotificationSoundName(ReminderAlarmSound.fileName))
            notification.interruptionLevel = .timeSensitive
        }
        return notification
    }

    /// The occurrence's instant, decomposed into the wall-clock components `UNCalendarNotificationTrigger`
    /// takes.
    ///
    /// This is the second and last kind of place `Calendar` is allowed to appear in this tree
    /// (`CLAUDE.md`'s `LocalDate` rule, whose carve-out is the instant↔day boundary in
    /// `SalusClock`): it is a boundary conversion into an OS API that accepts nothing else, not day
    /// arithmetic. It keeps the discipline that carve-out sets — a fixed **Gregorian** calendar
    /// rather than `Calendar.current`, which follows the device's region setting and would decompose
    /// the same instant into a different year — and reads the zone at CALL time, so a reminder
    /// re-scheduled after the user flies somewhere is decomposed in the zone they are now in.
    private func trigger(at date: Date) -> UNCalendarNotificationTrigger {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date),
            repeats: false
        )
    }

    // MARK: - Categories and budget

    private func registerCategoryIfChanged(actions: [ReminderAction], for type: ReminderType) async {
        guard let updated = categories.categories(recording: actions, for: type) else { return }

        // `setNotificationCategories` replaces the whole registered set, so the registry hands back
        // every type's category rather than the one that changed.
        await center.setNotificationCategories(updated)
    }

    /// Asks the centre what it is actually holding, rather than counting what this process
    /// scheduled: the budget is over the app's pending requests, which outlive the process and
    /// include anything scheduled outside the engine — the four slots §6.1 leaves free.
    private func reportOverflowIfNeeded() async {
        let count = await center.pendingNotificationRequests().count
        guard count > Self.systemPendingBudget else { return }

        onPendingBudgetExceeded(count)
    }
}

/// Which actions are registered for which reminder type, so the whole set can be rebuilt when one
/// type's actions change — and so the centre is not asked to re-register an unchanged set on every
/// one of a sync's sixty schedules.
private final class CategoryRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var actionsByType: [ReminderType: [ReminderAction]] = [:]

    /// The full category set if `actions` changed what is registered for `type`, nil if it did not.
    func categories(recording actions: [ReminderAction], for type: ReminderType) -> Set<UNNotificationCategory>? {
        lock.withLock {
            guard actionsByType[type] != actions else { return nil }

            actionsByType[type] = actions
            return Set(actionsByType.map { ReminderNotificationCategories.category(for: $0.key, actions: $0.value) })
        }
    }
}
