import SalusModel

/// The 13 persisted preference keys, spelled exactly as Android spells them.
///
/// Ported from `core/datastore/.../SalusPreferencesDataSource.kt:78-87` (the ten settings) and
/// `core/datastore/.../AiUsageDataSource.kt:118-120` (the three AI counters). Android reaches
/// them through typed `Preferences.Key` objects; on iOS the same strings are `UserDefaults` keys
/// — except `appLockEnabled`, which names a Keychain account instead (spec §5, see
/// `AppLockFlagStore`).
///
/// These are contract, not implementation detail: the backup format's `settings` block writes
/// them verbatim, so a key renamed here orphans every value the other platform already wrote.
/// A new key arrives with a new line in the pinning test, in the same commit (CLAUDE.md).
public enum SettingsKeys {
    public static let onboardingCompleted = "onboarding_completed"
    /// Keychain account, not a `UserDefaults` key — see `KeychainAppLockFlagStore`.
    public static let appLockEnabled = "app_lock_enabled"
    public static let secureScreenEnabled = "secure_screen_enabled"
    /// Re-exported rather than re-spelled: `ThemeMode` already carries its own storage key, so
    /// that `SalusDesignSystem` can read the persisted value without linking this package.
    public static let themeMode = ThemeMode.storageKey
    /// Re-exported for the same reason as `themeMode`.
    public static let premiumTheme = PremiumTheme.storageKey
    public static let glucoseUnit = "glucose_unit"
    public static let cycleReminderEnabled = "cycle_reminder_enabled"
    public static let cycleReminderLeadDays = "cycle_reminder_lead_days"
    public static let cycleReminderMinuteOfDay = "cycle_reminder_minute_of_day"
    public static let paywallIntroShown = "paywall_intro_shown"
    public static let aiFreeSummaryUsed = "ai_free_summary_used"
    public static let aiCallsCount = "ai_calls_count"
    public static let aiCallsEpochDay = "ai_calls_epoch_day"
}
