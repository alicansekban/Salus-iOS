import SalusModel
import SwiftUI

// Theme resolution, mirroring the Android `SalusTheme` composable
// (`core/designsystem/.../theme/Theme.kt:86-104`) and `withPremiumAccent`
// (`PremiumThemeColors.kt:103-120`). The behavior contract is tabulated in
// `salus-android/docs/design/design-tokens.md` §4.5.
//
// This is pure resolution over the token layer: no views, no storage, no environment reads.
// Whether the OS is in dark mode arrives as a parameter (`systemIsDark`) rather than being read
// here, so the whole thing stays a function of its inputs and testable without a UI. The
// SwiftUI plumbing (an `EnvironmentKey` for the extended colors, `.preferredColorScheme`) is a
// view concern and belongs to `SalusUI`; the settings that feed it arrive with `SalusSettings`
// in M1.
//
// One thing the resolution deliberately does NOT do is entitlement. Android's callers pass what
// the user is *entitled* to, not what they picked — `effectivePremiumTheme` in `:core:premium`
// downgrades a non-premium user to `CLASSIC` before theming (§4.5, `Theme.kt:88-91`). That
// check stays outside the design system on iOS too.

/// Everything a theme resolves to: the Material scheme, the Salus extended colors, and which
/// of the two themes was chosen.
///
/// The Android composable provides the same three things — `MaterialTheme(colorScheme = …)`,
/// `LocalSalusExtendedColors provides …`, and the `darkTheme` flag it branched on.
public struct SalusResolvedTheme: Equatable, Sendable {
    /// The 35 Material roles, with the premium palette already applied.
    public var colorScheme: SalusColorScheme
    /// The feature accents and status colors, which no palette ever touches.
    public var extendedColors: SalusExtendedColors
    /// Whether the dark theme was resolved.
    public var isDark: Bool

    public init(
        colorScheme: SalusColorScheme,
        extendedColors: SalusExtendedColors,
        isDark: Bool
    ) {
        self.colorScheme = colorScheme
        self.extendedColors = extendedColors
        self.isDark = isDark
    }
}

/// Resolves a theme mode and a premium palette to the tokens that get drawn.
public enum SalusTheme {
    /// Resolves the full theme.
    ///
    /// - Parameters:
    ///   - mode: what the user picked; `.system` defers to `systemIsDark`.
    ///   - premiumTheme: the palette the user is **entitled** to, not the one they selected.
    ///   - systemIsDark: what the OS currently reports (SwiftUI's `\.colorScheme == .dark`).
    public static func resolve(
        mode: ThemeMode = .default,
        premiumTheme: PremiumTheme = .default,
        systemIsDark: Bool
    ) -> SalusResolvedTheme {
        let dark = mode.isDark(systemIsDark: systemIsDark)
        return SalusResolvedTheme(
            colorScheme: colorScheme(dark: dark, premiumTheme: premiumTheme),
            extendedColors: extendedColors(dark: dark),
            isDark: dark
        )
    }

    /// The Material scheme for a theme, repainted with the palette's accents.
    ///
    /// `Theme.kt:99-100`: `(if (darkTheme) DarkColorScheme else LightColorScheme)
    /// .withPremiumAccent(premiumTheme, dark = darkTheme)`.
    public static func colorScheme(
        dark: Bool,
        premiumTheme: PremiumTheme = .default
    ) -> SalusColorScheme {
        let base = dark ? SalusColorScheme.dark : SalusColorScheme.light
        return base.withPremiumAccent(premiumTheme, dark: dark)
    }

    /// The extended colors for a theme (`Theme.kt:97-98`). The premium palette is not an input:
    /// feature accents and status colors are unaffected by it (§4.5).
    public static func extendedColors(dark: Bool) -> SalusExtendedColors {
        dark ? SalusExtendedColors.dark : SalusExtendedColors.light
    }
}

extension SalusColorScheme {
    /// Repaints the eight accent roles of this scheme for `theme`.
    ///
    /// `PremiumTheme.classic` is the Salus brand palette itself, so it returns the scheme
    /// untouched rather than copying an identical one over it (`PremiumThemeColors.kt:105`).
    /// Every other role — backgrounds, surfaces, outlines, error, tertiary — is left alone, so
    /// no palette can quietly break the contrast of body text on a surface.
    ///
    /// Kept `internal`, mirroring Kotlin's `internal fun`: `SalusTheme` is the entry point.
    func withPremiumAccent(_ theme: PremiumTheme, dark: Bool) -> SalusColorScheme {
        guard theme != .classic else { return self }
        let accent = theme.accentPalette(dark: dark)
        var scheme = self
        scheme.primary = accent.primary
        scheme.onPrimary = accent.onPrimary
        scheme.primaryContainer = accent.primaryContainer
        scheme.onPrimaryContainer = accent.onPrimaryContainer
        scheme.secondary = accent.secondary
        scheme.onSecondary = accent.onSecondary
        scheme.secondaryContainer = accent.secondaryContainer
        scheme.onSecondaryContainer = accent.onSecondaryContainer
        return scheme
    }
}
