import AppKit
import Foundation
import SalusModel
import SwiftUI
import Testing

@testable import SalusDesignSystem

// The scheme-level WCAG contrast gate, the twin of Android's
// `SalusColorSchemeContrastTest.kt`. Every role pair that a screen draws as text on a ground —
// body text on its own surface, accent content on its accent, the overline label, error and the
// positive-metric delta — is held at WCAG AA (≥ 4.5:1) across all 4 palettes × 2 modes, instead
// of being eyeballed on a device. In dark mode the card is told apart by its border alone (no
// shadow), so `cardBorder` is pinned on an absolute luminance step rather than a ratio, exactly
// as the Android twin does (`SalusColorSchemeContrastTest.kt:63-78`).
//
// The two CLASSIC-light feature-accent pairs Android records as below AA (medications 4.45:1,
// vitals 4.05:1) surface here as `.disabled` cases carrying the Android ledger reference; the
// threshold is never loosened, and they are not fixed — changing a shipped brand hex from a test
// is not something the port does. The premium-palette contrast and the "status colors never move"
// / "premium differs from classic" cases live in `SalusPremiumExtendedColorsTests`.

/// The sRGB channels of an opaque `SwiftUI.Color`, back as `0xRRGGBB`.
///
/// Every Salus colour is authored through `Color(hex:)` in the sRGB space, so resolving via the
/// native colour is lossless here. Tests run on the macOS host; `NSColor` gives the sRGB
/// components back directly.
func hex(_ color: Color) -> UInt32 {
    let resolved = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
    return (UInt32(round(resolved.redComponent * 255)) << 16)
        | (UInt32(round(resolved.greenComponent * 255)) << 8)
        | UInt32(round(resolved.blueComponent * 255))
}

@Suite("Material and accent roles clear WCAG AA (SalusColorSchemeContrastTest.kt)")
struct SalusColorSchemeContrastTests {
    /// One scheme role pair, named for the failure message.
    private struct ContrastPair {
        let name: String
        let foreground: Color
        let background: Color

        func ratio() -> Double {
            ContrastMath.contrastRatio(hex(foreground), hex(background))
        }
    }

    @Test(
        "text pairs clear 4.5:1 on every palette and mode",
        arguments: PremiumTheme.allCases, [false, true]
    )
    func textPairsClearAA(_ palette: PremiumTheme, dark: Bool) {
        let theme = SalusTheme.resolve(premiumTheme: palette, systemIsDark: dark)
        let scheme = theme.colorScheme
        let extended = theme.extendedColors
        let label = "\(palette.rawValue) dark=\(dark)"
        let pairs = [
            ContrastPair(
                name: "onSurface/surface",
                foreground: scheme.onSurface,
                background: scheme.surface
            ),
            ContrastPair(
                name: "primary/onPrimary",
                foreground: scheme.onPrimary,
                background: scheme.primary
            ),
            ContrastPair(
                name: "onSurfaceVariant/surfaceContainerLow",
                foreground: scheme.onSurfaceVariant,
                background: scheme.surfaceContainerLow
            ),
            ContrastPair(
                name: "overline/surfaceContainerLow",
                foreground: extended.overline,
                background: scheme.surfaceContainerLow
            ),
            ContrastPair(
                name: "error/surface",
                foreground: scheme.error,
                background: scheme.surface
            ),
            ContrastPair(
                name: "metricUp/surfaceContainerLow",
                foreground: extended.metricUp,
                background: scheme.surfaceContainerLow
            )
        ]
        for pair in pairs {
            let ratio = pair.ratio()
            #expect(ratio >= 4.5, "\(label) \(pair.name) ratio \(ratio)")
        }
    }

    /// In dark mode the card is told apart from the canvas by its border alone (no shadow), so
    /// `cardBorder` has to differ from the card surface by a visible amount. A contrast ratio is
    /// the wrong measure this deep in the blacks — both colours sit near zero luminance, where
    /// the ratio inflates — so the border is pinned on an absolute luminance step (Android:
    /// `SalusColorSchemeContrastTest.kt:63-78`, token doc §14.5).
    @Test(
        "the card border is visible against the card surface",
        arguments: PremiumTheme.allCases, [false, true]
    )
    func cardBorderVisible(_ palette: PremiumTheme, dark: Bool) {
        let theme = SalusTheme.resolve(premiumTheme: palette, systemIsDark: dark)
        let extended = theme.extendedColors
        let label = "\(palette.rawValue) dark=\(dark)"
        let step = abs(
            ContrastMath.relativeLuminance(hex(extended.cardBorder))
                - ContrastMath.relativeLuminance(hex(theme.colorScheme.surfaceContainerLow))
        )
        #expect(step >= 0.02, "\(label) cardBorder luminance step \(step)")
    }

    /// The two CLASSIC-light feature-accent pairs Android carries below AA — medications 4.45:1,
    /// vitals 4.05:1 — are recorded, not fixed. This is `.disabled` so the suite stays green while
    /// the shortfall stays on the Android ledger (`salus-android` design-tokens §14.1 note /
    /// `PremiumExtendedColorsTest.kt:124-140`); the threshold is never loosened, and changing a
    /// shipped brand hex from a test is not something the port does.
    @Test(
        "CLASSIC-light medications (4.45:1) and vitals (4.05:1) stay below AA by record",
        .disabled("Android ledger: design-tokens.md §14.1 / PremiumExtendedColorsTest.kt:124-140, not fixed here")
    )
    func classicLightBelowAA() {}
}
