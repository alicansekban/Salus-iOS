import SwiftUI

// Mirrors `salus-android/docs/design/design-tokens.md` §4
// (Android: `core/designsystem/.../theme/PremiumThemeColors.kt`).
//
// A premium theme recolors the accent roles ONLY. Backgrounds, surfaces, outlines, error and
// tertiary roles stay exactly as §1/§2 define them, so cards keep reading as the same calm
// panels and no palette can quietly break the contrast of body text on a surface.
// Feature accents (§3) and status colors (§3.3) are unaffected as well.
//
// This file holds the palette data only. Applying a palette to a `SalusColorScheme` is theme
// resolution and lives outside this package's token layer.

/// The eight Material roles a premium theme replaces (`PremiumThemeColors.kt:110-119`).
public struct SalusPremiumAccentPalette: Equatable, Sendable {
    public var primary: Color
    public var onPrimary: Color
    public var primaryContainer: Color
    public var onPrimaryContainer: Color
    public var secondary: Color
    public var onSecondary: Color
    public var secondaryContainer: Color
    public var onSecondaryContainer: Color

    /// The eight roles keyed by Material role name.
    public var allTokens: [String: Color] {
        [
            "primary": primary,
            "onPrimary": onPrimary,
            "primaryContainer": primaryContainer,
            "onPrimaryContainer": onPrimaryContainer,
            "secondary": secondary,
            "onSecondary": onSecondary,
            "secondaryContainer": secondaryContainer,
            "onSecondaryContainer": onSecondaryContainer,
        ]
    }
}

/// The four premium accent palettes, light and dark.
///
/// Palette names match the Android enum `PremiumTheme`
/// (`core/model/.../model/Settings.kt:10-15`): `CLASSIC`, `OCEAN`, `SUNSET`, `FOREST`.
public enum SalusPremiumAccents {
    /// §4.1 — `CLASSIC` is the Salus brand palette itself. On Android `withPremiumAccent`
    /// returns the scheme untouched rather than copying an identical one over it
    /// (`PremiumThemeColors.kt:105`); the values below are the eight brand accent rows of §1.
    public static let classicLight = SalusPremiumAccentPalette(
        primary: Color(hex: 0x3E7D5F),
        onPrimary: Color(hex: 0xFFFFFF),
        primaryContainer: Color(hex: 0xC4E8D2),
        onPrimaryContainer: Color(hex: 0x0B2818),
        secondary: Color(hex: 0x506358),
        onSecondary: Color(hex: 0xFFFFFF),
        secondaryContainer: Color(hex: 0xD3E8DB),
        onSecondaryContainer: Color(hex: 0x0E1F17)
    )

    /// §4.1 — the eight brand accent rows of §2.
    public static let classicDark = SalusPremiumAccentPalette(
        primary: Color(hex: 0x8BD6B2),
        onPrimary: Color(hex: 0x0A3B26),
        primaryContainer: Color(hex: 0x275B43),
        onPrimaryContainer: Color(hex: 0xC4E8D2),
        secondary: Color(hex: 0xB7CCBE),
        onSecondary: Color(hex: 0x22352B),
        secondaryContainer: Color(hex: 0x384B40),
        onSecondaryContainer: Color(hex: 0xD3E8DB)
    )

    /// §4.2 — OCEAN, cyan/teal. Source: `PremiumThemeColors.kt:29-38`.
    public static let oceanLight = SalusPremiumAccentPalette(
        primary: Color(hex: 0x0E7490),
        onPrimary: Color(hex: 0xFFFFFF),
        primaryContainer: Color(hex: 0xBEE9F7),
        onPrimaryContainer: Color(hex: 0x001F29),
        secondary: Color(hex: 0x4A6470),
        onSecondary: Color(hex: 0xFFFFFF),
        secondaryContainer: Color(hex: 0xCDE7F2),
        onSecondaryContainer: Color(hex: 0x061F29)
    )

    /// §4.2 — OCEAN, dark. Source: `PremiumThemeColors.kt:40-49`.
    public static let oceanDark = SalusPremiumAccentPalette(
        primary: Color(hex: 0x5FD4F0),
        onPrimary: Color(hex: 0x00363F),
        primaryContainer: Color(hex: 0x004E5F),
        onPrimaryContainer: Color(hex: 0xBEE9F7),
        secondary: Color(hex: 0xB2CBD8),
        onSecondary: Color(hex: 0x1C333E),
        secondaryContainer: Color(hex: 0x334A55),
        onSecondaryContainer: Color(hex: 0xCDE7F2)
    )

    /// §4.3 — SUNSET, warm orange over a brown secondary.
    /// Source: `PremiumThemeColors.kt:52-61`. Light `primaryContainer` and
    /// `secondaryContainer` are the same `#FFDBCF` by design.
    public static let sunsetLight = SalusPremiumAccentPalette(
        primary: Color(hex: 0xB4491F),
        onPrimary: Color(hex: 0xFFFFFF),
        primaryContainer: Color(hex: 0xFFDBCF),
        onPrimaryContainer: Color(hex: 0x3B0A00),
        secondary: Color(hex: 0x77574B),
        onSecondary: Color(hex: 0xFFFFFF),
        secondaryContainer: Color(hex: 0xFFDBCF),
        onSecondaryContainer: Color(hex: 0x2C160D)
    )

    /// §4.3 — SUNSET, dark. Source: `PremiumThemeColors.kt:63-72`.
    public static let sunsetDark = SalusPremiumAccentPalette(
        primary: Color(hex: 0xFFB598),
        onPrimary: Color(hex: 0x5F1600),
        primaryContainer: Color(hex: 0x8A3308),
        onPrimaryContainer: Color(hex: 0xFFDBCF),
        secondary: Color(hex: 0xE7BDAC),
        onSecondary: Color(hex: 0x442A20),
        secondaryContainer: Color(hex: 0x5D4035),
        onSecondaryContainer: Color(hex: 0xFFDBCF)
    )

    /// §4.4 — FOREST, a deeper, more saturated green than the brand sage.
    /// Source: `PremiumThemeColors.kt:75-84`.
    public static let forestLight = SalusPremiumAccentPalette(
        primary: Color(hex: 0x2E6B27),
        onPrimary: Color(hex: 0xFFFFFF),
        primaryContainer: Color(hex: 0xAFF2A1),
        onPrimaryContainer: Color(hex: 0x002203),
        secondary: Color(hex: 0x54634D),
        onSecondary: Color(hex: 0xFFFFFF),
        secondaryContainer: Color(hex: 0xD7E8CD),
        onSecondaryContainer: Color(hex: 0x121F0E)
    )

    /// §4.4 — FOREST, dark. Source: `PremiumThemeColors.kt:86-95`.
    public static let forestDark = SalusPremiumAccentPalette(
        primary: Color(hex: 0x95D888),
        onPrimary: Color(hex: 0x033900),
        primaryContainer: Color(hex: 0x155210),
        onPrimaryContainer: Color(hex: 0xAFF2A1),
        secondary: Color(hex: 0xBBCBB1),
        onSecondary: Color(hex: 0x263422),
        secondaryContainer: Color(hex: 0x3C4B37),
        onSecondaryContainer: Color(hex: 0xD7E8CD)
    )

    /// Every palette, keyed `<palette>.<theme>`.
    public static var allPalettes: [(name: String, palette: SalusPremiumAccentPalette)] {
        [
            ("classic.light", classicLight),
            ("classic.dark", classicDark),
            ("ocean.light", oceanLight),
            ("ocean.dark", oceanDark),
            ("sunset.light", sunsetLight),
            ("sunset.dark", sunsetDark),
            ("forest.light", forestLight),
            ("forest.dark", forestDark),
        ]
    }

    /// All 64 premium accent colors, keyed `<palette>.<theme>.<role>`.
    public static var allTokens: [String: Color] {
        var tokens: [String: Color] = [:]
        for entry in allPalettes {
            for (role, color) in entry.palette.allTokens {
                tokens["\(entry.name).\(role)"] = color
            }
        }
        return tokens
    }
}
