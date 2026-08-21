import SwiftUI

// The two theme settings, ported 1:1 from Android `core/model/.../model/Settings.kt`.
//
// On Android these enums live in `:core:model`, not `:core:designsystem`. They sit here for M0
// because the iOS `SalusModel` package is still a placeholder and the theme resolution below is
// their only consumer; when `SalusSettings` arrives in M1 they move to `SalusModel` and this
// package keeps importing them. Nothing about their shape changes when they move.
//
// The names are deliberately unprefixed — `ThemeMode` and `PremiumTheme` are Salus's own domain
// vocabulary and are spelled exactly as Kotlin spells them, unlike `SalusColorScheme`, which
// carries a prefix only because SwiftUI already owns the name `ColorScheme`.
//
// Persistence is NOT this package's business (no storage in M0). What is pinned here is the
// wire format, so that whatever writes the values in M1 is byte-compatible with Android:
// DataStore stores `mode.name` / `theme.name` — the Kotlin constant names themselves —
// under the two string keys carried as `storageKey`.

/// Which color scheme the user asked for.
///
/// Raw values are the Kotlin constant names (`Settings.kt:3-7`), which are what
/// `SalusPreferencesDataSource.setThemeMode` persists (`SalusPreferencesDataSource.kt:38`).
public enum ThemeMode: String, CaseIterable, Equatable, Sendable {
    case system = "SYSTEM"
    case light = "LIGHT"
    case dark = "DARK"

    /// The DataStore key the value is stored under (`SalusPreferencesDataSource.kt:78`).
    public static let storageKey = "theme_mode"

    /// `UserSettings.themeMode`'s default (`Settings.kt:18`).
    public static let `default`: ThemeMode = .system

    /// Decodes a persisted string the way Android's `toEnumOrDefault` does
    /// (`SalusPreferencesDataSource.kt:89-90`): an exact, case-sensitive constant-name match,
    /// and anything else — including a missing value — falls back to the default.
    public static func fromStoredValue(_ stored: String?) -> ThemeMode {
        guard let stored, let mode = ThemeMode(rawValue: stored) else { return .default }
        return mode
    }

    /// Whether the dark scheme is drawn, given what the OS currently reports.
    ///
    /// Mirrors `Theme.kt:87`, where `darkTheme` defaults to `isSystemInDarkTheme()` and an
    /// explicit mode overrides it.
    public func isDark(systemIsDark: Bool) -> Bool {
        switch self {
        case .system: systemIsDark
        case .light: false
        case .dark: true
        }
    }

    /// The value to hand SwiftUI's `.preferredColorScheme`: `nil` for `SYSTEM`, so the OS keeps
    /// deciding — the iOS shape of `isSystemInDarkTheme()` being the Android default.
    public var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// The premium-only color palettes; `classic` is the free Salus brand theme.
///
/// Raw values are the Kotlin constant names (`Settings.kt:10-15`), persisted by
/// `SalusPreferencesDataSource.setPremiumTheme` (`SalusPreferencesDataSource.kt:74`).
public enum PremiumTheme: String, CaseIterable, Equatable, Sendable {
    case classic = "CLASSIC"
    case ocean = "OCEAN"
    case sunset = "SUNSET"
    case forest = "FOREST"

    /// The DataStore key the value is stored under (`SalusPreferencesDataSource.kt:87`).
    public static let storageKey = "premium_theme"

    /// `UserSettings.premiumTheme`'s default (`Settings.kt:33`), and the default every preview
    /// and test draws on (`Theme.kt:95`).
    public static let `default`: PremiumTheme = .classic

    /// Decodes a persisted string exactly as `ThemeMode.fromStoredValue` does.
    public static func fromStoredValue(_ stored: String?) -> PremiumTheme {
        guard let stored, let theme = PremiumTheme(rawValue: stored) else { return .default }
        return theme
    }

    /// The eight accent roles this palette paints, in the given theme (§4).
    ///
    /// `classic` returns the brand accents, which is why applying it is a no-op.
    public func accentPalette(dark: Bool) -> SalusPremiumAccentPalette {
        switch self {
        case .classic: dark ? SalusPremiumAccents.classicDark : SalusPremiumAccents.classicLight
        case .ocean: dark ? SalusPremiumAccents.oceanDark : SalusPremiumAccents.oceanLight
        case .sunset: dark ? SalusPremiumAccents.sunsetDark : SalusPremiumAccents.sunsetLight
        case .forest: dark ? SalusPremiumAccents.forestDark : SalusPremiumAccents.forestLight
        }
    }
}
