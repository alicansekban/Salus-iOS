import SwiftUI

// §4.6 — the OCEAN per-feature accents, hero gradient and accent-derived roles.
// See `SalusPremiumExtendedColors.swift` for how a palette is built and why the hexes are
// hoisted; the source of truth is `PremiumExtendedColors.kt`.

/// §4.6 — OCEAN, light. Source: `PremiumExtendedColors.kt:40-86`.
private enum OceanLightExtendedValues {
    // Azure blue — the old teal-mint read as the brand green on the medication icons, so the
    // busiest feature moved off the primary's own hue entirely (owner QA, §14.8).
    // PremiumExtendedColors.kt:43-48
    static let medicationsAccent = Color(hex: 0x1B6FA8)
    static let medicationsOnAccent = Color(hex: 0xFFFFFF)
    static let medicationsContainer = Color(hex: 0xD6EAF8)
    static let medicationsOnContainer = Color(hex: 0x0B3A5C)

    // Plum-magenta — the one warm step out of the cyan family, as in the brand set.
    // PremiumExtendedColors.kt:50-55
    static let cycleAccent = Color(hex: 0xBB2FA3)
    static let cycleOnAccent = Color(hex: 0xFFFFFF)
    static let cycleContainer = Color(hex: 0xF0D4EB)
    static let cycleOnContainer = Color(hex: 0x410B38)

    // Blue — the muted periwinkle, a step off the brighter azure medications hue.
    // PremiumExtendedColors.kt:57-62
    static let vitalsAccent = Color(hex: 0x2F6DBD)
    static let vitalsOnAccent = Color(hex: 0xFFFFFF)
    static let vitalsContainer = Color(hex: 0xD4E0F0)
    static let vitalsOnContainer = Color(hex: 0x0B2341)

    // Deep cyan (petrol) — the Ocean primary's own hue.
    // PremiumExtendedColors.kt:64-69
    static let appointmentsAccent = Color(hex: 0x257592)
    static let appointmentsOnAccent = Color(hex: 0xFFFFFF)
    static let appointmentsContainer = Color(hex: 0xD4E8F0)
    static let appointmentsOnContainer = Color(hex: 0x0B3341)

    // Indigo — the cross-feature screen, furthest from every single feature's hue.
    // PremiumExtendedColors.kt:71-76
    static let trendsAccent = Color(hex: 0x5347D1)
    static let trendsOnAccent = Color(hex: 0xFFFFFF)
    static let trendsContainer = Color(hex: 0xD6D4F0)
    static let trendsOnContainer = Color(hex: 0x100B41)

    // Hero — cyan into deep cyan.
    // PremiumExtendedColors.kt:78-81
    static let heroTop = Color(hex: 0x26606C)
    static let heroBottom = Color(hex: 0x327683)
    static let hero = SalusGradient(top: heroTop, bottom: heroBottom)

    // Accent-derived roles, restated from the palette's own primary (0x155E75, cyan-800).
    // PremiumExtendedColors.kt:82-85
    static let accentGlow = Color(hex: 0x155E75).opacity(0.16)
    static let overline = Color(hex: 0x155E75)
    static let metricUp = Color(hex: 0x155E75)
    static let aiGradientTop = Color(hex: 0x155E75)

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

/// §4.6 — OCEAN, dark. Source: `PremiumExtendedColors.kt:88-134`.
private enum OceanDarkExtendedValues {
    // Azure blue — the old teal-mint read as the brand green on the medication icons, so the
    // busiest feature moved off the primary's own hue entirely (owner QA, §14.8).
    // PremiumExtendedColors.kt:91-96
    static let medicationsAccent = Color(hex: 0x7CC4F5)
    static let medicationsOnAccent = Color(hex: 0x06263B)
    static let medicationsContainer = Color(hex: 0x123A55)
    static let medicationsOnContainer = Color(hex: 0xCFE8FB)

    // Plum-magenta — the one warm step out of the cyan family, as in the brand set.
    // PremiumExtendedColors.kt:98-103
    static let cycleAccent = Color(hex: 0xDD8ACF)
    static let cycleOnAccent = Color(hex: 0x37062F)
    static let cycleContainer = Color(hex: 0x511F49)
    static let cycleOnContainer = Color(hex: 0xF0CAE9)

    // Blue — the muted periwinkle, a step off the brighter azure medications hue.
    // PremiumExtendedColors.kt:105-110
    static let vitalsAccent = Color(hex: 0x8AAEDD)
    static let vitalsOnAccent = Color(hex: 0x072143)
    static let vitalsContainer = Color(hex: 0x1F3551)
    static let vitalsOnContainer = Color(hex: 0xCADAF0)

    // Deep cyan (petrol) — the Ocean primary's own hue.
    // PremiumExtendedColors.kt:112-117
    static let appointmentsAccent = Color(hex: 0x8AC7DD)
    static let appointmentsOnAccent = Color(hex: 0x083546)
    static let appointmentsContainer = Color(hex: 0x1F4451)
    static let appointmentsOnContainer = Color(hex: 0xCAE5F0)

    // Indigo — the cross-feature screen, furthest from every single feature's hue.
    // PremiumExtendedColors.kt:119-124
    static let trendsAccent = Color(hex: 0x918ADD)
    static let trendsOnAccent = Color(hex: 0x08052E)
    static let trendsContainer = Color(hex: 0x241F51)
    static let trendsOnContainer = Color(hex: 0xCDCAF0)

    // Hero — the app ground rising into the Ocean primary container.
    // PremiumExtendedColors.kt:126-129
    static let heroTop = Color(hex: 0x090D0B) // BackgroundDark
    static let heroBottom = Color(hex: 0x164E63) // Ocean dark primaryContainer (cyan-900)
    static let hero = SalusGradient(top: heroTop, bottom: heroBottom)

    // Accent-derived roles, restated from the palette's own primary (0x22D3EE, cyan-400).
    // PremiumExtendedColors.kt:130-133
    static let accentGlow = Color(hex: 0x22D3EE).opacity(0.24)
    static let overline = Color(hex: 0x06B6D4) // cyan-500
    static let metricUp = Color(hex: 0x22D3EE)
    static let aiGradientTop = Color(hex: 0x22D3EE)

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
    /// §4.6 — OCEAN, light (`PremiumExtendedColors.kt:40`).
    static let oceanLight = SalusExtendedColors.light.replacingFeatureAccents(
        medications: OceanLightExtendedValues.medications,
        cycle: OceanLightExtendedValues.cycle,
        vitals: OceanLightExtendedValues.vitals,
        appointments: OceanLightExtendedValues.appointments,
        trends: OceanLightExtendedValues.trends,
        hero: OceanLightExtendedValues.hero
    )
    .restatingAccentDerivedRoles(
        accentGlow: OceanLightExtendedValues.accentGlow,
        overline: OceanLightExtendedValues.overline,
        metricUp: OceanLightExtendedValues.metricUp,
        aiGradientTop: OceanLightExtendedValues.aiGradientTop
    )

    /// §4.6 — OCEAN, dark (`PremiumExtendedColors.kt:88`).
    static let oceanDark = SalusExtendedColors.dark.replacingFeatureAccents(
        medications: OceanDarkExtendedValues.medications,
        cycle: OceanDarkExtendedValues.cycle,
        vitals: OceanDarkExtendedValues.vitals,
        appointments: OceanDarkExtendedValues.appointments,
        trends: OceanDarkExtendedValues.trends,
        hero: OceanDarkExtendedValues.hero
    )
    .restatingAccentDerivedRoles(
        accentGlow: OceanDarkExtendedValues.accentGlow,
        overline: OceanDarkExtendedValues.overline,
        metricUp: OceanDarkExtendedValues.metricUp,
        aiGradientTop: OceanDarkExtendedValues.aiGradientTop
    )
}
