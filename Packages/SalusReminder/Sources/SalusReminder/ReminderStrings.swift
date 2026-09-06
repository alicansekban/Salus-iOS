// The twin of `core/reminder/src/main/res/values/strings.xml` (Turkish, the source language) and
// `core/reminder/src/main/res/values-en/strings.xml`, resolved against this package's own bundle
// exactly as `R.string` resolves against `:core:reminder`.
//
// The module's whole copy surface, and it is small on purpose: the engine bakes every reminder's
// own text from the handler that owns the occurrence (`ReminderNotificationContent`), so what is
// left here is only what the engine and the surfaces that *steer* the user share —
//
//   * `alarm_dismiss`, the label on the button that silences a fired reminder without resolving it
//     — Android's, appended to the alarm's actions in `AlarmService.kt:87` and drawn under them in
//     `AlarmScreen.kt:153`;
//   * one `reminder_problem_*` line per ``ReminderProblem`` (reached through ``ReminderProblem/reason``),
//     and the `reminder_fix` / `reminder_not_now` pair a "reminders will not work" dialog answers
//     with. They live here rather than in `:feature:settings` because the surfaces that need them
//     — the medication editor, Home — must not depend on a feature module to say one sentence.
//
// The three problem lines are a **copy** of the `reminder_health_*_problem` wording settings draws
// on its own Reminder health screen, not a move: settings keeps its keys and this module gets its
// own, so neither depends on the other. Two of the three keys are Android-verbatim
// (`…_notifications_off`, `…_full_screen_denied`) even where the Swift accessor is named for the
// iOS mechanism, which is the convention `SettingsStrings` already set
// (`reminderHealthAlarmKitProblem = "reminder_health_full_screen_problem"`). The third is this
// platform's own: Background App Refresh is an iOS switch with no Android twin, so
// `reminder_problem_background_refresh_off` is coined here exactly as
// `reminder_health_background_refresh_problem` was — Android's `…_background_restricted` and
// `…_battery_optimized` describe different settings and are never reported by ``ReminderProblem``.
//
// TOOLCHAIN NOTE, and it costs an hour to rediscover: a `.xcstrings` catalog is compiled into
// `.lproj/Localizable.strings` by **Xcode's** build system only. Command-line `swift build` /
// `swift test` copies the catalog into the resource bundle verbatim, so a lookup under `swift test`
// finds no table and `String(localized:)` returns the key. The real app build
// (`scripts/build-app.sh`, xcodebuild) does compile it, which is where the translations appear.
// That is why `ReminderStringsTests` asserts against the FILE and never against a resolved string;
// the end-to-end check is the simulator run.

import Foundation
import SalusCommon

/// The strings `:core:reminder` owns.
public enum ReminderStrings {
    /// `alarm_dismiss` — "Kapat" / "Dismiss". The label on the answer that silences a fired
    /// reminder and leaves the occurrence unresolved (``ReminderActionIds/dismiss``).
    public static var alarmDismiss: String { localized(.alarmDismiss) }

    // MARK: - Problem reasons

    /// `reminder_problem_notifications_off` — the one-line reason behind
    /// ``ReminderProblem/notificationsOff``. Reached through ``ReminderProblem/reason``.
    public static var reminderProblemNotificationsOff: String {
        localized(.reminderProblemNotificationsOff)
    }

    /// `reminder_problem_full_screen_denied` — the one-line reason behind
    /// ``ReminderProblem/alarmKitDenied``. Reached through ``ReminderProblem/reason``.
    public static var reminderProblemAlarmKitDenied: String {
        localized(.reminderProblemAlarmKitDenied)
    }

    /// `reminder_problem_background_refresh_off` — the one-line reason behind
    /// ``ReminderProblem/backgroundRefreshOff``. Reached through ``ReminderProblem/reason``.
    public static var reminderProblemBackgroundRefreshOff: String {
        localized(.reminderProblemBackgroundRefreshOff)
    }

    // MARK: - Dialog answers

    /// `reminder_fix` — "Düzelt" / "Fix". The answer that takes the user to Reminder health.
    public static var reminderFix: String { localized(.reminderFix) }

    /// `reminder_not_now` — "Şimdi değil" / "Not now". The answer that dismisses the warning and
    /// changes nothing.
    public static var reminderNotNow: String { localized(.reminderNotNow) }

    // MARK: - Keys

    /// The catalog keys, named once. Internal so the parity test can prove every accessor asks for
    /// a key the catalog really carries — a typo here would otherwise ship the key as the label.
    enum Key: String, CaseIterable {
        case alarmDismiss = "alarm_dismiss"
        case reminderFix = "reminder_fix"
        case reminderNotNow = "reminder_not_now"
        case reminderProblemAlarmKitDenied = "reminder_problem_full_screen_denied"
        case reminderProblemBackgroundRefreshOff = "reminder_problem_background_refresh_off"
        case reminderProblemNotificationsOff = "reminder_problem_notifications_off"
    }

    private static func localized(_ key: Key) -> String {
        SalusLocalization.string(key.rawValue, bundle: .module)
    }
}
