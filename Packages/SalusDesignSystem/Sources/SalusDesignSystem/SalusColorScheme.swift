import SwiftUI

// Mirrors `salus-android/docs/design/design-tokens.md` §1 and §2
// (Android: `core/designsystem/.../theme/Color.kt`, wired in `theme/Theme.kt`).
//
// The 35 Material color roles Salus sets, once per theme. `surfaceTint` and the whole
// `*Fixed` / `*FixedDim` / `on*FixedVariant` family are deliberately NOT ported: Android
// leaves them at Material's defaults and never references them.
//
// Every hex lives on its own named `private static let` below rather than inline in the
// 35-argument initializer: a `Color(hex:)` call as an initializer argument costs the type
// checker real time, and 35 of them in one expression push it past its budget.

/// The 35 Material color roles Salus defines, for one theme.
///
/// Properties carry the Material role names so the file stays diffable against `Color.kt`
/// by eye. Resolution between `.light` and `.dark` is not this type's job.
public struct SalusColorScheme: Equatable, Sendable {
    public var primary: Color
    public var onPrimary: Color
    public var primaryContainer: Color
    public var onPrimaryContainer: Color

    public var secondary: Color
    public var onSecondary: Color
    public var secondaryContainer: Color
    public var onSecondaryContainer: Color

    public var tertiary: Color
    public var onTertiary: Color
    public var tertiaryContainer: Color
    public var onTertiaryContainer: Color

    public var error: Color
    public var onError: Color
    public var errorContainer: Color
    public var onErrorContainer: Color

    public var background: Color
    public var onBackground: Color
    public var surface: Color
    public var onSurface: Color
    public var surfaceVariant: Color
    public var onSurfaceVariant: Color

    public var outline: Color
    public var outlineVariant: Color
    public var inverseSurface: Color
    public var inverseOnSurface: Color
    public var inversePrimary: Color
    public var scrim: Color

    public var surfaceDim: Color
    public var surfaceBright: Color
    public var surfaceContainerLowest: Color
    public var surfaceContainerLow: Color
    public var surfaceContainer: Color
    public var surfaceContainerHigh: Color
    public var surfaceContainerHighest: Color

    /// Every role of this scheme, keyed by its Material role name. 35 entries.
    package var allTokens: [String: Color] {
        [
            "primary": primary,
            "onPrimary": onPrimary,
            "primaryContainer": primaryContainer,
            "onPrimaryContainer": onPrimaryContainer,
            "secondary": secondary,
            "onSecondary": onSecondary,
            "secondaryContainer": secondaryContainer,
            "onSecondaryContainer": onSecondaryContainer,
            "tertiary": tertiary,
            "onTertiary": onTertiary,
            "tertiaryContainer": tertiaryContainer,
            "onTertiaryContainer": onTertiaryContainer,
            "error": error,
            "onError": onError,
            "errorContainer": errorContainer,
            "onErrorContainer": onErrorContainer,
            "background": background,
            "onBackground": onBackground,
            "surface": surface,
            "onSurface": onSurface,
            "surfaceVariant": surfaceVariant,
            "onSurfaceVariant": onSurfaceVariant,
            "outline": outline,
            "outlineVariant": outlineVariant,
            "inverseSurface": inverseSurface,
            "inverseOnSurface": inverseOnSurface,
            "inversePrimary": inversePrimary,
            "scrim": scrim,
            "surfaceDim": surfaceDim,
            "surfaceBright": surfaceBright,
            "surfaceContainerLowest": surfaceContainerLowest,
            "surfaceContainerLow": surfaceContainerLow,
            "surfaceContainer": surfaceContainer,
            "surfaceContainerHigh": surfaceContainerHigh,
            "surfaceContainerHighest": surfaceContainerHighest
        ]
    }
}

/// §1 — the light palette's raw values, M15 target. Source: `Color.kt:13-59`.
///
/// M15 (design-tokens §14.2): `primary` stepped to emerald-800, `outline` becomes a hairline
/// (`#D6E2DA`) beside the light shadow rather than a mid-grey stroke, and the period/error roles
/// move onto their new families. Cards stay white, not tonal: `surfaceContainerLowest`,
/// `surfaceContainerLow` and `surfaceContainerHighest` are pinned to pure white on purpose
/// (`Color.kt:55-56,59`) so cards read as white panels floating on the mint background.
private enum LightPalette {
    static let primary = Color(hex: 0x065F46) // PrimaryLight, Color.kt:13 — emerald-800
    static let onPrimary = Color(hex: 0xFFFFFF) // OnPrimaryLight, Color.kt:14
    static let primaryContainer = Color(hex: 0xD1FAE5) // PrimaryContainerLight, Color.kt:15 — emerald-100
    static let onPrimaryContainer = Color(hex: 0x064E3B) // OnPrimaryContainerLight, Color.kt:16 — emerald-900

    static let secondary = Color(hex: 0x506358) // SecondaryLight, Color.kt:18
    static let onSecondary = Color(hex: 0xFFFFFF) // OnSecondaryLight, Color.kt:19
    static let secondaryContainer = Color(hex: 0xD3E8DB) // SecondaryContainerLight, Color.kt:20
    static let onSecondaryContainer = Color(hex: 0x0E1F17) // OnSecondaryContainerLight, Color.kt:21

    static let tertiary = Color(hex: 0xE11D48) // TertiaryLight, Color.kt:25 — rose-600
    static let onTertiary = Color(hex: 0xFFFFFF) // OnTertiaryLight, Color.kt:26
    static let tertiaryContainer = Color(hex: 0xFFE4E6) // TertiaryContainerLight, Color.kt:27 — rose-100
    static let onTertiaryContainer = Color(hex: 0x881337) // OnTertiaryContainerLight, Color.kt:28 — rose-900

    static let error = Color(hex: 0xBA1A1A) // ErrorLight, Color.kt:30
    static let onError = Color(hex: 0xFFFFFF) // OnErrorLight, Color.kt:31
    static let errorContainer = Color(hex: 0xFFDAD6) // ErrorContainerLight, Color.kt:32
    static let onErrorContainer = Color(hex: 0x410002) // OnErrorContainerLight, Color.kt:33

    static let background = Color(hex: 0xF1F5F2) // BackgroundLight, Color.kt:35
    static let onBackground = Color(hex: 0x171D19) // OnBackgroundLight, Color.kt:36
    static let surface = Color(hex: 0xF3F8F4) // SurfaceLight, Color.kt:37
    static let onSurface = Color(hex: 0x171D19) // OnSurfaceLight, Color.kt:38
    static let surfaceVariant = Color(hex: 0xDCE6DE) // SurfaceVariantLight, Color.kt:39
    static let onSurfaceVariant = Color(hex: 0x404944) // OnSurfaceVariantLight, Color.kt:40

    static let outline = Color(hex: 0xD6E2DA) // OutlineLight, Color.kt:44 — M15 hairline
    static let outlineVariant = Color(hex: 0xE4ECE7) // OutlineVariantLight, Color.kt:45
    static let inverseSurface = Color(hex: 0x2C322E) // InverseSurfaceLight, Color.kt:46
    static let inverseOnSurface = Color(hex: 0xEDF2ED) // InverseOnSurfaceLight, Color.kt:47
    static let inversePrimary = Color(hex: 0x34D399) // InversePrimaryLight, Color.kt:48 — the dark primary
    static let scrim = Color(hex: 0x000000) // ScrimLight, Color.kt:49

    static let surfaceDim = Color(hex: 0xD8E0DA) // SurfaceDimLight, Color.kt:50
    static let surfaceBright = Color(hex: 0xFBFDFB) // SurfaceBrightLight, Color.kt:51
    static let surfaceContainerLowest = Color(hex: 0xFFFFFF) // SurfaceContainerLowestLight, Color.kt:55
    static let surfaceContainerLow = Color(hex: 0xFFFFFF) // SurfaceContainerLowLight, Color.kt:56
    static let surfaceContainer = Color(hex: 0xF1F6F2) // SurfaceContainerLight, Color.kt:57
    static let surfaceContainerHigh = Color(hex: 0xEBF1EC) // SurfaceContainerHighLight, Color.kt:58
    static let surfaceContainerHighest = Color(hex: 0xFFFFFF) // SurfaceContainerHighestLight, Color.kt:59
}

/// §2 — the dark palette's raw values, M15 target. Source: `Color.kt:62-113`.
///
/// Near-black and OLED-friendly; accents brighten against the dark ground. M15
/// (design-tokens §14.1): `outline` carries the whole card edge in dark mode (no shadow), and is
/// one step lighter than the Figma spec's `#263029` so the border clears the 0.02 luminance step
/// against the card surface (`Color.kt:93-97`, §14.5).
private enum DarkPalette {
    static let primary = Color(hex: 0x34D399) // PrimaryDark, Color.kt:62 — emerald-400
    static let onPrimary = Color(hex: 0x022C22) // OnPrimaryDark, Color.kt:63 — emerald-950
    static let primaryContainer = Color(hex: 0x064E3B) // PrimaryContainerDark, Color.kt:64 — emerald-900
    static let onPrimaryContainer = Color(hex: 0xA7F3D0) // OnPrimaryContainerDark, Color.kt:65 — emerald-200

    static let secondary = Color(hex: 0xB7CCBE) // SecondaryDark, Color.kt:67
    static let onSecondary = Color(hex: 0x22352B) // OnSecondaryDark, Color.kt:68
    static let secondaryContainer = Color(hex: 0x384B40) // SecondaryContainerDark, Color.kt:69
    static let onSecondaryContainer = Color(hex: 0xD3E8DB) // OnSecondaryContainerDark, Color.kt:70

    static let tertiary = Color(hex: 0xFB7185) // TertiaryDark, Color.kt:73 — rose-400
    static let onTertiary = Color(hex: 0x4C0519) // OnTertiaryDark, Color.kt:74 — rose-950
    static let tertiaryContainer = Color(hex: 0x4C0519) // TertiaryContainerDark, Color.kt:75 — rose-950
    static let onTertiaryContainer = Color(hex: 0xFECDD3) // OnTertiaryContainerDark, Color.kt:76 — rose-200

    static let error = Color(hex: 0xFFB4AB) // ErrorDark, Color.kt:78
    static let onError = Color(hex: 0x690005) // OnErrorDark, Color.kt:79
    static let errorContainer = Color(hex: 0x3A1717) // ErrorContainerDark, Color.kt:83 — M15 muted ground
    static let onErrorContainer = Color(hex: 0xFFDAD6) // OnErrorContainerDark, Color.kt:84

    static let background = Color(hex: 0x090D0B) // BackgroundDark, Color.kt:86
    static let onBackground = Color(hex: 0xE6EBE7) // OnBackgroundDark, Color.kt:87
    static let surface = Color(hex: 0x090D0B) // SurfaceDark, Color.kt:88
    static let onSurface = Color(hex: 0xE6EBE7) // OnSurfaceDark, Color.kt:89
    static let surfaceVariant = Color(hex: 0x404944) // SurfaceVariantDark, Color.kt:90
    static let onSurfaceVariant = Color(hex: 0x9CA8A1) // OnSurfaceVariantDark, Color.kt:91

    static let outline = Color(hex: 0x2A352E) // OutlineDark, Color.kt:97 — the card edge
    static let outlineVariant = Color(hex: 0x1C2420) // OutlineVariantDark, Color.kt:98
    static let inverseSurface = Color(hex: 0xE6EBE7) // InverseSurfaceDark, Color.kt:99
    static let inverseOnSurface = Color(hex: 0x2C322E) // InverseOnSurfaceDark, Color.kt:100
    static let inversePrimary = Color(hex: 0x065F46) // InversePrimaryDark, Color.kt:101 — the light primary
    static let scrim = Color(hex: 0x000000) // ScrimDark, Color.kt:102

    static let surfaceDim = Color(hex: 0x090D0B) // SurfaceDimDark, Color.kt:103
    static let surfaceBright = Color(hex: 0x303632) // SurfaceBrightDark, Color.kt:104
    static let surfaceContainerLowest = Color(hex: 0x0E1311) // SurfaceContainerLowestDark, Color.kt:109
    static let surfaceContainerLow = Color(hex: 0x131917) // SurfaceContainerLowDark, Color.kt:110
    static let surfaceContainer = Color(hex: 0x182019) // SurfaceContainerDark, Color.kt:111
    static let surfaceContainerHigh = Color(hex: 0x1E2823) // SurfaceContainerHighDark, Color.kt:112
    static let surfaceContainerHighest = Color(hex: 0x243029) // SurfaceContainerHighestDark, Color.kt:113
}

extension SalusColorScheme {
    /// §1 — Material color roles, light.
    public static let light = SalusColorScheme(
        primary: LightPalette.primary,
        onPrimary: LightPalette.onPrimary,
        primaryContainer: LightPalette.primaryContainer,
        onPrimaryContainer: LightPalette.onPrimaryContainer,
        secondary: LightPalette.secondary,
        onSecondary: LightPalette.onSecondary,
        secondaryContainer: LightPalette.secondaryContainer,
        onSecondaryContainer: LightPalette.onSecondaryContainer,
        tertiary: LightPalette.tertiary,
        onTertiary: LightPalette.onTertiary,
        tertiaryContainer: LightPalette.tertiaryContainer,
        onTertiaryContainer: LightPalette.onTertiaryContainer,
        error: LightPalette.error,
        onError: LightPalette.onError,
        errorContainer: LightPalette.errorContainer,
        onErrorContainer: LightPalette.onErrorContainer,
        background: LightPalette.background,
        onBackground: LightPalette.onBackground,
        surface: LightPalette.surface,
        onSurface: LightPalette.onSurface,
        surfaceVariant: LightPalette.surfaceVariant,
        onSurfaceVariant: LightPalette.onSurfaceVariant,
        outline: LightPalette.outline,
        outlineVariant: LightPalette.outlineVariant,
        inverseSurface: LightPalette.inverseSurface,
        inverseOnSurface: LightPalette.inverseOnSurface,
        inversePrimary: LightPalette.inversePrimary,
        scrim: LightPalette.scrim,
        surfaceDim: LightPalette.surfaceDim,
        surfaceBright: LightPalette.surfaceBright,
        surfaceContainerLowest: LightPalette.surfaceContainerLowest,
        surfaceContainerLow: LightPalette.surfaceContainerLow,
        surfaceContainer: LightPalette.surfaceContainer,
        surfaceContainerHigh: LightPalette.surfaceContainerHigh,
        surfaceContainerHighest: LightPalette.surfaceContainerHighest
    )

    /// §2 — Material color roles, dark.
    public static let dark = SalusColorScheme(
        primary: DarkPalette.primary,
        onPrimary: DarkPalette.onPrimary,
        primaryContainer: DarkPalette.primaryContainer,
        onPrimaryContainer: DarkPalette.onPrimaryContainer,
        secondary: DarkPalette.secondary,
        onSecondary: DarkPalette.onSecondary,
        secondaryContainer: DarkPalette.secondaryContainer,
        onSecondaryContainer: DarkPalette.onSecondaryContainer,
        tertiary: DarkPalette.tertiary,
        onTertiary: DarkPalette.onTertiary,
        tertiaryContainer: DarkPalette.tertiaryContainer,
        onTertiaryContainer: DarkPalette.onTertiaryContainer,
        error: DarkPalette.error,
        onError: DarkPalette.onError,
        errorContainer: DarkPalette.errorContainer,
        onErrorContainer: DarkPalette.onErrorContainer,
        background: DarkPalette.background,
        onBackground: DarkPalette.onBackground,
        surface: DarkPalette.surface,
        onSurface: DarkPalette.onSurface,
        surfaceVariant: DarkPalette.surfaceVariant,
        onSurfaceVariant: DarkPalette.onSurfaceVariant,
        outline: DarkPalette.outline,
        outlineVariant: DarkPalette.outlineVariant,
        inverseSurface: DarkPalette.inverseSurface,
        inverseOnSurface: DarkPalette.inverseOnSurface,
        inversePrimary: DarkPalette.inversePrimary,
        scrim: DarkPalette.scrim,
        surfaceDim: DarkPalette.surfaceDim,
        surfaceBright: DarkPalette.surfaceBright,
        surfaceContainerLowest: DarkPalette.surfaceContainerLowest,
        surfaceContainerLow: DarkPalette.surfaceContainerLow,
        surfaceContainer: DarkPalette.surfaceContainer,
        surfaceContainerHigh: DarkPalette.surfaceContainerHigh,
        surfaceContainerHighest: DarkPalette.surfaceContainerHighest
    )
}
