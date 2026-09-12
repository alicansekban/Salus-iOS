import SwiftUI

// Mirrors `salus-android/docs/design/design-tokens.md` §4
// (Android: `core/designsystem/.../theme/PremiumThemeColors.kt`).
//
// A premium theme recolors the accent roles ONLY. Backgrounds, surfaces, outlines, error and
// tertiary roles stay exactly as §1/§2 define them, so cards keep reading as the same calm
// panels and no palette can quietly break the contrast of body text on a surface.
// Status colors (§3.3) are unaffected as well. Feature accents are NOT: §4.6 gives each palette
// its own five, in `SalusPremiumExtendedColors.swift`.
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

/// §4.2 — OCEAN, cyan/teal, light. Source: `PremiumThemeColors.kt:31-40`.
private enum OceanLightValues {
    static let primary = Color(hex: 0x155E75) // primary, PremiumThemeColors.kt:32 — cyan-800
    static let onPrimary = Color(hex: 0xFFFFFF) // onPrimary, PremiumThemeColors.kt:33
    static let primaryContainer = Color(hex: 0xCFFAFE) // primaryContainer, PremiumThemeColors.kt:34 — cyan-100
    static let onPrimaryContainer = Color(hex: 0x164E63) // onPrimaryContainer, PremiumThemeColors.kt:35 — cyan-900
    static let secondary = Color(hex: 0x4A6470) // secondary, PremiumThemeColors.kt:36
    static let onSecondary = Color(hex: 0xFFFFFF) // onSecondary, PremiumThemeColors.kt:37
    static let secondaryContainer = Color(hex: 0xCDE7F2) // secondaryContainer, PremiumThemeColors.kt:38
    static let onSecondaryContainer = Color(hex: 0x061F29) // onSecondaryContainer, PremiumThemeColors.kt:39
}

/// §4.2 — OCEAN, dark. Source: `PremiumThemeColors.kt:42-51`.
private enum OceanDarkValues {
    static let primary = Color(hex: 0x22D3EE) // primary, PremiumThemeColors.kt:43 — cyan-400
    static let onPrimary = Color(hex: 0x083344) // onPrimary, PremiumThemeColors.kt:44 — cyan-950
    static let primaryContainer = Color(hex: 0x164E63) // primaryContainer, PremiumThemeColors.kt:45 — cyan-900
    static let onPrimaryContainer = Color(hex: 0xA5F3FC) // onPrimaryContainer, PremiumThemeColors.kt:46 — cyan-200
    static let secondary = Color(hex: 0xB2CBD8) // secondary, PremiumThemeColors.kt:47
    static let onSecondary = Color(hex: 0x1C333E) // onSecondary, PremiumThemeColors.kt:48
    static let secondaryContainer = Color(hex: 0x334A55) // secondaryContainer, PremiumThemeColors.kt:49
    static let onSecondaryContainer = Color(hex: 0xCDE7F2) // onSecondaryContainer, PremiumThemeColors.kt:50
}

/// §4.3 — SUNSET, warm orange over a brown secondary, light.
/// Source: `PremiumThemeColors.kt:54-63`. `primaryContainer` and `secondaryContainer` are not the
/// same hex any more (M15 moved `primaryContainer` onto orange-100).
private enum SunsetLightValues {
    static let primary = Color(hex: 0x9A3412) // primary, PremiumThemeColors.kt:55 — orange-800
    static let onPrimary = Color(hex: 0xFFFFFF) // onPrimary, PremiumThemeColors.kt:56
    static let primaryContainer = Color(hex: 0xFFEDD5) // primaryContainer, PremiumThemeColors.kt:57 — orange-100
    static let onPrimaryContainer = Color(hex: 0x7C2D12) // onPrimaryContainer, PremiumThemeColors.kt:58 — orange-900
    static let secondary = Color(hex: 0x77574B) // secondary, PremiumThemeColors.kt:59
    static let onSecondary = Color(hex: 0xFFFFFF) // onSecondary, PremiumThemeColors.kt:60
    static let secondaryContainer = Color(hex: 0xFFDBCF) // secondaryContainer, PremiumThemeColors.kt:61
    static let onSecondaryContainer = Color(hex: 0x2C160D) // onSecondaryContainer, PremiumThemeColors.kt:62
}

/// §4.3 — SUNSET, dark. Source: `PremiumThemeColors.kt:65-74`.
private enum SunsetDarkValues {
    static let primary = Color(hex: 0xFB923C) // primary, PremiumThemeColors.kt:66 — orange-400
    static let onPrimary = Color(hex: 0x431407) // onPrimary, PremiumThemeColors.kt:67 — orange-950
    static let primaryContainer = Color(hex: 0x7C2D12) // primaryContainer, PremiumThemeColors.kt:68 — orange-900
    static let onPrimaryContainer = Color(hex: 0xFED7AA) // onPrimaryContainer, PremiumThemeColors.kt:69 — orange-200
    static let secondary = Color(hex: 0xE7BDAC) // secondary, PremiumThemeColors.kt:70
    static let onSecondary = Color(hex: 0x442A20) // onSecondary, PremiumThemeColors.kt:71
    static let secondaryContainer = Color(hex: 0x5D4035) // secondaryContainer, PremiumThemeColors.kt:72
    static let onSecondaryContainer = Color(hex: 0xFFDBCF) // onSecondaryContainer, PremiumThemeColors.kt:73
}

/// §4.4 — FOREST, a deeper, more saturated green than the brand sage, light.
/// Source: `PremiumThemeColors.kt:77-86`.
private enum ForestLightValues {
    static let primary = Color(hex: 0x166534) // primary, PremiumThemeColors.kt:78 — green-800
    static let onPrimary = Color(hex: 0xFFFFFF) // onPrimary, PremiumThemeColors.kt:79
    static let primaryContainer = Color(hex: 0xDCFCE7) // primaryContainer, PremiumThemeColors.kt:80 — green-100
    static let onPrimaryContainer = Color(hex: 0x14532D) // onPrimaryContainer, PremiumThemeColors.kt:81 — green-900
    static let secondary = Color(hex: 0x54634D) // secondary, PremiumThemeColors.kt:82
    static let onSecondary = Color(hex: 0xFFFFFF) // onSecondary, PremiumThemeColors.kt:83
    static let secondaryContainer = Color(hex: 0xD7E8CD) // secondaryContainer, PremiumThemeColors.kt:84
    static let onSecondaryContainer = Color(hex: 0x121F0E) // onSecondaryContainer, PremiumThemeColors.kt:85
}

/// §4.4 — FOREST, dark. Source: `PremiumThemeColors.kt:88-97`.
private enum ForestDarkValues {
    static let primary = Color(hex: 0x4ADE80) // primary, PremiumThemeColors.kt:89 — green-400
    static let onPrimary = Color(hex: 0x052E16) // onPrimary, PremiumThemeColors.kt:90 — green-950
    static let primaryContainer = Color(hex: 0x14532D) // primaryContainer, PremiumThemeColors.kt:91 — green-900
    static let onPrimaryContainer = Color(hex: 0xBBF7D0) // onPrimaryContainer, PremiumThemeColors.kt:92 — green-200
    static let secondary = Color(hex: 0xBBCBB1) // secondary, PremiumThemeColors.kt:93
    static let onSecondary = Color(hex: 0x263422) // onSecondary, PremiumThemeColors.kt:94
    static let secondaryContainer = Color(hex: 0x3C4B37) // secondaryContainer, PremiumThemeColors.kt:95
    static let onSecondaryContainer = Color(hex: 0xD7E8CD) // onSecondaryContainer, PremiumThemeColors.kt:96
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
