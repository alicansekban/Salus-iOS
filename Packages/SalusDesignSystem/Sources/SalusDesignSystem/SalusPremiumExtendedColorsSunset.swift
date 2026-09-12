import SwiftUI

// §4.6 — the SUNSET per-feature accents and hero gradient.
// See `SalusPremiumExtendedColors.swift` for how a palette is built and why the hexes are
// hoisted; the source of truth is `PremiumExtendedColors.kt`.

/// §4.6 — SUNSET, light. Source: `PremiumExtendedColors.kt:113-154`.
private enum SunsetLightExtendedValues {
    // Terracotta — the muted warm brown-orange nearest the Sunset primary.
    // PremiumExtendedColors.kt:115-120
    static let medicationsAccent = Color(hex: 0xAA552A)
    static let medicationsOnAccent = Color(hex: 0xFFFFFF)
    static let medicationsContainer = Color(hex: 0xF0DDD4)
    static let medicationsOnContainer = Color(hex: 0x411D0B)

    // Rose-red — the cycle hue of the brand set, pulled warmer.
    // PremiumExtendedColors.kt:122-127
    static let cycleAccent = Color(hex: 0xC83257)
    static let cycleOnAccent = Color(hex: 0xFFFFFF)
    static let cycleContainer = Color(hex: 0xF0D4DB)
    static let cycleOnContainer = Color(hex: 0x410B19)

    // Amber/gold — the lightest warm hue, so vitals charts read clearly.
    // PremiumExtendedColors.kt:129-134
    static let vitalsAccent = Color(hex: 0x876822)
    static let vitalsOnAccent = Color(hex: 0xFFFFFF)
    static let vitalsContainer = Color(hex: 0xF0E7D4)
    static let vitalsOnContainer = Color(hex: 0x41310B)

    // Coral — a red-orange that sits between terracotta and rose.
    // PremiumExtendedColors.kt:136-141
    static let appointmentsAccent = Color(hex: 0xC33D31)
    static let appointmentsOnAccent = Color(hex: 0xFFFFFF)
    static let appointmentsContainer = Color(hex: 0xF0D6D4)
    static let appointmentsOnContainer = Color(hex: 0x41100B)

    // Plum — the coolest of the warm five, the cross-feature colour.
    // PremiumExtendedColors.kt:143-148
    static let trendsAccent = Color(hex: 0xBD2F9A)
    static let trendsOnAccent = Color(hex: 0xFFFFFF)
    static let trendsContainer = Color(hex: 0xF0D4E9)
    static let trendsOnContainer = Color(hex: 0x410B34)

    // Hero — orange into burnt orange.
    // PremiumExtendedColors.kt:174-177
    static let heroTop = Color(hex: 0x6C4326)
    static let heroBottom = Color(hex: 0x835432)
    static let hero = SalusGradient(top: heroTop, bottom: heroBottom)

    // Accent-derived roles, restated from the palette's own primary (0x9A3412, orange-800).
    // PremiumExtendedColors.kt:178-181
    static let accentGlow = Color(hex: 0x9A3412).opacity(0.16)
    static let overline = Color(hex: 0x9A3412)
    static let metricUp = Color(hex: 0x9A3412)
    static let aiGradientTop = Color(hex: 0x9A3412)

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

/// §4.6 — SUNSET, dark. Source: `PremiumExtendedColors.kt:156-197`.
private enum SunsetDarkExtendedValues {
    // Terracotta — the muted warm brown-orange nearest the Sunset primary.
    // PremiumExtendedColors.kt:158-163
    static let medicationsAccent = Color(hex: 0xDDA68A)
    static let medicationsOnAccent = Color(hex: 0x441C08)
    static let medicationsContainer = Color(hex: 0x51301F)
    static let medicationsOnContainer = Color(hex: 0xF0D6CA)

    // Rose-red — the cycle hue of the brand set, pulled warmer.
    // PremiumExtendedColors.kt:165-170
    static let cycleAccent = Color(hex: 0xDD8A9F)
    static let cycleOnAccent = Color(hex: 0x330611)
    static let cycleContainer = Color(hex: 0x511F2C)
    static let cycleOnContainer = Color(hex: 0xF0CAD3)

    // Amber/gold — the lightest warm hue, so vitals charts read clearly.
    // PremiumExtendedColors.kt:172-177
    static let vitalsAccent = Color(hex: 0xDDC48A)
    static let vitalsOnAccent = Color(hex: 0x473408)
    static let vitalsContainer = Color(hex: 0x51421F)
    static let vitalsOnContainer = Color(hex: 0xF0E4CA)

    // Coral — a red-orange that sits between terracotta and rose.
    // PremiumExtendedColors.kt:179-184
    static let appointmentsAccent = Color(hex: 0xDD918A)
    static let appointmentsOnAccent = Color(hex: 0x380A06)
    static let appointmentsContainer = Color(hex: 0x51241F)
    static let appointmentsOnContainer = Color(hex: 0xF0CDCA)

    // Plum — the coolest of the warm five, the cross-feature colour.
    // PremiumExtendedColors.kt:186-191
    static let trendsAccent = Color(hex: 0xDD8AC8)
    static let trendsOnAccent = Color(hex: 0x37062A)
    static let trendsContainer = Color(hex: 0x511F44)
    static let trendsOnContainer = Color(hex: 0xF0CAE6)

    // Hero — the app ground rising into the Sunset primary container.
    // PremiumExtendedColors.kt:221-224
    static let heroTop = Color(hex: 0x090D0B) // BackgroundDark
    static let heroBottom = Color(hex: 0x7C2D12) // Sunset dark primaryContainer (orange-900)
    static let hero = SalusGradient(top: heroTop, bottom: heroBottom)

    // Accent-derived roles, restated from the palette's own primary (0xFB923C, orange-400).
    // PremiumExtendedColors.kt:225-228
    static let accentGlow = Color(hex: 0xFB923C).opacity(0.24)
    static let overline = Color(hex: 0xF97316) // orange-500
    static let metricUp = Color(hex: 0xFB923C)
    static let aiGradientTop = Color(hex: 0xFB923C)

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
    /// §4.6 — SUNSET, light (`PremiumExtendedColors.kt:137`).
    static let sunsetLight = SalusExtendedColors.light.replacingFeatureAccents(
        medications: SunsetLightExtendedValues.medications,
        cycle: SunsetLightExtendedValues.cycle,
        vitals: SunsetLightExtendedValues.vitals,
        appointments: SunsetLightExtendedValues.appointments,
        trends: SunsetLightExtendedValues.trends,
        hero: SunsetLightExtendedValues.hero
    )
    .restatingAccentDerivedRoles(
        accentGlow: SunsetLightExtendedValues.accentGlow,
        overline: SunsetLightExtendedValues.overline,
        metricUp: SunsetLightExtendedValues.metricUp,
        aiGradientTop: SunsetLightExtendedValues.aiGradientTop
    )

    /// §4.6 — SUNSET, dark (`PremiumExtendedColors.kt:184`).
    static let sunsetDark = SalusExtendedColors.dark.replacingFeatureAccents(
        medications: SunsetDarkExtendedValues.medications,
        cycle: SunsetDarkExtendedValues.cycle,
        vitals: SunsetDarkExtendedValues.vitals,
        appointments: SunsetDarkExtendedValues.appointments,
        trends: SunsetDarkExtendedValues.trends,
        hero: SunsetDarkExtendedValues.hero
    )
    .restatingAccentDerivedRoles(
        accentGlow: SunsetDarkExtendedValues.accentGlow,
        overline: SunsetDarkExtendedValues.overline,
        metricUp: SunsetDarkExtendedValues.metricUp,
        aiGradientTop: SunsetDarkExtendedValues.aiGradientTop
    )
}
