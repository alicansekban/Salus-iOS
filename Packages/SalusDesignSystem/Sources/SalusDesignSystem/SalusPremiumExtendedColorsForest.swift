import SwiftUI

// §4.6 — the FOREST per-feature accents and hero gradient.
// See `SalusPremiumExtendedColors.swift` for how a palette is built and why the hexes are
// hoisted; the source of truth is `PremiumExtendedColors.kt`.

/// §4.6 — FOREST, light. Source: `PremiumExtendedColors.kt:201-242`.
private enum ForestLightExtendedValues {
    // Olive — the old deep green *was* the Forest primary's hue, so medication icons read as
    // the brand green. Pushed round to yellow, clear of green-400 (owner QA, §14.8).
    // PremiumExtendedColors.kt:236-241
    static let medicationsAccent = Color(hex: 0x6B7A16)
    static let medicationsOnAccent = Color(hex: 0xFFFFFF)
    static let medicationsContainer = Color(hex: 0xEDF3C8)
    static let medicationsOnContainer = Color(hex: 0x2E3607)

    // Berry — the warm counterpoint, as in the brand set.
    // PremiumExtendedColors.kt:243-248
    static let cycleAccent = Color(hex: 0xC3317A)
    static let cycleOnAccent = Color(hex: 0xFFFFFF)
    static let cycleContainer = Color(hex: 0xF0D4E2)
    static let cycleOnContainer = Color(hex: 0x410B26)

    // Moss — the green-leaning yellow-green, between the olive medications and the primary.
    // PremiumExtendedColors.kt:250-255
    static let vitalsAccent = Color(hex: 0x447A1E)
    static let vitalsOnAccent = Color(hex: 0xFFFFFF)
    static let vitalsContainer = Color(hex: 0xDFF0D4)
    static let vitalsOnContainer = Color(hex: 0x22410B)

    // Olive-teal — green pushed towards cyan.
    // PremiumExtendedColors.kt:257-262
    static let appointmentsAccent = Color(hex: 0x1F7A63)
    static let appointmentsOnAccent = Color(hex: 0xFFFFFF)
    static let appointmentsContainer = Color(hex: 0xD4F0E9)
    static let appointmentsOnContainer = Color(hex: 0x0B4134)

    // Teal-indigo — the coolest hue, reserved for the cross-feature screen.
    // PremiumExtendedColors.kt:264-269
    static let trendsAccent = Color(hex: 0x27749A)
    static let trendsOnAccent = Color(hex: 0xFFFFFF)
    static let trendsContainer = Color(hex: 0xD4E6F0)
    static let trendsOnContainer = Color(hex: 0x0B2F41)

    // Hero — green into deep green.
    // PremiumExtendedColors.kt:271-274
    static let heroTop = Color(hex: 0x266C31)
    static let heroBottom = Color(hex: 0x32833F)
    static let hero = SalusGradient(top: heroTop, bottom: heroBottom)

    // Accent-derived roles, restated from the palette's own primary (0x166534, green-800).
    // PremiumExtendedColors.kt:275-278
    static let accentGlow = Color(hex: 0x166534).opacity(0.16)
    static let overline = Color(hex: 0x166534)
    static let metricUp = Color(hex: 0x166534)
    static let aiGradientTop = Color(hex: 0x166534)

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
    // `PremiumExtendedColors.kt:284-289` — Olive-lime after owner QA: the old mint green *was* the Forest primary's
    // hue; medication icons read as the brand green. Pushed to olive (owner QA, §14.8).
    static let medicationsAccent = Color(hex: 0xD4E157)
    static let medicationsOnAccent = Color(hex: 0x2A3300)
    static let medicationsContainer = Color(hex: 0x3E4A12)
    static let medicationsOnContainer = Color(hex: 0xEEF5C4)

    // Berry — the warm counterpoint, as in the brand set.
    // PremiumExtendedColors.kt:291-296
    static let cycleAccent = Color(hex: 0xDD8AB4)
    static let cycleOnAccent = Color(hex: 0x35061D)
    static let cycleContainer = Color(hex: 0x511F38)
    static let cycleOnContainer = Color(hex: 0xF0CADD)

    // Moss — the green-leaning yellow-green, between the olive medications and the primary.
    // PremiumExtendedColors.kt:298-303
    static let vitalsAccent = Color(hex: 0xADDD8A)
    static let vitalsOnAccent = Color(hex: 0x214508)
    static let vitalsContainer = Color(hex: 0x34511F)
    static let vitalsOnContainer = Color(hex: 0xD9F0CA)

    // Olive-teal — green pushed towards cyan.
    // PremiumExtendedColors.kt:305-310
    static let appointmentsAccent = Color(hex: 0x8ADDC8)
    static let appointmentsOnAccent = Color(hex: 0x084435)
    static let appointmentsContainer = Color(hex: 0x1F5144)
    static let appointmentsOnContainer = Color(hex: 0xCAF0E6)

    // Teal-indigo — the coolest hue, reserved for the cross-feature screen.
    // PremiumExtendedColors.kt:312-317
    static let trendsAccent = Color(hex: 0x8AC2DD)
    static let trendsOnAccent = Color(hex: 0x083246)
    static let trendsContainer = Color(hex: 0x1F4051)
    static let trendsOnContainer = Color(hex: 0xCAE3F0)

    // Hero — the app ground rising into the Forest primary container.
    // PremiumExtendedColors.kt:319-322
    static let heroTop = Color(hex: 0x090D0B) // BackgroundDark
    static let heroBottom = Color(hex: 0x14532D) // Forest dark primaryContainer (green-900)
    static let hero = SalusGradient(top: heroTop, bottom: heroBottom)

    // Accent-derived roles, restated from the palette's own primary (0x4ADE80, green-400).
    // PremiumExtendedColors.kt:323-326
    static let accentGlow = Color(hex: 0x4ADE80).opacity(0.24)
    static let overline = Color(hex: 0x22C55E) // green-500
    static let metricUp = Color(hex: 0x4ADE80)
    static let aiGradientTop = Color(hex: 0x4ADE80)

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
    /// §4.6 — FOREST, light (`PremiumExtendedColors.kt:233`).
    static let forestLight = SalusExtendedColors.light.replacingFeatureAccents(
        medications: ForestLightExtendedValues.medications,
        cycle: ForestLightExtendedValues.cycle,
        vitals: ForestLightExtendedValues.vitals,
        appointments: ForestLightExtendedValues.appointments,
        trends: ForestLightExtendedValues.trends,
        hero: ForestLightExtendedValues.hero
    )
    .restatingAccentDerivedRoles(
        accentGlow: ForestLightExtendedValues.accentGlow,
        overline: ForestLightExtendedValues.overline,
        metricUp: ForestLightExtendedValues.metricUp,
        aiGradientTop: ForestLightExtendedValues.aiGradientTop
    )

    /// §4.6 — FOREST, dark (`PremiumExtendedColors.kt:281`).
    static let forestDark = SalusExtendedColors.dark.replacingFeatureAccents(
        medications: ForestDarkExtendedValues.medications,
        cycle: ForestDarkExtendedValues.cycle,
        vitals: ForestDarkExtendedValues.vitals,
        appointments: ForestDarkExtendedValues.appointments,
        trends: ForestDarkExtendedValues.trends,
        hero: ForestDarkExtendedValues.hero
    )
    .restatingAccentDerivedRoles(
        accentGlow: ForestDarkExtendedValues.accentGlow,
        overline: ForestDarkExtendedValues.overline,
        metricUp: ForestDarkExtendedValues.metricUp,
        aiGradientTop: ForestDarkExtendedValues.aiGradientTop
    )
}
