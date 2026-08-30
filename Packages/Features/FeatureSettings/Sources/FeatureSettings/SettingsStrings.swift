// The twin of `feature/settings/src/main/res/values/strings.xml` (Turkish, the source language)
// and `feature/settings/src/main/res/values-en/strings.xml` — every key `:feature:settings` owns,
// name and text verbatim, resolved against this package's own bundle exactly as `R.string` resolves
// against `:feature:settings`.
//
// ROW MAPPING, and it is the reason the key list is not the Android key list. The catalog carries
// 87 keys today: the 15 `reminder_health_*` keys that shipped with iOS-M3, plus the 72 More / About
// / Profile / settings keys the M8 settings hub adds. Android draws four health cards; iOS draws
// three, because two of Android's questions do not exist here and one iOS question does not exist
// there. `SystemReminderEnvironment` already records the same mapping on the reading side, member
// by member:
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
//   —                                    Last reminder pass           IOS-ONLY. Android reads
//                                                                     WorkManager's run history;
//                                                                     iOS has no such ledger, so the
//                                                                     engine writes its own stamp and
//                                                                     the screen shows it
//                                                                     (`reminder_health_last_sync`,
//                                                                     `reminder_health_never_synced`).
//
// Nine Android keys are dropped entirely, none silently. The five `reminder_health_*` ones
// (`reminder_health_exact_*`, `reminder_health_battery_*`, `reminder_health_back`) are dropped
// with the cards above; `settings_back` and `profile_back` are dropped with the `TopAppBar` that
// owned them: the shell's one `NavigationStack` draws the back button, so no screen in this port
// declares one (`docs/ios-feature-template.md`, Navigation). Each dropped key is recorded as a
// divergence (d) in the task report rather than carried over.
//
// PLACEHOLDER MAPPING, the one place the port is not byte-for-byte. Two keys carry an argument:
//
//   Android      Swift        Key                          Why
//   ---------------------------------------------------------------------------------------------
//   %1$s         %1$@         reminder_health_last_sync    `%s` under `String(format:)` reads a C
//   %1$s         %1$@         about_version                string pointer. Handed a Swift `String`
//                                                          it prints garbage or crashes; `%@` is
//                                                          the object form.
//
// The sentence around the specifier never changes.
//
// `more_cycle` and `more_cycle_subtitle` move here from the App target's catalog with M8: they
// describe the More tab's Cycle row, which the settings hub now draws, and a key lives with the
// feature that renders it.
//
// TOOLCHAIN NOTE, and it costs an hour to rediscover: a `.xcstrings` catalog is compiled into
// `.lproj/Localizable.strings` by **Xcode's** build system only. Command-line `swift build` /
// `swift test` copies the catalog into the resource bundle verbatim, so a lookup under
// `swift test` finds no table and `String(localized:)` returns the key. The real app build
// (`scripts/build-app.sh`, xcodebuild) does compile it, which is where the translations appear.
// That is why the tests assert against the FILE and never against a resolved string; the
// end-to-end check is the simulator run.

import Foundation
import SalusModel

/// The strings `:feature:settings` owns.
public enum SettingsStrings {
    // MARK: - Reminder health

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

    // MARK: - More hub

    public static var moreTitle: String { localized(.moreTitle) }
    public static var moreCycle: String { localized(.moreCycle) }
    public static var moreCycleSubtitle: String { localized(.moreCycleSubtitle) }
    public static var moreSectionTracking: String { localized(.moreSectionTracking) }
    public static var moreProfile: String { localized(.moreProfile) }
    public static var moreProfileIncomplete: String { localized(.moreProfileIncomplete) }
    public static var moreTrends: String { localized(.moreTrends) }
    public static var moreTrendsSubtitle: String { localized(.moreTrendsSubtitle) }

    // MARK: - Settings rows

    public static var settingsTheme: String { localized(.settingsTheme) }
    public static var settingsLanguage: String { localized(.settingsLanguage) }
    public static var settingsNotifications: String { localized(.settingsNotifications) }
    public static var settingsNotificationsDesc: String { localized(.settingsNotificationsDesc) }
    public static var settingsReminders: String { localized(.settingsReminders) }
    public static var settingsRemindersDesc: String { localized(.settingsRemindersDesc) }
    public static var settingsAbout: String { localized(.settingsAbout) }
    public static var settingsAboutDesc: String { localized(.settingsAboutDesc) }
    public static var settingsCancel: String { localized(.settingsCancel) }
    public static var settingsPremium: String { localized(.settingsPremium) }
    public static var settingsPremiumActive: String { localized(.settingsPremiumActive) }
    public static var settingsPremiumPromo: String { localized(.settingsPremiumPromo) }
    public static var settingsSectionAppearance: String { localized(.settingsSectionAppearance) }
    public static var settingsSectionNotifications: String { localized(.settingsSectionNotifications) }
    public static var settingsSectionApp: String { localized(.settingsSectionApp) }
    public static var settingsSectionSecurity: String { localized(.settingsSectionSecurity) }
    public static var settingsAppLock: String { localized(.settingsAppLock) }
    public static var settingsAppLockDesc: String { localized(.settingsAppLockDesc) }
    public static var settingsAppLockUnavailable: String { localized(.settingsAppLockUnavailable) }
    public static var settingsAppLockConfirmTitle: String { localized(.settingsAppLockConfirmTitle) }
    public static var settingsSecureScreen: String { localized(.settingsSecureScreen) }
    public static var settingsSecureScreenDesc: String { localized(.settingsSecureScreenDesc) }
    public static var settingsColorTheme: String { localized(.settingsColorTheme) }
    public static var settingsDoctorReport: String { localized(.settingsDoctorReport) }
    public static var settingsDoctorReportDesc: String { localized(.settingsDoctorReportDesc) }

    // MARK: - Theme dialog

    public static var themeTitle: String { localized(.themeTitle) }
    public static var themeSystem: String { localized(.themeSystem) }
    public static var themeLight: String { localized(.themeLight) }
    public static var themeDark: String { localized(.themeDark) }

    // MARK: - Language dialog

    public static var languageTitle: String { localized(.languageTitle) }
    public static var languageSystem: String { localized(.languageSystem) }
    public static var languageTurkish: String { localized(.languageTurkish) }
    public static var languageEnglish: String { localized(.languageEnglish) }

    // MARK: - Color theme dialog

    public static var colorThemeClassic: String { localized(.colorThemeClassic) }
    public static var colorThemeOcean: String { localized(.colorThemeOcean) }
    public static var colorThemeSunset: String { localized(.colorThemeSunset) }
    public static var colorThemeForest: String { localized(.colorThemeForest) }

    // MARK: - About

    public static var aboutTitle: String { localized(.aboutTitle) }
    public static var aboutAppName: String { localized(.aboutAppName) }
    public static var aboutDescription: String { localized(.aboutDescription) }
    public static var aboutPrivacyTitle: String { localized(.aboutPrivacyTitle) }
    public static var aboutPrivacyBody: String { localized(.aboutPrivacyBody) }

    // MARK: - Profile

    public static var profileTitle: String { localized(.profileTitle) }
    public static var profileSave: String { localized(.profileSave) }
    public static var profileName: String { localized(.profileName) }
    public static var profileNamePlaceholder: String { localized(.profileNamePlaceholder) }
    public static var profileSex: String { localized(.profileSex) }
    public static var profileSexFemale: String { localized(.profileSexFemale) }
    public static var profileSexMale: String { localized(.profileSexMale) }
    public static var profileSexOther: String { localized(.profileSexOther) }
    public static var profileSexCycleDisappears: String { localized(.profileSexCycleDisappears) }
    public static var profileSexCycleAppears: String { localized(.profileSexCycleAppears) }
    public static var profileSexConfirmTitle: String { localized(.profileSexConfirmTitle) }
    public static var profileSexConfirmBody: String { localized(.profileSexConfirmBody) }
    public static var profileSexConfirmOk: String { localized(.profileSexConfirmOk) }
    public static var profileSexConfirmCancel: String { localized(.profileSexConfirmCancel) }
    public static var profileBirthDate: String { localized(.profileBirthDate) }
    public static var profileBirthDateSelect: String { localized(.profileBirthDateSelect) }
    public static var profileHeight: String { localized(.profileHeight) }
    public static var profileHeightPlaceholder: String { localized(.profileHeightPlaceholder) }
    public static var profileHeightInvalid: String { localized(.profileHeightInvalid) }
    public static var profileHealthNotes: String { localized(.profileHealthNotes) }
    public static var profileHealthNotesPlaceholder: String { localized(.profileHealthNotesPlaceholder) }

    // MARK: - Formatted strings

    /// `reminder_health_last_sync` — "Son hatırlatıcı taraması: %1$@" / "Last reminder pass: %1$@".
    public static func reminderHealthLastSync(_ timestamp: String) -> String {
        formatted(.reminderHealthLastSync, timestamp)
    }

    /// `about_version` — "Sürüm %1$@" / "Version %1$@".
    public static func aboutVersion(_ version: String) -> String {
        formatted(.aboutVersion, version)
    }

    // MARK: - Enum-typed dialog labels

    /// `theme_*` — the dialog option label for each `ThemeMode`.
    public static func theme(_ mode: ThemeMode) -> String {
        switch mode {
        case .system: themeSystem
        case .light: themeLight
        case .dark: themeDark
        }
    }

    /// `color_theme_*` — the dialog option label for each `PremiumTheme`.
    public static func colorTheme(_ theme: PremiumTheme) -> String {
        switch theme {
        case .classic: colorThemeClassic
        case .ocean: colorThemeOcean
        case .sunset: colorThemeSunset
        case .forest: colorThemeForest
        }
    }

    // MARK: - Keys

    /// The catalog keys, named once. Internal so the parity test can prove every accessor asks for
    /// a key the catalog really carries — a typo here would otherwise ship the key as the label.
    enum Key: String, CaseIterable {
        case aboutAppName = "about_app_name"
        case aboutDescription = "about_description"
        case aboutPrivacyBody = "about_privacy_body"
        case aboutPrivacyTitle = "about_privacy_title"
        case aboutTitle = "about_title"
        case aboutVersion = "about_version"
        case colorThemeClassic = "color_theme_classic"
        case colorThemeForest = "color_theme_forest"
        case colorThemeOcean = "color_theme_ocean"
        case colorThemeSunset = "color_theme_sunset"
        case languageEnglish = "language_english"
        case languageSystem = "language_system"
        case languageTitle = "language_title"
        case languageTurkish = "language_turkish"
        case moreCycle = "more_cycle"
        case moreCycleSubtitle = "more_cycle_subtitle"
        case moreProfile = "more_profile"
        case moreProfileIncomplete = "more_profile_incomplete"
        case moreSectionTracking = "more_section_tracking"
        case moreTitle = "more_title"
        case moreTrends = "more_trends"
        case moreTrendsSubtitle = "more_trends_subtitle"
        case profileBirthDate = "profile_birth_date"
        case profileBirthDateSelect = "profile_birth_date_select"
        case profileHealthNotes = "profile_health_notes"
        case profileHealthNotesPlaceholder = "profile_health_notes_placeholder"
        case profileHeight = "profile_height"
        case profileHeightInvalid = "profile_height_invalid"
        case profileHeightPlaceholder = "profile_height_placeholder"
        case profileName = "profile_name"
        case profileNamePlaceholder = "profile_name_placeholder"
        case profileSave = "profile_save"
        case profileSex = "profile_sex"
        case profileSexCycleAppears = "profile_sex_cycle_appears"
        case profileSexCycleDisappears = "profile_sex_cycle_disappears"
        case profileSexConfirmBody = "profile_sex_confirm_body"
        case profileSexConfirmCancel = "profile_sex_confirm_cancel"
        case profileSexConfirmOk = "profile_sex_confirm_ok"
        case profileSexConfirmTitle = "profile_sex_confirm_title"
        case profileSexFemale = "profile_sex_female"
        case profileSexMale = "profile_sex_male"
        case profileSexOther = "profile_sex_other"
        case profileTitle = "profile_title"
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
        case settingsAbout = "settings_about"
        case settingsAboutDesc = "settings_about_desc"
        case settingsAppLock = "settings_app_lock"
        case settingsAppLockConfirmTitle = "settings_app_lock_confirm_title"
        case settingsAppLockDesc = "settings_app_lock_desc"
        case settingsAppLockUnavailable = "settings_app_lock_unavailable"
        case settingsCancel = "settings_cancel"
        case settingsColorTheme = "settings_color_theme"
        case settingsDoctorReport = "settings_doctor_report"
        case settingsDoctorReportDesc = "settings_doctor_report_desc"
        case settingsLanguage = "settings_language"
        case settingsNotifications = "settings_notifications"
        case settingsNotificationsDesc = "settings_notifications_desc"
        case settingsPremium = "settings_premium"
        case settingsPremiumActive = "settings_premium_active"
        case settingsPremiumPromo = "settings_premium_promo"
        case settingsReminders = "settings_reminders"
        case settingsRemindersDesc = "settings_reminders_desc"
        case settingsSectionApp = "settings_section_app"
        case settingsSectionAppearance = "settings_section_appearance"
        case settingsSectionNotifications = "settings_section_notifications"
        case settingsSectionSecurity = "settings_section_security"
        case settingsSecureScreen = "settings_secure_screen"
        case settingsSecureScreenDesc = "settings_secure_screen_desc"
        case settingsTheme = "settings_theme"
        case themeDark = "theme_dark"
        case themeLight = "theme_light"
        case themeSystem = "theme_system"
        case themeTitle = "theme_title"
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
