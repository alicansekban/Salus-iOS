// Ported 1:1 from
// `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/domain/AppLocaleController.kt`.
//
// The Kotlin file declares `AppLanguage` and `AppLocaleController` together, and so does this one.
// The enum's raw values are the Android constant names (`SYSTEM`/`TURKISH`/`ENGLISH`); they are
// **not** persisted by `SalusPreferencesDataSource` — the locale lives in the per-app language
// override, which on iOS is `UserDefaults`' `AppleLanguages` key and on Android is appcompat's
// `autoStoreLocales` — so the raw values are the names the `MoreViewModel` switches on rather than
// keys in the settings store. They are kept verbatim to match the Kotlin spelling.

/// The three language options the Settings screen offers
/// (`AppLocaleController.kt:3-7`).
///
/// `system` means "follow the device"; `turkish` and `english` are the two in-app overrides.
public enum AppLanguage: String, CaseIterable, Sendable {
    case system = "SYSTEM"
    case turkish = "TURKISH"
    case english = "ENGLISH"
}

/// Reads and applies the per-app language override
/// (`AppLocaleController.kt:14-20`).
///
/// **Recorded divergence (a)**, the iOS twin of `AppCompatLocaleController`: the controller stays a
/// protocol so the ViewModel stays testable without an `AppCompatDelegate` (Android) or a
/// `UserDefaults` (iOS) — both are framework classes that would defeat a plain host test. The iOS
/// implementation is `UserDefaultsAppLocaleController`, which writes the `AppleLanguages` key.
public protocol AppLocaleController: Sendable {
    /// `AppLocaleController.kt:15` — the currently applied language, or `system` when no override
    /// is set.
    func current() -> AppLanguage

    /// Applies the language. **The change takes effect on the next launch** (ruling 6, divergence
    /// (a)): `UserDefaults` writes are immediate, but the locale override is read at launch time
    /// by `UIApplication`, so the in-app strings flip when the app restarts — not the moment
    /// `apply(_:)` returns. Android's appcompat recreates the activity inline
    /// (`AppLocaleController.kt:18-19`); iOS does not, and the comment here is the only place that
    /// difference is written down.
    func apply(_ language: AppLanguage)
}
