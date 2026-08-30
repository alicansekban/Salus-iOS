// The iOS twin of
// `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/data/AppCompatLocaleController.kt`
// — **recorded divergence (a)**, ruling 6.
//
// Android stores the per-app language override in appcompat's `autoStoreLocales`
// (`AppCompatDelegate.getApplicationLocales` / `setApplicationLocales`), and applies it inline by
// recreating the activity. iOS has no AppCompat: the per-app language override is the
// `AppleLanguages` key in `UserDefaults`, which `UIApplication` reads **at launch time** to pick
// the bundle's localization. Writing the key changes what the *next* launch resolves; the running
// app's strings do not flip until it restarts. That is the divergence, and it is the only one: the
// three cases map one-to-one onto the Kotlin's three `LocaleListCompat` branches
// (`AppCompatLocaleController.kt:23-27`).
//
// `UserDefaults` carries no `Sendable` annotation, so the one property that needs the exemption
// spells it out rather than making the whole class `@unchecked` — the same shape
// `SalusPreferencesDataSource.swift:33` uses.

import Foundation

/// ``AppLocaleController`` backed by the `AppleLanguages` `UserDefaults` key.
///
/// The twin of Android's `AppCompatLocaleController`:
///
/// | `AppLanguage` | Kotlin `LocaleListCompat`        | iOS `AppleLanguages` |
/// | ------------- | -------------------------------- | -------------------- |
/// | `system`      | `getEmptyLocaleList()`           | key removed          |
/// | `turkish`     | `forLanguageTags("tr")`          | `["tr"]`             |
/// | `english`     | `forLanguageTags("en")`          | `["en"]`             |
///
/// `current()` reads the key and maps it back: an absent key is `system` (the device language
/// applies), `["tr"]` is `turkish`, `["en"]` is `english`, and anything else falls back to `system`
/// — the twin of the Kotlin `else -> AppLanguage.ENGLISH` arm, narrowed to `system` because iOS's
/// `AppleLanguages` is an array and an unknown entry means the override was set by something other
/// than this screen, so the honest answer is "no override we recognise".
public final class UserDefaultsAppLocaleController: AppLocaleController {
    /// `UserDefaults` is documented thread-safe but carries no `Sendable` annotation, so the
    /// exemption is spelled out on the one property that needs it rather than by making the whole
    /// class `@unchecked` — everything else here stays checked.
    nonisolated(unsafe) let defaults: UserDefaults

    /// - Parameter defaults: the store; production passes `.standard`, tests a throwaway suite.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func current() -> AppLanguage {
        // `object(forKey:)` distinguishes "absent" from "stored `[]`"; `array(forKey:)` collapses
        // the two, which would turn a removed key into an empty array and mis-map it. The
        // appcompat twin does the same with `locales.isEmpty`.
        guard let languages = defaults.object(forKey: Self.appleLanguagesKey) as? [String] else {
            return .system
        }
        switch languages.first {
        case "tr": return .turkish
        case "en": return .english
        default: return .system
        }
    }

    public func apply(_ language: AppLanguage) {
        switch language {
        case .system:
            // The twin of `LocaleListCompat.getEmptyLocaleList()` — removing the key lets the
            // device language apply on the next launch.
            defaults.removeObject(forKey: Self.appleLanguagesKey)
        case .turkish:
            defaults.set(["tr"], forKey: Self.appleLanguagesKey)
        case .english:
            defaults.set(["en"], forKey: Self.appleLanguagesKey)
        }
    }

    /// The `UserDefaults` key the system reads at launch to pick the bundle's localization.
    /// Hard-coded rather than a `SettingsKeys` entry because it is not one of the 13 settings keys
    /// the backup format pins (spec §9) — it is a framework-owned key, never written by
    /// `SalusPreferencesDataSource`.
    private static let appleLanguagesKey = "AppleLanguages"
}
