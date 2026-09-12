import SwiftUI

// Mirrors `salus-android/docs/design/design-tokens.md` §4.6
// (Android: `core/designsystem/.../theme/PremiumExtendedColors.kt`).
//
// A premium theme repaints accents — and until this file existed, only the eight Material
// accent roles of §4 moved with it, so Home, Medications, Vitals and Appointments kept drawing
// the brand greens under an Ocean or a Sunset palette. Each palette here restates the five
// `FeatureAccent`s, the hero gradient and the accent-derived extended roles; everything else is
// inherited from the brand set.
//
// `success` and `warning` are deliberately NOT restated: a status colour that changed with the
// theme would stop meaning "good" and "careful". They come along with the copied brand value,
// which is the whole reason each palette is built from `SalusExtendedColors.light` / `.dark`
// rather than from a fresh memberwise initializer.
//
// The same split holds for the accent-derived extended roles of §3.6
// (`PremiumExtendedColors.kt:20-23`): `accentGlow`, `overline`, `metricUp` and `aiGradient.top`
// are restated per palette from that palette's own primary (`PremiumExtendedColors.kt:82-85`,
// `:130-133`, …), while `cardBorder`, `metricDown` and `aiGradient.bottom` are inherited from
// the copy — a border is structure and "worse" must keep meaning "worse" in every palette.
//
// Tones follow the same Material 3 curve as `SalusPremiumAccents.swift`: light uses accent ~40,
// container ~90, onContainer ~10; dark uses accent ~80, onAccent ~20, container ~30,
// onContainer ~90. Every accent/onAccent and container/onContainer pair clears WCAG AA (4.5:1),
// asserted over the parity table in `SalusPremiumExtendedColorsTests`.
//
// The palettes themselves live one theme per file beside this one —
// `SalusPremiumExtendedColorsOcean/Sunset/Forest.swift`. Kotlin keeps all three in
// `PremiumExtendedColors.kt`; the hexes with their role comments would push this file past
// SwiftLint's 500-line `file_length` gate, so the port splits where the Kotlin file does not.
// This file holds what the three share: the header above and the `copy`-shaped helper below.

extension SalusExtendedColors {
    /// The Swift twin of Kotlin's `LightExtendedColors.copy(medications = …, hero = …)`
    /// (`PremiumExtendedColors.kt:40`): the three roles a premium palette does NOT repaint —
    /// `success`, `warning`, and the structural roles `cardBorder` + `metricDown` +
    /// `aiGradient.bottom` — are carried over from the receiver rather than restated.
    func replacingFeatureAccents(
        medications: FeatureAccent,
        cycle: FeatureAccent,
        vitals: FeatureAccent,
        appointments: FeatureAccent,
        trends: FeatureAccent,
        hero: SalusGradient
    ) -> SalusExtendedColors {
        var copy = self
        copy.medications = medications
        copy.cycle = cycle
        copy.vitals = vitals
        copy.appointments = appointments
        copy.trends = trends
        copy.hero = hero
        return copy
    }

    /// Restates the four accent-derived roles from this palette's own primary, mirroring
    /// `PremiumExtendedColors.kt:82-85` and its dark per-palette twins. Called on the palette's
    /// brand-derived copy, so `cardBorder`, `metricDown` and `aiGradient.bottom` stay inherited.
    func restatingAccentDerivedRoles(
        accentGlow: Color,
        overline: Color,
        metricUp: Color,
        aiGradientTop: Color
    ) -> SalusExtendedColors {
        var copy = self
        copy.accentGlow = accentGlow
        copy.overline = overline
        copy.metricUp = metricUp
        copy.aiGradient = SalusGradient(top: aiGradientTop, bottom: copy.aiGradient.bottom)
        return copy
    }
}
