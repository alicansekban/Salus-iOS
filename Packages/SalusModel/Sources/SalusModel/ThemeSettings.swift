// The two theme settings, ported 1:1 from Android
// `core/model/src/main/kotlin/com/alicansekban/salus/core/model/Settings.kt`.
//
// They live here, in the pure-domain layer, exactly as they do on Android: `:core:model` links
// no UI framework, and `:core:designsystem` depends on `:core:model`, never the reverse. The
// settings store that reads and writes them (`SalusSettings`, M1) must not have to link SwiftUI
// to know which mode the user picked.
//
// Everything below is String raw values and Bool logic — no SwiftUI, no UIKit. The two pieces
// that need a framework or the token layer are extensions in `SalusDesignSystem`:
// `ThemeMode.preferredColorScheme` and `PremiumTheme.accentPalette(dark:)`.
//
// The names are deliberately unprefixed — `ThemeMode` and `PremiumTheme` are Salus's own domain
// vocabulary, spelled exactly as Kotlin spells them.
//
// Persistence is not this package's business either. What is pinned here is the wire format, so
// that whatever writes the values in M1 is byte-compatible with Android: DataStore stores
// `mode.name` / `theme.name` — the Kotlin constant names themselves — under the two string keys
// carried as `storageKey`.

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
}
