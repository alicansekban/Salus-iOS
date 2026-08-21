import SalusModel
import SwiftUI
import Testing

@testable import SalusDesignSystem

// Pinning tests for theme resolution: mode + palette -> the tokens that get drawn.
//
// Source of truth, copied by hand into the literals below:
// `salus-android/core/designsystem/.../theme/Theme.kt:86-104` and
// `PremiumThemeColors.kt:103-120`, tabulated in `docs/design/design-tokens.md` §4 / §4.5.
//
// The vocabulary itself — raw values, storage keys, decoding, `isDark(systemIsDark:)` — is pure
// domain and lives in `SalusModel`; `ThemeSettingsTests` there pins it. What is asserted here is
// only what needs the token layer or SwiftUI.
//
// The token values are pinned by `SalusDesignTokensTests`; the tables below assert that
// *resolution* lands on them, plus a handful of doc hexes so a swapped palette is caught even if
// a token were mis-transcribed on both sides.

/// One palette row: palette, theme, and two doc hexes that identify it unambiguously.
typealias PaletteRow = (
    palette: PremiumTheme,
    dark: Bool,
    primary: UInt32,
    onSecondaryContainer: UInt32
)

@Suite("Mode resolution, SwiftUI side (Theme.kt:87)")
struct ThemeModePresentationTests {
    @Test("SYSTEM defers to SwiftUI, the explicit modes override it")
    func preferredColorScheme() {
        // The SwiftUI mirror of `isSystemInDarkTheme()` being the Android default.
        #expect(ThemeMode.system.preferredColorScheme == nil)
        #expect(ThemeMode.light.preferredColorScheme == .light)
        #expect(ThemeMode.dark.preferredColorScheme == .dark)
    }
}

@Suite("Premium palette resolution (§4, PremiumThemeColors.kt:103-120)")
struct PremiumPaletteResolutionTests {
    /// The doc's §4.1–§4.4 tables, one identifying row per palette and theme.
    static let rows: [PaletteRow] = [
        (.classic, false, 0x3E_7D5F, 0x0E_1F17),
        (.classic, true, 0x8B_D6B2, 0xD3_E8DB),
        (.ocean, false, 0x0E_7490, 0x06_1F29),
        (.ocean, true, 0x5F_D4F0, 0xCD_E7F2),
        (.sunset, false, 0xB4_491F, 0x2C_160D),
        (.sunset, true, 0xFF_B598, 0xFF_DBCF),
        (.forest, false, 0x2E_6B27, 0x12_1F0E),
        (.forest, true, 0x95_D888, 0xD7_E8CD),
    ]

    @Test("each palette repaints the accent roles with its own §4 values", arguments: rows)
    func accentRoles(_ row: PaletteRow) {
        let scheme = SalusTheme.colorScheme(dark: row.dark, premiumTheme: row.palette)
        let label = "\(row.palette.rawValue) dark=\(row.dark)"
        #expect(scheme.primary == Color(hex: row.primary), "\(label) primary")
        #expect(
            scheme.onSecondaryContainer == Color(hex: row.onSecondaryContainer),
            "\(label) onSecondaryContainer"
        )
    }

    @Test("all eight accent roles come from the palette", arguments: rows)
    func allEightAccentRoles(_ row: PaletteRow) {
        let scheme = SalusTheme.colorScheme(dark: row.dark, premiumTheme: row.palette)
        let palette = row.palette.accentPalette(dark: row.dark)
        #expect(scheme.primary == palette.primary)
        #expect(scheme.onPrimary == palette.onPrimary)
        #expect(scheme.primaryContainer == palette.primaryContainer)
        #expect(scheme.onPrimaryContainer == palette.onPrimaryContainer)
        #expect(scheme.secondary == palette.secondary)
        #expect(scheme.onSecondary == palette.onSecondary)
        #expect(scheme.secondaryContainer == palette.secondaryContainer)
        #expect(scheme.onSecondaryContainer == palette.onSecondaryContainer)
    }

    @Test("nothing outside the eight accent roles moves", arguments: rows)
    func nonAccentRolesUnchanged(_ row: PaletteRow) {
        let base = row.dark ? SalusColorScheme.dark : SalusColorScheme.light
        let scheme = SalusTheme.colorScheme(dark: row.dark, premiumTheme: row.palette)
        let label = "\(row.palette.rawValue) dark=\(row.dark)"
        #expect(scheme.tertiary == base.tertiary, "\(label) tertiary")
        #expect(scheme.tertiaryContainer == base.tertiaryContainer, "\(label) tertiaryContainer")
        #expect(scheme.error == base.error, "\(label) error")
        #expect(scheme.errorContainer == base.errorContainer, "\(label) errorContainer")
        #expect(scheme.background == base.background, "\(label) background")
        #expect(scheme.surface == base.surface, "\(label) surface")
        #expect(scheme.surfaceVariant == base.surfaceVariant, "\(label) surfaceVariant")
        #expect(scheme.outline == base.outline, "\(label) outline")
        #expect(scheme.outlineVariant == base.outlineVariant, "\(label) outlineVariant")
        #expect(scheme.inversePrimary == base.inversePrimary, "\(label) inversePrimary")
        #expect(scheme.scrim == base.scrim, "\(label) scrim")
        #expect(
            scheme.surfaceContainerHighest == base.surfaceContainerHighest,
            "\(label) surfaceContainerHighest"
        )
    }

    @Test("CLASSIC returns the brand scheme untouched")
    func classicIsIdentity() {
        // PremiumThemeColors.kt:105 — `CLASSIC -> return this`.
        #expect(
            SalusTheme.colorScheme(dark: false, premiumTheme: .classic) == SalusColorScheme.light
        )
        #expect(
            SalusTheme.colorScheme(dark: true, premiumTheme: .classic) == SalusColorScheme.dark
        )
    }

    @Test("the palettes are distinct from one another in both themes")
    func palettesAreDistinct() {
        for dark in [false, true] {
            let primaries = PremiumTheme.allCases.map {
                SalusTheme.colorScheme(dark: dark, premiumTheme: $0).primary
            }
            #expect(Set(primaries).count == PremiumTheme.allCases.count, "dark=\(dark)")
        }
    }
}

@Suite("SalusTheme.resolve (Theme.kt:86-104)")
struct SalusThemeResolutionTests {
    @Test("the resolved theme carries the scheme, the extended colors and the dark flag")
    func resolvesEverything() {
        let resolved = SalusTheme.resolve(
            mode: .system,
            premiumTheme: .ocean,
            systemIsDark: true
        )
        #expect(resolved.isDark)
        #expect(resolved.colorScheme == SalusTheme.colorScheme(dark: true, premiumTheme: .ocean))
        #expect(resolved.extendedColors == SalusExtendedColors.dark)
    }

    @Test("an explicit mode overrides the system in the full resolution")
    func explicitModeWins() {
        let resolved = SalusTheme.resolve(mode: .light, premiumTheme: .forest, systemIsDark: true)
        #expect(!resolved.isDark)
        #expect(resolved.extendedColors == SalusExtendedColors.light)
        #expect(resolved.colorScheme.primary == Color(hex: 0x2E_6B27))
        #expect(resolved.colorScheme.background == SalusColorScheme.light.background)
    }

    @Test("the defaults keep every preview on SYSTEM + CLASSIC")
    func defaultArguments() {
        // Theme.kt:88-95 — `darkTheme = isSystemInDarkTheme()`, `premiumTheme = CLASSIC`.
        #expect(SalusTheme.resolve(systemIsDark: false).colorScheme == SalusColorScheme.light)
        #expect(SalusTheme.resolve(systemIsDark: true).colorScheme == SalusColorScheme.dark)
    }

    @Test(
        "feature accents and status colors are never touched by the palette",
        arguments: PremiumTheme.allCases
    )
    func extendedColorsUnaffected(_ palette: PremiumTheme) {
        // §4.5 — feature accents (§3) and status colors (§3.3) are unaffected.
        #expect(
            SalusTheme.resolve(mode: .light, premiumTheme: palette, systemIsDark: true)
                .extendedColors == SalusExtendedColors.light
        )
        #expect(
            SalusTheme.resolve(mode: .dark, premiumTheme: palette, systemIsDark: false)
                .extendedColors == SalusExtendedColors.dark
        )
    }
}
