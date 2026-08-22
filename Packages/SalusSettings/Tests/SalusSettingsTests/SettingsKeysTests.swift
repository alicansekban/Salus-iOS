import SalusModel
import Testing

@testable import SalusSettings

// Pinning test for the 13 persisted preference keys (CLAUDE.md "Port fidelity rules", spec §9).
//
// Source of truth, copied by hand into the literals below:
// `salus-android/core/datastore/.../SalusPreferencesDataSource.kt:78-87` (ten settings keys) and
// `salus-android/core/datastore/.../AiUsageDataSource.kt:118-120` (three AI usage keys).
//
// These strings are the backup format's `settings` block and the cross-platform contract: a key
// renamed here silently orphans every value Android already wrote. Nothing may "improve" them.

@Suite("Settings keys (Android parity)")
struct SettingsKeysTests {
    @Test("all 13 persisted keys are the Android strings, verbatim")
    func persistedKeys() {
        let keys = [
            SettingsKeys.onboardingCompleted,
            SettingsKeys.appLockEnabled,
            SettingsKeys.secureScreenEnabled,
            SettingsKeys.themeMode,
            SettingsKeys.premiumTheme,
            SettingsKeys.glucoseUnit,
            SettingsKeys.cycleReminderEnabled,
            SettingsKeys.cycleReminderLeadDays,
            SettingsKeys.cycleReminderMinuteOfDay,
            SettingsKeys.paywallIntroShown,
            SettingsKeys.aiFreeSummaryUsed,
            SettingsKeys.aiCallsCount,
            SettingsKeys.aiCallsEpochDay
        ]

        #expect(keys == [
            "onboarding_completed",
            "app_lock_enabled",
            "secure_screen_enabled",
            "theme_mode",
            "premium_theme",
            "glucose_unit",
            "cycle_reminder_enabled",
            "cycle_reminder_lead_days",
            "cycle_reminder_minute_of_day",
            "paywall_intro_shown",
            "ai_free_summary_used",
            "ai_calls_count",
            "ai_calls_epoch_day"
        ])
    }

    @Test("the two theme keys keep their single home in SalusModel")
    func themeKeysAreNotDuplicated() {
        // `ThemeMode`/`PremiumTheme` already carry the key they are persisted under, because the
        // design system reads them without linking this package. `SettingsKeys` points at those
        // rather than repeating the literal — one home per key, one place to get it wrong.
        #expect(SettingsKeys.themeMode == ThemeMode.storageKey)
        #expect(SettingsKeys.premiumTheme == PremiumTheme.storageKey)
    }
}
