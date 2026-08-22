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
//
// Every hex lives on its own named `private static let` below rather than inline in the
// eight-argument palette initializers: a `Color(hex:)` call as an initializer argument costs
// the type checker real time, and eight of them in one expression is already at its edge.

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
    package var allTokens: [String: Color] {
        [
            "primary": primary,
            "onPrimary": onPrimary,
            "primaryContainer": primaryContainer,
            "onPrimaryContainer": onPrimaryContainer,
            "secondary": secondary,
            "onSecondary": onSecondary,
            "secondaryContainer": secondaryContainer,
            "onSecondaryContainer": onSecondaryContainer
        ]
    }
}

/// §4.1 — CLASSIC, light. CLASSIC is the Salus brand palette itself: on Android
/// `withPremiumAccent` returns the scheme untouched rather than copying an identical one over
/// it (`PremiumThemeColors.kt:105`), so these are the eight brand accent rows of §1.
///
/// Read off `SalusColorScheme.light` rather than re-stating its hexes. Two copies of the same
/// eight literals can drift apart, and the drift would be invisible: nothing in the token count
/// notices that CLASSIC has stopped being the brand palette. Derived, the identity holds by
/// construction, and §1 stays the one place a brand accent hex is written down.
private enum ClassicLightValues {
    private static let brand = SalusColorScheme.light

    static let primary = brand.primary
    static let onPrimary = brand.onPrimary
    static let primaryContainer = brand.primaryContainer
    static let onPrimaryContainer = brand.onPrimaryContainer
    static let secondary = brand.secondary
    static let onSecondary = brand.onSecondary
    static let secondaryContainer = brand.secondaryContainer
    static let onSecondaryContainer = brand.onSecondaryContainer
}

/// §4.1 — CLASSIC, dark: the eight brand accent rows of §2, derived from `SalusColorScheme.dark`
/// for the reason above.
private enum ClassicDarkValues {
    private static let brand = SalusColorScheme.dark

    static let primary = brand.primary
    static let onPrimary = brand.onPrimary
    static let primaryContainer = brand.primaryContainer
    static let onPrimaryContainer = brand.onPrimaryContainer
    static let secondary = brand.secondary
    static let onSecondary = brand.onSecondary
    static let secondaryContainer = brand.secondaryContainer
    static let onSecondaryContainer = brand.onSecondaryContainer
}

/// §4.2 — OCEAN, cyan/teal, light. Source: `PremiumThemeColors.kt:29-38`.
private enum OceanLightValues {
    static let primary = Color(hex: 0x0E7490)
    static let onPrimary = Color(hex: 0xFFFFFF)
    static let primaryContainer = Color(hex: 0xBEE9F7)
    static let onPrimaryContainer = Color(hex: 0x001F29)
    static let secondary = Color(hex: 0x4A6470)
    static let onSecondary = Color(hex: 0xFFFFFF)
    static let secondaryContainer = Color(hex: 0xCDE7F2)
    static let onSecondaryContainer = Color(hex: 0x061F29)
}

/// §4.2 — OCEAN, dark. Source: `PremiumThemeColors.kt:40-49`.
private enum OceanDarkValues {
    static let primary = Color(hex: 0x5FD4F0)
    static let onPrimary = Color(hex: 0x00363F)
    static let primaryContainer = Color(hex: 0x004E5F)
    static let onPrimaryContainer = Color(hex: 0xBEE9F7)
    static let secondary = Color(hex: 0xB2CBD8)
    static let onSecondary = Color(hex: 0x1C333E)
    static let secondaryContainer = Color(hex: 0x334A55)
    static let onSecondaryContainer = Color(hex: 0xCDE7F2)
}

/// §4.3 — SUNSET, warm orange over a brown secondary, light.
/// Source: `PremiumThemeColors.kt:52-61`. `primaryContainer` and `secondaryContainer` are the
/// same `#FFDBCF` by design.
private enum SunsetLightValues {
    static let primary = Color(hex: 0xB4491F)
    static let onPrimary = Color(hex: 0xFFFFFF)
    static let primaryContainer = Color(hex: 0xFFDBCF)
    static let onPrimaryContainer = Color(hex: 0x3B0A00)
    static let secondary = Color(hex: 0x77574B)
    static let onSecondary = Color(hex: 0xFFFFFF)
    static let secondaryContainer = Color(hex: 0xFFDBCF)
    static let onSecondaryContainer = Color(hex: 0x2C160D)
}

/// §4.3 — SUNSET, dark. Source: `PremiumThemeColors.kt:63-72`.
private enum SunsetDarkValues {
    static let primary = Color(hex: 0xFFB598)
    static let onPrimary = Color(hex: 0x5F1600)
    static let primaryContainer = Color(hex: 0x8A3308)
    static let onPrimaryContainer = Color(hex: 0xFFDBCF)
    static let secondary = Color(hex: 0xE7BDAC)
    static let onSecondary = Color(hex: 0x442A20)
    static let secondaryContainer = Color(hex: 0x5D4035)
    static let onSecondaryContainer = Color(hex: 0xFFDBCF)
}

/// §4.4 — FOREST, a deeper, more saturated green than the brand sage, light.
/// Source: `PremiumThemeColors.kt:75-84`.
private enum ForestLightValues {
    static let primary = Color(hex: 0x2E6B27)
    static let onPrimary = Color(hex: 0xFFFFFF)
    static let primaryContainer = Color(hex: 0xAFF2A1)
    static let onPrimaryContainer = Color(hex: 0x002203)
    static let secondary = Color(hex: 0x54634D)
    static let onSecondary = Color(hex: 0xFFFFFF)
    static let secondaryContainer = Color(hex: 0xD7E8CD)
    static let onSecondaryContainer = Color(hex: 0x121F0E)
}

/// §4.4 — FOREST, dark. Source: `PremiumThemeColors.kt:86-95`.
private enum ForestDarkValues {
    static let primary = Color(hex: 0x95D888)
    static let onPrimary = Color(hex: 0x033900)
    static let primaryContainer = Color(hex: 0x155210)
    static let onPrimaryContainer = Color(hex: 0xAFF2A1)
    static let secondary = Color(hex: 0xBBCBB1)
    static let onSecondary = Color(hex: 0x263422)
    static let secondaryContainer = Color(hex: 0x3C4B37)
    static let onSecondaryContainer = Color(hex: 0xD7E8CD)
}

/// The four premium accent palettes, light and dark.
///
/// Palette names match the Android enum `PremiumTheme`
/// (`core/model/.../model/Settings.kt:10-15`): `CLASSIC`, `OCEAN`, `SUNSET`, `FOREST`.
public enum SalusPremiumAccents {
    /// §4.1 — CLASSIC, light.
    public static let classicLight = SalusPremiumAccentPalette(
        primary: ClassicLightValues.primary,
        onPrimary: ClassicLightValues.onPrimary,
        primaryContainer: ClassicLightValues.primaryContainer,
        onPrimaryContainer: ClassicLightValues.onPrimaryContainer,
        secondary: ClassicLightValues.secondary,
        onSecondary: ClassicLightValues.onSecondary,
        secondaryContainer: ClassicLightValues.secondaryContainer,
        onSecondaryContainer: ClassicLightValues.onSecondaryContainer
    )

    /// §4.1 — CLASSIC, dark.
    public static let classicDark = SalusPremiumAccentPalette(
        primary: ClassicDarkValues.primary,
        onPrimary: ClassicDarkValues.onPrimary,
        primaryContainer: ClassicDarkValues.primaryContainer,
        onPrimaryContainer: ClassicDarkValues.onPrimaryContainer,
        secondary: ClassicDarkValues.secondary,
        onSecondary: ClassicDarkValues.onSecondary,
        secondaryContainer: ClassicDarkValues.secondaryContainer,
        onSecondaryContainer: ClassicDarkValues.onSecondaryContainer
    )

    /// §4.2 — OCEAN, light.
    public static let oceanLight = SalusPremiumAccentPalette(
        primary: OceanLightValues.primary,
        onPrimary: OceanLightValues.onPrimary,
        primaryContainer: OceanLightValues.primaryContainer,
        onPrimaryContainer: OceanLightValues.onPrimaryContainer,
        secondary: OceanLightValues.secondary,
        onSecondary: OceanLightValues.onSecondary,
        secondaryContainer: OceanLightValues.secondaryContainer,
        onSecondaryContainer: OceanLightValues.onSecondaryContainer
    )

    /// §4.2 — OCEAN, dark.
    public static let oceanDark = SalusPremiumAccentPalette(
        primary: OceanDarkValues.primary,
        onPrimary: OceanDarkValues.onPrimary,
        primaryContainer: OceanDarkValues.primaryContainer,
        onPrimaryContainer: OceanDarkValues.onPrimaryContainer,
        secondary: OceanDarkValues.secondary,
        onSecondary: OceanDarkValues.onSecondary,
        secondaryContainer: OceanDarkValues.secondaryContainer,
        onSecondaryContainer: OceanDarkValues.onSecondaryContainer
    )

    /// §4.3 — SUNSET, light.
    public static let sunsetLight = SalusPremiumAccentPalette(
        primary: SunsetLightValues.primary,
        onPrimary: SunsetLightValues.onPrimary,
        primaryContainer: SunsetLightValues.primaryContainer,
        onPrimaryContainer: SunsetLightValues.onPrimaryContainer,
        secondary: SunsetLightValues.secondary,
        onSecondary: SunsetLightValues.onSecondary,
        secondaryContainer: SunsetLightValues.secondaryContainer,
        onSecondaryContainer: SunsetLightValues.onSecondaryContainer
    )

    /// §4.3 — SUNSET, dark.
    public static let sunsetDark = SalusPremiumAccentPalette(
        primary: SunsetDarkValues.primary,
        onPrimary: SunsetDarkValues.onPrimary,
        primaryContainer: SunsetDarkValues.primaryContainer,
        onPrimaryContainer: SunsetDarkValues.onPrimaryContainer,
        secondary: SunsetDarkValues.secondary,
        onSecondary: SunsetDarkValues.onSecondary,
        secondaryContainer: SunsetDarkValues.secondaryContainer,
        onSecondaryContainer: SunsetDarkValues.onSecondaryContainer
    )

    /// §4.4 — FOREST, light.
    public static let forestLight = SalusPremiumAccentPalette(
        primary: ForestLightValues.primary,
        onPrimary: ForestLightValues.onPrimary,
        primaryContainer: ForestLightValues.primaryContainer,
        onPrimaryContainer: ForestLightValues.onPrimaryContainer,
        secondary: ForestLightValues.secondary,
        onSecondary: ForestLightValues.onSecondary,
        secondaryContainer: ForestLightValues.secondaryContainer,
        onSecondaryContainer: ForestLightValues.onSecondaryContainer
    )

    /// §4.4 — FOREST, dark.
    public static let forestDark = SalusPremiumAccentPalette(
        primary: ForestDarkValues.primary,
        onPrimary: ForestDarkValues.onPrimary,
        primaryContainer: ForestDarkValues.primaryContainer,
        onPrimaryContainer: ForestDarkValues.onPrimaryContainer,
        secondary: ForestDarkValues.secondary,
        onSecondary: ForestDarkValues.onSecondary,
        secondaryContainer: ForestDarkValues.secondaryContainer,
        onSecondaryContainer: ForestDarkValues.onSecondaryContainer
    )

    /// Every palette, keyed `<palette>.<theme>`.
    package static var allPalettes: [(name: String, palette: SalusPremiumAccentPalette)] {
        [
            ("classic.light", classicLight),
            ("classic.dark", classicDark),
            ("ocean.light", oceanLight),
            ("ocean.dark", oceanDark),
            ("sunset.light", sunsetLight),
            ("sunset.dark", sunsetDark),
            ("forest.light", forestLight),
            ("forest.dark", forestDark)
        ]
    }

    /// All 64 premium accent colors, keyed `<palette>.<theme>.<role>`.
    package static var allTokens: [String: Color] {
        var tokens: [String: Color] = [:]
        for entry in allPalettes {
            for (role, color) in entry.palette.allTokens {
                tokens["\(entry.name).\(role)"] = color
            }
        }
        return tokens
    }
}
