import SwiftUI

// Mirrors `salus-android/docs/design/design-tokens.md` §4.6
// (Android: `core/designsystem/.../theme/PremiumExtendedColors.kt`).
//
// A premium theme repaints accents — and until this file existed, only the eight Material
// accent roles of §4 moved with it, so Home, Medications, Vitals and Appointments kept drawing
// the brand greens under an Ocean or a Sunset palette. Each palette here restates the five
// `FeatureAccent`s and the hero gradient; everything else is inherited from the brand set.
//
// `success` and `warning` are deliberately NOT restated: a status colour that changed with the
// theme would stop meaning "good" and "careful". They come along with the copied brand value,
// which is the whole reason each palette is built from `SalusExtendedColors.light` / `.dark`
// rather than from a fresh memberwise initializer.
//
// Tones follow the same Material 3 curve as `SalusPremiumAccents.swift`: light uses accent ~40,
// container ~90, onContainer ~10; dark uses accent ~80, onAccent ~20, container ~30,
// onContainer ~90. Every accent/onAccent and container/onContainer pair clears WCAG AA (4.5:1),
// asserted over the parity table in `SalusPremiumExtendedColorsTests`.
//
// Every hex lives on its own named `private static let` below rather than inline in the
// `FeatureAccent(...)` initializers: a `Color(hex:)` call as an initializer argument costs the
// type checker real time, and five nested four-argument calls in one expression is past its
// edge. Hexes are transcribed from the Kotlin file, which is the source of truth for all 132.
//
// The palettes themselves live one theme per file beside this one —
// `SalusPremiumExtendedColorsOcean/Sunset/Forest.swift`. Kotlin keeps all three in
// `PremiumExtendedColors.kt`; 132 hexes with their role comments are 550 lines of Swift, past
// SwiftLint's 500-line `file_length` gate, so the port splits where the Kotlin file does not.
// This file holds what the three share: the header above and the `copy`-shaped helper below.

extension SalusExtendedColors {
    /// The Swift twin of Kotlin's `LightExtendedColors.copy(medications = …, hero = …)`
    /// (`PremiumExtendedColors.kt:26`): everything a premium palette does NOT repaint —
    /// `success` and `warning` — is carried over from the receiver rather than restated.
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
}
