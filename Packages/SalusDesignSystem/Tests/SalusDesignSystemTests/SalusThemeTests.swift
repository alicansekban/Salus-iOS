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
        (.classic, false, 0x3E7D5F, 0x0E1F17),
        (.classic, true, 0x8BD6B2, 0xD3E8DB),
        (.ocean, false, 0x0E7490, 0x061F29),
        (.ocean, true, 0x5FD4F0, 0xCDE7F2),
        (.sunset, false, 0xB4491F, 0x2C160D),
        (.sunset, true, 0xFFB598, 0xFFDBCF),
        (.forest, false, 0x2E6B27, 0x121F0E),
        (.forest, true, 0x95D888, 0xD7E8CD)
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

    /// The eight Material roles §4 lets a palette repaint (`PremiumThemeColors.kt:110-119`).
    static let accentRoleNames: Set = [
        "primary", "onPrimary", "primaryContainer", "onPrimaryContainer",
        "secondary", "onSecondary", "secondaryContainer", "onSecondaryContainer"
    ]

    /// Asserted over the whole 35-role registry rather than a hand-picked list of roles: a role
    /// added to `SalusColorScheme` and then quietly repainted would be missed by a list, and the
    /// list is exactly the thing nobody updates.
    @Test("the accented scheme is the base with only the eight §4 roles overwritten", arguments: rows)
    func nonAccentRolesUnchanged(_ row: PaletteRow) {
        let base = row.dark ? SalusColorScheme.dark : SalusColorScheme.light
        let scheme = SalusTheme.colorScheme(dark: row.dark, premiumTheme: row.palette)
        let baseTokens = base.allTokens
        let accents = row.palette.accentPalette(dark: row.dark).allTokens
        let label = "\(row.palette.rawValue) dark=\(row.dark)"

        // The palette offers exactly the eight §4 roles, and all eight are roles of the scheme.
        #expect(Set(accents.keys) == Self.accentRoleNames, "\(label) palette roles")
        #expect(baseTokens.count == 35, "\(label) scheme roles")
        #expect(Set(baseTokens.keys).isSuperset(of: Self.accentRoleNames), "\(label) role names")

        // The whole scheme, role by role: the eight come from the palette, the 27 from the base.
        var expected = baseTokens
        for (role, color) in accents {
            expected[role] = color
        }
        #expect(scheme.allTokens == expected, "\(label) resolved scheme")

        // The same statement as a key diff. It is a *subset*, not the full eight: some accent
        // roles legitimately carry the base's value — every light palette keeps `onPrimary` and
        // `onSecondary` at #FFFFFF — so those roles are repainted with what was already there.
        let changed = Set(scheme.allTokens.filter { baseTokens[$0.key] != $0.value }.keys)
        #expect(changed.isSubset(of: Self.accentRoleNames), "\(label) moved \(changed.sorted())")

        if row.palette == .classic {
            // CLASSIC is the brand palette itself — `withPremiumAccent` returns `self`.
            #expect(changed.isEmpty, "\(label) CLASSIC moved \(changed.sorted())")
        } else {
            #expect(!changed.isEmpty, "\(label) the palette repainted nothing")
        }
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
        #expect(resolved.colorScheme.primary == Color(hex: 0x2E6B27))
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
