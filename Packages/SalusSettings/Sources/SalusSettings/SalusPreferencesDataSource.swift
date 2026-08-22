import Foundation
import SalusModel

/// Reads and writes the ten user settings, ported 1:1 from Android
/// `core/datastore/.../SalusPreferencesDataSource.kt`.
///
/// Android's backing store is a Preferences DataStore file; here it is `UserDefaults` for nine of
/// the ten settings and the Keychain for the tenth (`app_lock_enabled`, spec §5) — which is why
/// the flag store is a second injected dependency rather than a detail hidden inside. Keys and
/// stored spellings are Android-verbatim (`SettingsKeys`, and the enums' own raw values).
///
/// Synchronous where Kotlin is `suspend`: `DataStore.edit` suspends because it serialises a file
/// through a coroutine; `UserDefaults.set` is a synchronous, thread-safe write against an
/// in-memory domain that the system flushes. Making the setters `async` would buy nothing and
/// force every caller into a `Task`.
public final class SalusPreferencesDataSource: Sendable {
    /// `UserDefaults` is documented thread-safe but carries no `Sendable` annotation, so the
    /// exemption is spelled out on the one property that needs it rather than by making the whole
    /// class `@unchecked` — everything else here stays checked.
    ///
    /// Package-visible rather than `private` only because SwiftFormat and SwiftLint order
    /// `nonisolated(unsafe)` and `private` in opposite ways, and neither gate may be silenced.
    nonisolated(unsafe) let defaults: UserDefaults
    private let appLockFlagStore: any AppLockFlagStore
    private let values: DefaultsValueStream<UserSettings>

    /// - Parameters:
    ///   - defaults: the store; production passes `.standard`, tests a throwaway suite.
    ///   - appLockFlagStore: where `app_lock_enabled` really lives — `KeychainAppLockFlagStore`
    ///     in production, `InMemoryAppLockFlagStore` in tests and previews.
    public init(defaults: UserDefaults = .standard, appLockFlagStore: any AppLockFlagStore) {
        self.defaults = defaults
        self.appLockFlagStore = appLockFlagStore

        nonisolated(unsafe) let captured = defaults
        values = DefaultsValueStream {
            Self.read(from: captured, appLockFlagStore: appLockFlagStore)
        }
    }

    /// Every setting, re-read on each change — the twin of
    /// `SalusPreferencesDataSource.kt:20-35`.
    ///
    /// Emits the current value immediately, then once per actual change; see
    /// `DefaultsValueStream` for what "actual" means.
    public var userSettings: AsyncStream<UserSettings> {
        values.makeStream()
    }

    // MARK: - Setters (SalusPreferencesDataSource.kt:37-75)

    public func setThemeMode(_ mode: ThemeMode) {
        // Stored as the Kotlin constant name, because Android writes `mode.name` (:38).
        write(mode.rawValue, forKey: SettingsKeys.themeMode)
    }

    public func setAppLockEnabled(_ enabled: Bool) {
        appLockFlagStore.write(enabled)
        values.publish()
    }

    public func setSecureScreenEnabled(_ enabled: Bool) {
        write(enabled, forKey: SettingsKeys.secureScreenEnabled)
    }

    public func setOnboardingCompleted(_ completed: Bool) {
        write(completed, forKey: SettingsKeys.onboardingCompleted)
    }

    public func setGlucoseUnit(_ unit: GlucoseUnit) {
        write(unit.rawValue, forKey: SettingsKeys.glucoseUnit)
    }

    public func setCycleReminderEnabled(_ enabled: Bool) {
        write(enabled, forKey: SettingsKeys.cycleReminderEnabled)
    }

    public func setCycleReminderLeadDays(_ days: Int) {
        write(days, forKey: SettingsKeys.cycleReminderLeadDays)
    }

    public func setCycleReminderMinuteOfDay(_ minuteOfDay: Int) {
        write(minuteOfDay, forKey: SettingsKeys.cycleReminderMinuteOfDay)
    }

    public func setPaywallIntroShown(_ shown: Bool) {
        write(shown, forKey: SettingsKeys.paywallIntroShown)
    }

    public func setPremiumTheme(_ theme: PremiumTheme) {
        // `theme.name` on Android (:74).
        write(theme.rawValue, forKey: SettingsKeys.premiumTheme)
    }

    // MARK: - Private

    /// One write plus the re-emit every setter owes the stream.
    ///
    /// `UserDefaults.didChangeNotification` covers the standard domain, but a suite does not
    /// always post it, so the stream would be silent in exactly the configuration the tests run
    /// in. Publishing by hand makes the stream a property of this class rather than of the
    /// platform's notification behaviour.
    private func write(_ value: Any, forKey key: String) {
        defaults.set(value, forKey: key)
        values.publish()
    }

    /// The whole read, as one pure function of the two stores — `SalusPreferencesDataSource.kt:21-34`.
    ///
    /// `fallback` stands in for Kotlin's two spellings of the same thing: the booleans are
    /// written `?: false` (:23, :25, :27, :32) and the integers `?: UserSettings().x` (:28-31),
    /// and `UserSettings()` carries both. Enum values go through `fromStoredValue`, the twin of
    /// `toEnumOrDefault` (:89-90).
    private static func read(
        from defaults: UserDefaults,
        appLockFlagStore: any AppLockFlagStore
    ) -> UserSettings {
        let fallback = UserSettings()
        return UserSettings(
            themeMode: ThemeMode.fromStoredValue(defaults.string(forKey: SettingsKeys.themeMode)),
            appLockEnabled: appLockFlagStore.read(),
            secureScreenEnabled: defaults.storedBool(
                forKey: SettingsKeys.secureScreenEnabled,
                default: fallback.secureScreenEnabled
            ),
            onboardingCompleted: defaults.storedBool(
                forKey: SettingsKeys.onboardingCompleted,
                default: fallback.onboardingCompleted
            ),
            glucoseUnit: GlucoseUnit.fromStoredValue(defaults.string(forKey: SettingsKeys.glucoseUnit)),
            cycleReminderEnabled: defaults.storedBool(
                forKey: SettingsKeys.cycleReminderEnabled,
                default: fallback.cycleReminderEnabled
            ),
            cycleReminderLeadDays: defaults.storedInt(
                forKey: SettingsKeys.cycleReminderLeadDays,
                default: fallback.cycleReminderLeadDays
            ),
            cycleReminderMinuteOfDay: defaults.storedInt(
                forKey: SettingsKeys.cycleReminderMinuteOfDay,
                default: fallback.cycleReminderMinuteOfDay
            ),
            paywallIntroShown: defaults.storedBool(
                forKey: SettingsKeys.paywallIntroShown,
                default: fallback.paywallIntroShown
            ),
            premiumTheme: PremiumTheme.fromStoredValue(defaults.string(forKey: SettingsKeys.premiumTheme))
        )
    }
}
