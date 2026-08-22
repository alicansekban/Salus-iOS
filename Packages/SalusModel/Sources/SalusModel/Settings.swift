// Ported 1:1 from Android
// `core/model/src/main/kotlin/com/alicansekban/salus/core/model/Settings.kt:17-34`.
//
// `ThemeMode` and `PremiumTheme` — the other two declarations of the same Kotlin file — already
// live in `ThemeSettings.swift`, where they arrived with M0 alongside their storage keys. They
// are not repeated here; this file holds only the aggregate.

/// Everything the settings store holds, with Android's defaults.
///
/// Every parameter of `init` defaults to the Kotlin default, so `UserSettings()` is the exact
/// twin of Kotlin's `UserSettings()` — which is what the store returns before anything has been
/// written. Field order follows `Settings.kt:18-33`.
public struct UserSettings: Equatable, Hashable, Sendable {
    public let themeMode: ThemeMode
    public let appLockEnabled: Bool
    /// On Android this sets `FLAG_SECURE`. On iOS it is the *masking* toggle of spec §6.2 — the
    /// app-switcher blur is always on, and this adds screenshot masking on top of it.
    public let secureScreenEnabled: Bool
    public let onboardingCompleted: Bool
    public let glucoseUnit: GlucoseUnit
    /// Opt-in period-start reminder derived from cycle predictions (never for LOW confidence).
    public let cycleReminderEnabled: Bool
    /// Days before the predicted start; 0 = the predicted day itself.
    public let cycleReminderLeadDays: Int
    /// Local time of day for the reminder, as minuteOfDay.
    public let cycleReminderMinuteOfDay: Int
    /// True once the one-shot paywall intro has been shown, so it never opens again.
    public let paywallIntroShown: Bool
    /// Selected premium palette; only applied while the user is premium.
    public let premiumTheme: PremiumTheme

    public init(
        themeMode: ThemeMode = .system,
        appLockEnabled: Bool = false,
        secureScreenEnabled: Bool = false,
        onboardingCompleted: Bool = false,
        glucoseUnit: GlucoseUnit = .mgDl,
        cycleReminderEnabled: Bool = false,
        cycleReminderLeadDays: Int = 1,
        cycleReminderMinuteOfDay: Int = 9 * 60,
        paywallIntroShown: Bool = false,
        premiumTheme: PremiumTheme = .classic
    ) {
        self.themeMode = themeMode
        self.appLockEnabled = appLockEnabled
        self.secureScreenEnabled = secureScreenEnabled
        self.onboardingCompleted = onboardingCompleted
        self.glucoseUnit = glucoseUnit
        self.cycleReminderEnabled = cycleReminderEnabled
        self.cycleReminderLeadDays = cycleReminderLeadDays
        self.cycleReminderMinuteOfDay = cycleReminderMinuteOfDay
        self.paywallIntroShown = paywallIntroShown
        self.premiumTheme = premiumTheme
    }
}
