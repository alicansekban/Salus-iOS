import SwiftUI

// §4.6 — the FOREST per-feature accents and hero gradient.
// See `SalusPremiumExtendedColors.swift` for how a palette is built and why the hexes are
// hoisted; the source of truth is `PremiumExtendedColors.kt`.

/// §4.6 — FOREST, light. Source: `PremiumExtendedColors.kt:201-242`.
private enum ForestLightExtendedValues {
    // Deep green — the Forest primary's own hue.
    // PremiumExtendedColors.kt:203-208
    static let medicationsAccent = Color(hex: 0x1F7D3E)
    static let medicationsOnAccent = Color(hex: 0xFFFFFF)
    static let medicationsContainer = Color(hex: 0xD4F0DD)
    static let medicationsOnContainer = Color(hex: 0x0B411D)

    // Berry — the warm counterpoint, as in the brand set.
    // PremiumExtendedColors.kt:210-215
    static let cycleAccent = Color(hex: 0xC3317A)
    static let cycleOnAccent = Color(hex: 0xFFFFFF)
    static let cycleContainer = Color(hex: 0xF0D4E2)
    static let cycleOnContainer = Color(hex: 0x410B26)

    // Moss/lime — a yellow-green that separates vitals from medications.
    // PremiumExtendedColors.kt:217-222
    static let vitalsAccent = Color(hex: 0x447A1E)
    static let vitalsOnAccent = Color(hex: 0xFFFFFF)
    static let vitalsContainer = Color(hex: 0xDFF0D4)
    static let vitalsOnContainer = Color(hex: 0x22410B)

    // Olive-teal — green pushed towards cyan.
    // PremiumExtendedColors.kt:224-229
    static let appointmentsAccent = Color(hex: 0x1F7A63)
    static let appointmentsOnAccent = Color(hex: 0xFFFFFF)
    static let appointmentsContainer = Color(hex: 0xD4F0E9)
    static let appointmentsOnContainer = Color(hex: 0x0B4134)

    // Teal-indigo — the coolest hue, reserved for the cross-feature screen.
    // PremiumExtendedColors.kt:231-236
    static let trendsAccent = Color(hex: 0x27749A)
    static let trendsOnAccent = Color(hex: 0xFFFFFF)
    static let trendsContainer = Color(hex: 0xD4E6F0)
    static let trendsOnContainer = Color(hex: 0x0B2F41)

    // Hero — green into deep green.
    // PremiumExtendedColors.kt:238-241
    static let heroTop = Color(hex: 0x266C31)
    static let heroBottom = Color(hex: 0x32833F)
    static let hero = SalusGradient(top: heroTop, bottom: heroBottom)

    static let medications = FeatureAccent(
        accent: medicationsAccent,
        onAccent: medicationsOnAccent,
        container: medicationsContainer,
        onContainer: medicationsOnContainer
    )
    static let cycle = FeatureAccent(
        accent: cycleAccent,
        onAccent: cycleOnAccent,
        container: cycleContainer,
        onContainer: cycleOnContainer
    )
    static let vitals = FeatureAccent(
        accent: vitalsAccent,
        onAccent: vitalsOnAccent,
        container: vitalsContainer,
        onContainer: vitalsOnContainer
    )
    static let appointments = FeatureAccent(
        accent: appointmentsAccent,
        onAccent: appointmentsOnAccent,
        container: appointmentsContainer,
        onContainer: appointmentsOnContainer
    )
    static let trends = FeatureAccent(
        accent: trendsAccent,
        onAccent: trendsOnAccent,
        container: trendsContainer,
        onContainer: trendsOnContainer
    )
}

/// §4.6 — FOREST, dark. Source: `PremiumExtendedColors.kt:244-285`.
private enum ForestDarkExtendedValues {
    // Deep green — the Forest primary's own hue.
    // PremiumExtendedColors.kt:246-251
    static let medicationsAccent = Color(hex: 0x8ADDA6)
    static let medicationsOnAccent = Color(hex: 0x08441C)
    static let medicationsContainer = Color(hex: 0x1F5130)
    static let medicationsOnContainer = Color(hex: 0xCAF0D6)

    // Berry — the warm counterpoint, as in the brand set.
    // PremiumExtendedColors.kt:253-258
    static let cycleAccent = Color(hex: 0xDD8AB4)
    static let cycleOnAccent = Color(hex: 0x35061D)
    static let cycleContainer = Color(hex: 0x511F38)
    static let cycleOnContainer = Color(hex: 0xF0CADD)

    // Moss/lime — a yellow-green that separates vitals from medications.
    // PremiumExtendedColors.kt:260-265
    static let vitalsAccent = Color(hex: 0xADDD8A)
    static let vitalsOnAccent = Color(hex: 0x214508)
    static let vitalsContainer = Color(hex: 0x34511F)
    static let vitalsOnContainer = Color(hex: 0xD9F0CA)

    // Olive-teal — green pushed towards cyan.
    // PremiumExtendedColors.kt:267-272
    static let appointmentsAccent = Color(hex: 0x8ADDC8)
    static let appointmentsOnAccent = Color(hex: 0x084435)
    static let appointmentsContainer = Color(hex: 0x1F5144)
    static let appointmentsOnContainer = Color(hex: 0xCAF0E6)

    // Teal-indigo — the coolest hue, reserved for the cross-feature screen.
    // PremiumExtendedColors.kt:274-279
    static let trendsAccent = Color(hex: 0x8AC2DD)
    static let trendsOnAccent = Color(hex: 0x083246)
    static let trendsContainer = Color(hex: 0x1F4051)
    static let trendsOnContainer = Color(hex: 0xCAE3F0)

    // Hero — green into deep green.
    // PremiumExtendedColors.kt:281-284
    static let heroTop = Color(hex: 0x1C4823)
    static let heroBottom = Color(hex: 0x265C2F)
    static let hero = SalusGradient(top: heroTop, bottom: heroBottom)

    static let medications = FeatureAccent(
        accent: medicationsAccent,
        onAccent: medicationsOnAccent,
        container: medicationsContainer,
        onContainer: medicationsOnContainer
    )
    static let cycle = FeatureAccent(
        accent: cycleAccent,
        onAccent: cycleOnAccent,
        container: cycleContainer,
        onContainer: cycleOnContainer
    )
    static let vitals = FeatureAccent(
        accent: vitalsAccent,
        onAccent: vitalsOnAccent,
        container: vitalsContainer,
        onContainer: vitalsOnContainer
    )
    static let appointments = FeatureAccent(
        accent: appointmentsAccent,
        onAccent: appointmentsOnAccent,
        container: appointmentsContainer,
        onContainer: appointmentsOnContainer
    )
    static let trends = FeatureAccent(
        accent: trendsAccent,
        onAccent: trendsOnAccent,
        container: trendsContainer,
        onContainer: trendsOnContainer
    )
}

extension SalusExtendedColors {
    /// §4.6 — FOREST, light (`PremiumExtendedColors.kt:201`).
    static let forestLight = SalusExtendedColors.light.replacingFeatureAccents(
        medications: ForestLightExtendedValues.medications,
        cycle: ForestLightExtendedValues.cycle,
        vitals: ForestLightExtendedValues.vitals,
        appointments: ForestLightExtendedValues.appointments,
        trends: ForestLightExtendedValues.trends,
        hero: ForestLightExtendedValues.hero
    )

    /// §4.6 — FOREST, dark (`PremiumExtendedColors.kt:244`).
    static let forestDark = SalusExtendedColors.dark.replacingFeatureAccents(
        medications: ForestDarkExtendedValues.medications,
        cycle: ForestDarkExtendedValues.cycle,
        vitals: ForestDarkExtendedValues.vitals,
        appointments: ForestDarkExtendedValues.appointments,
        trends: ForestDarkExtendedValues.trends,
        hero: ForestDarkExtendedValues.hero
    )
}
