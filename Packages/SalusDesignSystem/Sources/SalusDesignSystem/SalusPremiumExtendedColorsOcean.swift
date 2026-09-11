import SwiftUI

// §4.6 — the OCEAN per-feature accents and hero gradient.
// See `SalusPremiumExtendedColors.swift` for how a palette is built and why the hexes are
// hoisted; the source of truth is `PremiumExtendedColors.kt`.

/// §4.6 — OCEAN, light. Source: `PremiumExtendedColors.kt:26-67`.
private enum OceanLightExtendedValues {
    // Teal — the closest hue to the Ocean primary, kept for the app's busiest feature.
    // PremiumExtendedColors.kt:28-33
    static let medicationsAccent = Color(hex: 0x1E7A68)
    static let medicationsOnAccent = Color(hex: 0xFFFFFF)
    static let medicationsContainer = Color(hex: 0xD4F0EA)
    static let medicationsOnContainer = Color(hex: 0x0B4136)

    // Plum-magenta — the one warm step out of the cyan family, as in the brand set.
    // PremiumExtendedColors.kt:35-40
    static let cycleAccent = Color(hex: 0xBB2FA3)
    static let cycleOnAccent = Color(hex: 0xFFFFFF)
    static let cycleContainer = Color(hex: 0xF0D4EB)
    static let cycleOnContainer = Color(hex: 0x410B38)

    // Blue — a clean step off teal so charts never read as the medications colour.
    // PremiumExtendedColors.kt:42-47
    static let vitalsAccent = Color(hex: 0x2F6DBD)
    static let vitalsOnAccent = Color(hex: 0xFFFFFF)
    static let vitalsContainer = Color(hex: 0xD4E0F0)
    static let vitalsOnContainer = Color(hex: 0x0B2341)

    // Deep cyan (petrol) — the Ocean primary's own hue.
    // PremiumExtendedColors.kt:49-54
    static let appointmentsAccent = Color(hex: 0x257592)
    static let appointmentsOnAccent = Color(hex: 0xFFFFFF)
    static let appointmentsContainer = Color(hex: 0xD4E8F0)
    static let appointmentsOnContainer = Color(hex: 0x0B3341)

    // Indigo — the cross-feature screen, furthest from every single feature's hue.
    // PremiumExtendedColors.kt:56-61
    static let trendsAccent = Color(hex: 0x5347D1)
    static let trendsOnAccent = Color(hex: 0xFFFFFF)
    static let trendsContainer = Color(hex: 0xD6D4F0)
    static let trendsOnContainer = Color(hex: 0x100B41)

    // Hero — cyan into deep cyan.
    // PremiumExtendedColors.kt:63-66
    static let heroTop = Color(hex: 0x26606C)
    static let heroBottom = Color(hex: 0x327683)
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

/// §4.6 — OCEAN, dark. Source: `PremiumExtendedColors.kt:69-110`.
private enum OceanDarkExtendedValues {
    // Teal — the closest hue to the Ocean primary, kept for the app's busiest feature.
    // PremiumExtendedColors.kt:71-76
    static let medicationsAccent = Color(hex: 0x8ADDCD)
    static let medicationsOnAccent = Color(hex: 0x084438)
    static let medicationsContainer = Color(hex: 0x1F5147)
    static let medicationsOnContainer = Color(hex: 0xCAF0E8)

    // Plum-magenta — the one warm step out of the cyan family, as in the brand set.
    // PremiumExtendedColors.kt:78-83
    static let cycleAccent = Color(hex: 0xDD8ACF)
    static let cycleOnAccent = Color(hex: 0x37062F)
    static let cycleContainer = Color(hex: 0x511F49)
    static let cycleOnContainer = Color(hex: 0xF0CAE9)

    // Blue — a clean step off teal so charts never read as the medications colour.
    // PremiumExtendedColors.kt:85-90
    static let vitalsAccent = Color(hex: 0x8AAEDD)
    static let vitalsOnAccent = Color(hex: 0x072143)
    static let vitalsContainer = Color(hex: 0x1F3551)
    static let vitalsOnContainer = Color(hex: 0xCADAF0)

    // Deep cyan (petrol) — the Ocean primary's own hue.
    // PremiumExtendedColors.kt:92-97
    static let appointmentsAccent = Color(hex: 0x8AC7DD)
    static let appointmentsOnAccent = Color(hex: 0x083546)
    static let appointmentsContainer = Color(hex: 0x1F4451)
    static let appointmentsOnContainer = Color(hex: 0xCAE5F0)

    // Indigo — the cross-feature screen, furthest from every single feature's hue.
    // PremiumExtendedColors.kt:99-104
    static let trendsAccent = Color(hex: 0x918ADD)
    static let trendsOnAccent = Color(hex: 0x08052E)
    static let trendsContainer = Color(hex: 0x241F51)
    static let trendsOnContainer = Color(hex: 0xCDCAF0)

    // Hero — cyan into deep cyan.
    // PremiumExtendedColors.kt:106-109
    static let heroTop = Color(hex: 0x1C4048)
    static let heroBottom = Color(hex: 0x26535C)
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
    /// §4.6 — OCEAN, light (`PremiumExtendedColors.kt:26`).
    static let oceanLight = SalusExtendedColors.light.replacingFeatureAccents(
        medications: OceanLightExtendedValues.medications,
        cycle: OceanLightExtendedValues.cycle,
        vitals: OceanLightExtendedValues.vitals,
        appointments: OceanLightExtendedValues.appointments,
        trends: OceanLightExtendedValues.trends,
        hero: OceanLightExtendedValues.hero
    )

    /// §4.6 — OCEAN, dark (`PremiumExtendedColors.kt:69`).
    static let oceanDark = SalusExtendedColors.dark.replacingFeatureAccents(
        medications: OceanDarkExtendedValues.medications,
        cycle: OceanDarkExtendedValues.cycle,
        vitals: OceanDarkExtendedValues.vitals,
        appointments: OceanDarkExtendedValues.appointments,
        trends: OceanDarkExtendedValues.trends,
        hero: OceanDarkExtendedValues.hero
    )
}
