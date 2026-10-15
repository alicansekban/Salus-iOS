// The iOS twin of Android
// `core/reminder/src/main/kotlin/.../engine/AndroidReminderEnvironment.kt`, answering the three
// questions ``ReminderEnvironment`` re-read for this platform — plus the two the user can be asked
// to fix, which Android answers by sending the user to a settings Intent and iOS answers with a
// runtime prompt.
//
// Nothing here decides anything: the answers feed the synchronizer's FIRED/MISSED settlement and
// Reminder Health's three rows (iOS-M3 Task 8), and this type's whole job is to read the platform
// honestly — including saying "no" when it cannot read at all.

import Foundation
import UserNotifications

/// Prompting the user for the two authorizations the reminder pipeline depends on.
///
/// Separate from ``ReminderEnvironment``, which is a read-only view of device state and the port of
/// Android's read-only interface: asking is a user-visible action with a once-per-install prompt
/// behind it, and only Reminder Health's fix buttons ever take it. Nothing in the engine may.
public protocol ReminderAuthorizationRequesting: Sendable {
    /// Shows the system notification prompt if it has not been shown, and reports whether
    /// notifications ended up authorized. False when the user declines, and also when the prompt
    /// could not be shown at all (it has already been answered — the fix is Settings, which is
    /// where Reminder Health sends a user whose answer was no).
    func requestNotificationAuthorization() async -> Bool

    /// The same for AlarmKit, whose prompt is what lets a medication dose take over the screen.
    /// Always false below iOS 26.0: `SystemAlarmKitScheduler` is `@available(iOS 26.0, *)`, so
    /// below that there is no AlarmKit to authorize and the dose takes the documented
    /// time-sensitive fallback. (What 26.1 changes is only the alert's stop button — the system
    /// supplies it from 26.1 up, the app supplies "Kapat" on 26.0.)
    func requestAlarmKitAuthorization() async -> Bool
}

/// What the app runs on.
public final class SystemReminderEnvironment: ReminderEnvironment, @unchecked Sendable {
    /// What the app asks for. `.timeSensitive` is deliberately absent: the dose alarm's
    /// interruption level comes from the
    /// `com.apple.developer.usernotifications.time-sensitive` entitlement (`project.yml`), not from
    /// an authorization option, and asking for one that does not exist would fail the whole request.
    public static let notificationOptions: UNAuthorizationOptions = [.alert, .sound, .badge]

    private let center: any UserNotificationCenting
    private let alarmKit: (any AlarmKitAuthorizing)?
    private let backgroundRefreshStatus: @MainActor @Sendable () -> Bool

    /// - Parameters:
    ///   - center: the notification centre seam.
    ///   - alarmKit: the AlarmKit authorization backend, or nil where there is none. Its presence
    ///     IS the "iOS 26.0+" answer, exactly as the alarm scheduler's presence is for
    ///     ``UserNotificationGateway`` — the composition root builds one behind `#available`, so
    ///     nothing below this line version-checks.
    ///   - backgroundRefreshStatus: the app layer's read of `UIApplication.backgroundRefreshStatus`.
    ///     Called on every ``backgroundRefreshAvailable()`` and never here. See that member.
    public init(
        center: any UserNotificationCenting,
        alarmKit: (any AlarmKitAuthorizing)? = nil,
        backgroundRefreshStatus: @escaping @MainActor @Sendable () -> Bool
    ) {
        self.center = center
        self.alarmKit = alarmKit
        self.backgroundRefreshStatus = backgroundRefreshStatus
    }

    /// `areNotificationsEnabled()` (`AndroidReminderEnvironment.kt:14-15`).
    ///
    /// Provisional and ephemeral authorization both count: they deliver, quietly, which is what the
    /// synchronizer is asking about when it settles a past-due row. Settings that cannot be read
    /// count as NOT authorized — see the type doc: guessing "delivered" would tell the user a
    /// reminder reached them when nobody knows whether it did.
    public func notificationsAuthorized() async -> Bool {
        guard let settings = await center.notificationSettings() else { return false }
        switch settings.authorizationStatus {
        case .authorized, .ephemeral, .provisional: return true
        default: return false
        }
    }

    /// The iOS replacement for `canUseFullScreenAlarms()` (`AndroidReminderEnvironment.kt:29-33`):
    /// there, a permission that only exists from API 34; here, a framework that only exists from
    /// iOS 26.0 plus a runtime authorization inside it.
    public func alarmKitAuthorized() async -> Bool {
        await alarmKit?.isAuthorized() ?? false
    }

    /// The iOS replacement for `isIgnoringBatteryOptimizations()`
    /// (`AndroidReminderEnvironment.kt:22-25`): both answer "will the OS let us run when the app is
    /// not open?".
    ///
    /// A live read on the main actor, where `UIApplication` can be read, and never a stored
    /// sample. This used to be a snapshot taken when the composition root was built inside
    /// `App.init`, before launch finished. There the status did not yet read `.available`, and on a
    /// cold start Home asked before the foreground re-sample landed. So the readiness card claimed
    /// background refresh was off on every launch, while Reminder Health, opened later, said
    /// everything was fine.
    public func backgroundRefreshAvailable() async -> Bool {
        await backgroundRefreshStatus()
    }
}

/// The prompting half, in an extension of its own so the two roles read as the two roles they are —
/// and so the type line stays one line.
extension SystemReminderEnvironment: ReminderAuthorizationRequesting {
    public func requestNotificationAuthorization() async -> Bool {
        // A throwing request means the prompt could not be shown, which is not authorization; the
        // caller's next `notificationsAuthorized()` reports what the state really is.
        await (try? center.requestAuthorization(options: Self.notificationOptions)) ?? false
    }

    public func requestAlarmKitAuthorization() async -> Bool {
        await alarmKit?.requestAuthorization() ?? false
    }
}
