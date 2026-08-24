// The twin of `feature/settings/src/main/res/values/strings.xml` (Turkish, the source language)
// and `feature/settings/src/main/res/values-en/strings.xml` — the `reminder_health_*` keys, name
// and text verbatim, resolved against this package's own bundle exactly as `R.string` resolves
// against `:feature:settings`.
//
// ROW MAPPING, and it is the reason the key list is not the Android key list. Android draws four
// health cards; iOS draws three, because two of Android's questions do not exist here and one iOS
// question does not exist there. `SystemReminderEnvironment` already records the same mapping on
// the reading side, member by member:
//
//   Android card                         iOS row                      Keys
//   ---------------------------------------------------------------------------------------------
//   Notifications                        Notifications                `reminder_health_notifications_*`,
//                                                                     verbatim.
//   Full-screen medication alarms        AlarmKit                     `reminder_health_full_screen_*`,
//   (`canUseFullScreenAlarms`)           (`alarmKitAuthorized`)       verbatim — the copy describes
//                                                                     the behaviour, which is the
//                                                                     same one on both platforms.
//   Exact alarms                         —                            DROPPED. iOS has no exact-alarm
//   (`canScheduleExactAlarms`)                                        permission: a scheduled
//                                                                     notification fires at its
//                                                                     trigger, so the row would be a
//                                                                     check that can never fail.
//   Battery optimization                 Background App Refresh       Android's copy names a
//   (`isIgnoringBatteryOptimizations`)   (`backgroundRefreshAvailable`) vendor-specific mechanism
//                                                                     that has no iOS reading, so
//                                                                     the row keeps the question and
//                                                                     gets iOS-only copy:
//                                                                     `reminder_health_background_refresh_*`.
//   —                                    Last reminder pass           iOS-ONLY. Android reads
//                                                                     WorkManager's run history;
//                                                                     iOS has no such ledger, so the
//                                                                     engine writes its own stamp and
//                                                                     the screen shows it
//                                                                     (`reminder_health_last_sync`,
//                                                                     `reminder_health_never_synced`).
//
// `reminder_health_back` is dropped with the `TopAppBar` that owned it: the shell's one
// `NavigationStack` draws the back button, so no screen in this port declares one
// (`docs/ios-feature-template.md`, Navigation).
//
// PLACEHOLDER MAPPING, the one place the port is not byte-for-byte. One key carries an argument:
//
//   Android      Swift        Key                          Why
//   ---------------------------------------------------------------------------------------------
//   %1$s         %1$@         reminder_health_last_sync    `%s` under `String(format:)` reads a C
//                                                          string pointer. Handed a Swift `String`
//                                                          it prints garbage or crashes; `%@` is
//                                                          the object form.
//
// (The key is iOS-only, so there is no Android sentence to keep — the row is here because the rule
// is the same for every argument this package ever adds.)
//
// TOOLCHAIN NOTE, and it costs an hour to rediscover: a `.xcstrings` catalog is compiled into
// `.lproj/Localizable.strings` by **Xcode's** build system only. Command-line `swift build` /
// `swift test` copies the catalog into the resource bundle verbatim, so a lookup under
// `swift test` finds no table and `String(localized:)` returns the key. The real app build
// (`scripts/build-app.sh`, xcodebuild) does compile it, which is where the translations appear.
// That is why the tests assert against the FILE and never against a resolved string; the
// end-to-end check is the simulator run.

import Foundation

/// The strings `:feature:settings` owns.
public enum SettingsStrings {
    public static var reminderHealthTitle: String { localized(.reminderHealthTitle) }
    public static var reminderHealthIntro: String { localized(.reminderHealthIntro) }
    public static var reminderHealthAllOk: String { localized(.reminderHealthAllOk) }
    public static var reminderHealthFix: String { localized(.reminderHealthFix) }

    public static var reminderHealthNotificationsTitle: String {
        localized(.reminderHealthNotificationsTitle)
    }

    public static var reminderHealthNotificationsOk: String {
        localized(.reminderHealthNotificationsOk)
    }

    public static var reminderHealthNotificationsProblem: String {
        localized(.reminderHealthNotificationsProblem)
    }

    public static var reminderHealthAlarmKitTitle: String { localized(.reminderHealthAlarmKitTitle) }
    public static var reminderHealthAlarmKitOk: String { localized(.reminderHealthAlarmKitOk) }

    public static var reminderHealthAlarmKitProblem: String {
        localized(.reminderHealthAlarmKitProblem)
    }

    public static var reminderHealthBackgroundRefreshTitle: String {
        localized(.reminderHealthBackgroundRefreshTitle)
    }

    public static var reminderHealthBackgroundRefreshOk: String {
        localized(.reminderHealthBackgroundRefreshOk)
    }

    public static var reminderHealthBackgroundRefreshProblem: String {
        localized(.reminderHealthBackgroundRefreshProblem)
    }

    public static var reminderHealthNeverSynced: String { localized(.reminderHealthNeverSynced) }

    // MARK: - Formatted strings

    /// `reminder_health_last_sync` — "Son hatırlatıcı taraması: %1$@" / "Last reminder pass: %1$@".
    public static func reminderHealthLastSync(_ timestamp: String) -> String {
        formatted(.reminderHealthLastSync, timestamp)
    }

    // MARK: - Keys

    /// The catalog keys, named once. Internal so the parity test can prove every accessor asks for
    /// a key the catalog really carries — a typo here would otherwise ship the key as the label.
    enum Key: String, CaseIterable {
        case reminderHealthTitle = "reminder_health_title"
        case reminderHealthIntro = "reminder_health_intro"
        case reminderHealthAllOk = "reminder_health_all_ok"
        case reminderHealthFix = "reminder_health_fix"
        case reminderHealthNotificationsTitle = "reminder_health_notifications_title"
        case reminderHealthNotificationsOk = "reminder_health_notifications_ok"
        case reminderHealthNotificationsProblem = "reminder_health_notifications_problem"
        case reminderHealthAlarmKitTitle = "reminder_health_full_screen_title"
        case reminderHealthAlarmKitOk = "reminder_health_full_screen_ok"
        case reminderHealthAlarmKitProblem = "reminder_health_full_screen_problem"
        case reminderHealthBackgroundRefreshTitle = "reminder_health_background_refresh_title"
        case reminderHealthBackgroundRefreshOk = "reminder_health_background_refresh_ok"
        case reminderHealthBackgroundRefreshProblem = "reminder_health_background_refresh_problem"
        case reminderHealthLastSync = "reminder_health_last_sync"
        case reminderHealthNeverSynced = "reminder_health_never_synced"
    }

    private static func localized(_ key: Key) -> String {
        String(localized: String.LocalizationValue(key.rawValue), bundle: .module)
    }

    /// Substitutes the single argument, in the device's locale.
    ///
    /// The locale is the current one rather than `nil` because that is what Android does:
    /// `Resources.getString(int, Object...)` formats with the configuration's locale.
    private static func formatted(_ key: Key, _ argument: CVarArg) -> String {
        String(format: localized(key), locale: .current, argument)
    }
}
