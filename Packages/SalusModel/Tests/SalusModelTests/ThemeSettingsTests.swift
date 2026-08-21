import Testing

@testable import SalusModel

// Pinning tests for the theme settings vocabulary.
//
// Source of truth, copied by hand into the literals below:
// `salus-android/core/model/.../model/Settings.kt:3-15` for the constants, and
// `salus-android/core/datastore/.../SalusPreferencesDataSource.kt:38,74,78,87,89-90` for how
// they are persisted and read back. DataStore stores `mode.name` / `theme.name`, so the Kotlin
// constant names ARE the stored strings and the Swift raw values must match them verbatim.
//
// Resolution (mode + palette -> tokens) is pinned by `SalusThemeTests` in `SalusDesignSystem`;
// what is asserted here is only the part that carries no UI framework.

/// One mode-resolution row: the stored mode, what the OS reports, and the expected outcome.
typealias ThemeModeRow = (mode: ThemeMode, systemIsDark: Bool, expectedDark: Bool)

/// One decoding row: the raw string DataStore could hold, and the value it must decode to.
typealias StoredModeRow = (stored: String?, expected: ThemeMode)

@Suite("Theme vocabulary (Android parity)")
struct ThemeVocabularyTests {
    @Test("ThemeMode raw values are the Kotlin enum constant names, in declaration order")
    func themeModeRawValues() {
        // Settings.kt:3-7
        #expect(ThemeMode.allCases.map(\.rawValue) == ["SYSTEM", "LIGHT", "DARK"])
    }

    @Test("PremiumTheme raw values are the Kotlin enum constant names, in declaration order")
    func premiumThemeRawValues() {
        // Settings.kt:10-15
        #expect(PremiumTheme.allCases.map(\.rawValue) == ["CLASSIC", "OCEAN", "SUNSET", "FOREST"])
    }

    @Test("the DataStore preference keys are carried verbatim")
    func preferenceKeys() {
        // SalusPreferencesDataSource.kt:78 / :87
        #expect(ThemeMode.storageKey == "theme_mode")
        #expect(PremiumTheme.storageKey == "premium_theme")
    }

    @Test("the defaults are the UserSettings defaults")
    func defaults() {
        // Settings.kt:18 / :33
        #expect(ThemeMode.default == .system)
        #expect(PremiumTheme.default == .classic)
    }

    @Test(
        "an unknown or absent stored string falls back to the default, case-sensitively",
        arguments: [
            ("SYSTEM", ThemeMode.system),
            ("LIGHT", ThemeMode.light),
            ("DARK", ThemeMode.dark),
            // `toEnumOrDefault` matches `it.name == value` — no case folding.
            ("light", ThemeMode.system),
            ("MIDNIGHT", ThemeMode.system),
            ("", ThemeMode.system),
            (nil, ThemeMode.system),
        ] as [StoredModeRow]
    )
    func decodeStoredMode(_ row: StoredModeRow) {
        // SalusPreferencesDataSource.kt:89-90
        #expect(
            ThemeMode.fromStoredValue(row.stored) == row.expected,
            "stored \(row.stored ?? "nil")"
        )
    }

    @Test("premium palettes decode the same way")
    func decodeStoredPremiumTheme() {
        #expect(PremiumTheme.fromStoredValue("FOREST") == .forest)
        #expect(PremiumTheme.fromStoredValue("forest") == .classic)
        #expect(PremiumTheme.fromStoredValue(nil) == .classic)
    }
}

@Suite("Mode resolution (Theme.kt:87)")
struct ThemeModeResolutionTests {
    @Test(
        "the stored mode wins over the system, SYSTEM follows it",
        arguments: [
            (ThemeMode.system, false, false),
            (ThemeMode.system, true, true),
            (ThemeMode.light, false, false),
            (ThemeMode.light, true, false),
            (ThemeMode.dark, false, true),
            (ThemeMode.dark, true, true),
        ] as [ThemeModeRow]
    )
    func isDark(_ row: ThemeModeRow) {
        #expect(
            row.mode.isDark(systemIsDark: row.systemIsDark) == row.expectedDark,
            "\(row.mode.rawValue) with systemIsDark=\(row.systemIsDark)"
        )
    }
}
