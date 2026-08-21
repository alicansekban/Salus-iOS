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
            "surfaceContainerHighest": surfaceContainerHighest,
        ]
    }
}

/// §1 — the light palette's raw values. Source: `Color.kt:11-52`.
///
/// Cards are white, not tonal: `surfaceContainerLowest`, `surfaceContainerLow` and
/// `surfaceContainerHighest` are pinned to pure white on purpose (`Color.kt:46-47`) so cards
/// read as white panels floating on the mint background. Do not "fix" them back onto the M3
/// tonal ladder.
private enum LightPalette {
    static let primary = Color(hex: 0x3E7D5F)  // PrimaryLight, Color.kt:11
    static let onPrimary = Color(hex: 0xFFFFFF)  // OnPrimaryLight, Color.kt:12
    static let primaryContainer = Color(hex: 0xC4E8D2)  // PrimaryContainerLight, Color.kt:13
    static let onPrimaryContainer = Color(hex: 0x0B2818)  // OnPrimaryContainerLight, Color.kt:14

    static let secondary = Color(hex: 0x506358)  // SecondaryLight, Color.kt:16
    static let onSecondary = Color(hex: 0xFFFFFF)  // OnSecondaryLight, Color.kt:17
    static let secondaryContainer = Color(hex: 0xD3E8DB)  // SecondaryContainerLight, Color.kt:18
    static let onSecondaryContainer = Color(hex: 0x0E1F17)  // OnSecondaryContainerLight, Color.kt:19

    static let tertiary = Color(hex: 0x9C5566)  // TertiaryLight, Color.kt:21
    static let onTertiary = Color(hex: 0xFFFFFF)  // OnTertiaryLight, Color.kt:22
    static let tertiaryContainer = Color(hex: 0xFFD9E0)  // TertiaryContainerLight, Color.kt:23
    static let onTertiaryContainer = Color(hex: 0x3F111D)  // OnTertiaryContainerLight, Color.kt:24

    static let error = Color(hex: 0xBA1A1A)  // ErrorLight, Color.kt:26
    static let onError = Color(hex: 0xFFFFFF)  // OnErrorLight, Color.kt:27
    static let errorContainer = Color(hex: 0xFFDAD6)  // ErrorContainerLight, Color.kt:28
    static let onErrorContainer = Color(hex: 0x410002)  // OnErrorContainerLight, Color.kt:29

    static let background = Color(hex: 0xEAF2EC)  // BackgroundLight, Color.kt:31
    static let onBackground = Color(hex: 0x171D19)  // OnBackgroundLight, Color.kt:32
    static let surface = Color(hex: 0xF3F8F4)  // SurfaceLight, Color.kt:33
    static let onSurface = Color(hex: 0x171D19)  // OnSurfaceLight, Color.kt:34
    static let surfaceVariant = Color(hex: 0xDCE6DE)  // SurfaceVariantLight, Color.kt:35
    static let onSurfaceVariant = Color(hex: 0x404944)  // OnSurfaceVariantLight, Color.kt:36

    static let outline = Color(hex: 0x6F7973)  // OutlineLight, Color.kt:37
    static let outlineVariant = Color(hex: 0xC0CBC2)  // OutlineVariantLight, Color.kt:38
    static let inverseSurface = Color(hex: 0x2C322E)  // InverseSurfaceLight, Color.kt:39
    static let inverseOnSurface = Color(hex: 0xEDF2ED)  // InverseOnSurfaceLight, Color.kt:40
    static let inversePrimary = Color(hex: 0xA3D6BB)  // InversePrimaryLight, Color.kt:41
    static let scrim = Color(hex: 0x000000)  // ScrimLight, Color.kt:42

    static let surfaceDim = Color(hex: 0xD8E0DA)  // SurfaceDimLight, Color.kt:43
    static let surfaceBright = Color(hex: 0xFBFDFB)  // SurfaceBrightLight, Color.kt:44
    static let surfaceContainerLowest = Color(hex: 0xFFFFFF)  // SurfaceContainerLowestLight, Color.kt:48
    static let surfaceContainerLow = Color(hex: 0xFFFFFF)  // SurfaceContainerLowLight, Color.kt:49
    static let surfaceContainer = Color(hex: 0xF1F6F2)  // SurfaceContainerLight, Color.kt:50
    static let surfaceContainerHigh = Color(hex: 0xEBF1EC)  // SurfaceContainerHighLight, Color.kt:51
    static let surfaceContainerHighest = Color(hex: 0xFFFFFF)  // SurfaceContainerHighestLight, Color.kt:52
}

/// §2 — the dark palette's raw values. Source: `Color.kt:55-94`.
///
/// Near-black and OLED-friendly; accents brighten against the dark ground.
private enum DarkPalette {
    static let primary = Color(hex: 0x8BD6B2)  // PrimaryDark, Color.kt:55
    static let onPrimary = Color(hex: 0x0A3B26)  // OnPrimaryDark, Color.kt:56
    static let primaryContainer = Color(hex: 0x275B43)  // PrimaryContainerDark, Color.kt:57
    static let onPrimaryContainer = Color(hex: 0xC4E8D2)  // OnPrimaryContainerDark, Color.kt:58

    static let secondary = Color(hex: 0xB7CCBE)  // SecondaryDark, Color.kt:60
    static let onSecondary = Color(hex: 0x22352B)  // OnSecondaryDark, Color.kt:61
    static let secondaryContainer = Color(hex: 0x384B40)  // SecondaryContainerDark, Color.kt:62
    static let onSecondaryContainer = Color(hex: 0xD3E8DB)  // OnSecondaryContainerDark, Color.kt:63

    static let tertiary = Color(hex: 0xF2AFC0)  // TertiaryDark, Color.kt:65
    static let onTertiary = Color(hex: 0x4C2430)  // OnTertiaryDark, Color.kt:66
    static let tertiaryContainer = Color(hex: 0x653747)  // TertiaryContainerDark, Color.kt:67
    static let onTertiaryContainer = Color(hex: 0xFFD9E0)  // OnTertiaryContainerDark, Color.kt:68

    static let error = Color(hex: 0xFFB4AB)  // ErrorDark, Color.kt:70
    static let onError = Color(hex: 0x690005)  // OnErrorDark, Color.kt:71
    static let errorContainer = Color(hex: 0x93000A)  // ErrorContainerDark, Color.kt:72
    static let onErrorContainer = Color(hex: 0xFFDAD6)  // OnErrorContainerDark, Color.kt:73

    static let background = Color(hex: 0x0A0F0C)  // BackgroundDark, Color.kt:75
    static let onBackground = Color(hex: 0xE0E6E1)  // OnBackgroundDark, Color.kt:76
    static let surface = Color(hex: 0x0A0F0C)  // SurfaceDark, Color.kt:77
    static let onSurface = Color(hex: 0xE0E6E1)  // OnSurfaceDark, Color.kt:78
    static let surfaceVariant = Color(hex: 0x404944)  // SurfaceVariantDark, Color.kt:79
    static let onSurfaceVariant = Color(hex: 0xBFC9C1)  // OnSurfaceVariantDark, Color.kt:80

    static let outline = Color(hex: 0x8A938C)  // OutlineDark, Color.kt:81
    static let outlineVariant = Color(hex: 0x404944)  // OutlineVariantDark, Color.kt:82
    static let inverseSurface = Color(hex: 0xE0E6E1)  // InverseSurfaceDark, Color.kt:83
    static let inverseOnSurface = Color(hex: 0x2C322E)  // InverseOnSurfaceDark, Color.kt:84
    static let inversePrimary = Color(hex: 0x3E7D5F)  // InversePrimaryDark, Color.kt:85
    static let scrim = Color(hex: 0x000000)  // ScrimDark, Color.kt:86

    static let surfaceDim = Color(hex: 0x0A0F0C)  // SurfaceDimDark, Color.kt:87
    static let surfaceBright = Color(hex: 0x303632)  // SurfaceBrightDark, Color.kt:88
    static let surfaceContainerLowest = Color(hex: 0x050807)  // SurfaceContainerLowestDark, Color.kt:90
    static let surfaceContainerLow = Color(hex: 0x141A16)  // SurfaceContainerLowDark, Color.kt:91
    static let surfaceContainer = Color(hex: 0x181F1A)  // SurfaceContainerDark, Color.kt:92
    static let surfaceContainerHigh = Color(hex: 0x222925)  // SurfaceContainerHighDark, Color.kt:93
    static let surfaceContainerHighest = Color(hex: 0x2D3430)  // SurfaceContainerHighestDark, Color.kt:94
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
