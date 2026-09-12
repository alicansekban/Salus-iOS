import SwiftUI

// Mirrors `salus-android/docs/design/design-tokens.md` §3 (M15: §14.1–14.3)
// (Android: `core/designsystem/.../theme/ExtendedColors.kt`).
//
// Colors with no Material role: one accent set per feature area, the shared status colors, the
// hero and AI gradients, and the five structural/metric roles of §3.6. Member names are kept
// byte-identical to the Kotlin ones so the two files stay diffable by eye.
//
// Every hex lives on its own named `private static let` below rather than inline in the
// `SalusExtendedColors` initializer: a `Color(hex:)` call as an initializer argument costs
// the type checker real time, and the nested `FeatureAccent(...)` calls multiply it.

/// One feature area's accent set. Mirrors `data class FeatureAccent`
/// (`ExtendedColors.kt:16-21`).
public struct FeatureAccent: Equatable, Sendable {
    /// Icons, emphasis, chart lines, filled controls.
    public var accent: Color
    /// Content drawn on top of `accent`.
    public var onAccent: Color
    /// The tinted fill behind the accent — icon circles, calendar bands, chips.
    public var container: Color
    /// Content drawn on top of `container`.
    public var onContainer: Color

    public init(accent: Color, onAccent: Color, container: Color, onContainer: Color) {
        self.accent = accent
        self.onAccent = onAccent
        self.container = container
        self.onContainer = onContainer
    }

    /// The four members keyed by name, for the token registry.
    package var allTokens: [String: Color] {
        [
            "accent": accent,
            "onAccent": onAccent,
            "container": container,
            "onContainer": onContainer
        ]
    }
}

/// A feature accent paired with the feature name it belongs to.
public struct SalusFeatureAccentEntry: Equatable, Sendable {
    public let name: String
    public let accent: FeatureAccent
}

/// A two-stop vertical gradient used for hero surfaces (the avatar, the Home hero band, the
/// Profile band). `top` is the lighter end, `bottom` the deeper end. Mirrors `data class
/// SalusGradient` (`ExtendedColors.kt:28-31`).
public struct SalusGradient: Equatable, Sendable {
    /// The lighter, upper stop.
    public let top: Color
    /// The deeper, lower stop.
    public let bottom: Color

    public init(top: Color, bottom: Color) {
        self.top = top
        self.bottom = bottom
    }

    /// A vertical gradient running `top` → `bottom`. The one place the port turns the two stops
    /// into a `LinearGradient`; nothing outside this package recombines them.
    public var vertical: LinearGradient {
        LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }
}

/// The Salus colors that sit outside the Material roles, for one theme: one accent set per
/// feature area, two shared status colors, and the hero gradient.
///
/// These are the brand (CLASSIC) values. A premium theme repaints the five feature accents and
/// the hero gradient from its own §4.6 set (`SalusPremiumExtendedColors.swift`); `success` and
/// `warning` are inherited from here by every palette and never move.
public struct SalusExtendedColors: Equatable, Sendable {
    public var medications: FeatureAccent
    public var cycle: FeatureAccent
    public var vitals: FeatureAccent
    public var appointments: FeatureAccent
    /// The only accent that is neither a green nor a rose (`ExtendedColors.kt:63-66`).
    /// The trends screen reports on every feature at once, so borrowing any one feature's
    /// color would have made it read as that feature's screen. Keep the indigo.
    public var trends: FeatureAccent

    /// §3.3 status color. There is no `error` here — error stays on the Material role.
    public var success: Color
    /// §3.3 status color.
    public var warning: Color
    /// §3.5 the hero gradient — the avatar, the Home hero band and the Profile band.
    public var hero: SalusGradient

    /// §3.4 the card edge — `outline` in both modes. Dark mode draws no card shadow, so this
    /// line carries the whole card (`ExtendedColors.kt:109`); in light mode it is a faint line
    /// next to the shadow.
    public var cardBorder: Color
    /// §3.4 the translucent wash behind a primary button, a FAB and a chart line — `primary`
    /// at 24 % dark / 16 % light (`ExtendedColors.kt:110`).
    public var accentGlow: Color
    /// §3.4 the small upper-case section label — `#10B981` dark / `#065F46` light
    /// (`ExtendedColors.kt:166,112`).
    public var overline: Color
    /// §3.4 a delta that moved the good way; follows the palette's `primary`
    /// (`ExtendedColors.kt:167,113`).
    public var metricUp: Color
    /// §3.4 a delta that moved the bad way, and missed doses — `tertiary`, rose in every
    /// palette, so "worse" never changes hue with the theme (`ExtendedColors.kt:168,114`).
    public var metricDown: Color
    /// §3.4 the two-stop border of the AI cards — `primary` → `tertiary`, recognisable as an AI
    /// surface across palettes (`ExtendedColors.kt:169-172,115-118`).
    public var aiGradient: SalusGradient

    /// The five feature accents in document order.
    public var featureAccents: [SalusFeatureAccentEntry] {
        [
            SalusFeatureAccentEntry(name: "medications", accent: medications),
            SalusFeatureAccentEntry(name: "cycle", accent: cycle),
            SalusFeatureAccentEntry(name: "vitals", accent: vitals),
            SalusFeatureAccentEntry(name: "appointments", accent: appointments),
            SalusFeatureAccentEntry(name: "trends", accent: trends)
        ]
    }

    /// The 20 feature accent colors of this theme, keyed `<feature>.<member>`.
    package var accentTokens: [String: Color] {
        var tokens: [String: Color] = [:]
        for entry in featureAccents {
            for (member, color) in entry.accent.allTokens {
                tokens["\(entry.name).\(member)"] = color
            }
        }
        return tokens
    }

    /// The two-status-colors of this theme.
    package var statusTokens: [String: Color] {
        ["success": success, "warning": warning]
    }

    /// The five accent-derived structural/metric roles of this theme.
    package var accentRoleTokens: [String: Color] {
        [
            "cardBorder": cardBorder,
            "accentGlow": accentGlow,
            "overline": overline,
            "metricUp": metricUp,
            "metricDown": metricDown
        ]
    }

    /// The gradient stops of this theme — the hero and the AI border — keyed `<role>.<stop>`.
    package var gradientTokens: [String: Color] {
        [
            "hero.top": hero.top,
            "hero.bottom": hero.bottom,
            "aiGradient.top": aiGradient.top,
            "aiGradient.bottom": aiGradient.bottom
        ]
    }
}

/// §3.1 / §3.3 / §3.5 — the light accent and gradient values. Source: `ExtendedColors.kt:49-90`.
private enum LightAccentPalette {
    // medications — ExtendedColors.kt:39-44
    static let medicationsAccent = Color(hex: 0x17876D)
    static let medicationsOnAccent = Color(hex: 0xFFFFFF)
    static let medicationsContainer = Color(hex: 0xC4EFE3)
    static let medicationsOnContainer = Color(hex: 0x063D33)

    // vitals — ExtendedColors.kt:51-56
    static let vitalsAccent = Color(hex: 0x3E8D5F)
    static let vitalsOnAccent = Color(hex: 0xFFFFFF)
    static let vitalsContainer = Color(hex: 0xCDEBD6)
    static let vitalsOnContainer = Color(hex: 0x0D2E1C)

    // appointments — ExtendedColors.kt:57-62.
    // §3.1 note: `accent` was historically the brand primary; in M15 the brand `primary` moved
    // to emerald-800 (`#065F46`), but appointments keeps its pre-M15 `#3E7D5F` accent — that is
    // not a copy-paste slip, do not "differentiate" it.
    static let appointmentsAccent = Color(hex: 0x3E7D5F)
    static let appointmentsOnAccent = Color(hex: 0xFFFFFF)
    static let appointmentsContainer = Color(hex: 0xD5E8DC)
    static let appointmentsOnContainer = Color(hex: 0x10281C)

    // trends — ExtendedColors.kt:67-72
    static let trendsAccent = Color(hex: 0x4F5AA8)
    static let trendsOnAccent = Color(hex: 0xFFFFFF)
    static let trendsContainer = Color(hex: 0xDEE0FF)
    static let trendsOnContainer = Color(hex: 0x00105C)

    // cycle — ExtendedColors.kt:75-80. The cycle accent is the tertiary role itself: "period"
    // is one hue app-wide, whether it is drawn as a feature accent or as a Material surface.
    static let cycleAccent = Color(hex: 0xE11D48) // TertiaryLight — rose-600
    static let cycleOnAccent = Color(hex: 0xFFFFFF) // OnTertiaryLight
    static let cycleContainer = Color(hex: 0xFFE4E6) // TertiaryContainerLight — rose-100
    static let cycleOnContainer = Color(hex: 0x881337) // OnTertiaryContainerLight — rose-900

    // §3.3 status colors
    static let success = Color(hex: 0x2E7D4F) // ExtendedColors.kt:84
    static let warning = Color(hex: 0xA66B00) // ExtendedColors.kt:85

    // §3.5 hero gradient — ExtendedColors.kt:86-89
    static let heroTop = Color(hex: 0x2C6B4F)
    static let heroBottom = Color(hex: 0x3E7D5F)
    static let hero = SalusGradient(top: heroTop, bottom: heroBottom)

    // §3.6 structural and metric roles — ExtendedColors.kt:109-118
    static let cardBorder = Color(hex: 0xD6E2DA) // OutlineLight
    static let accentGlow = Color(hex: 0x065F46).opacity(0.16) // PrimaryLight @ 16 %
    static let overline = Color(hex: 0x065F46) // PrimaryLight (emerald-800)
    static let metricUp = Color(hex: 0x065F46) // PrimaryLight
    static let metricDown = Color(hex: 0xE11D48) // TertiaryLight
    static let aiGradient = SalusGradient(top: Color(hex: 0x065F46), bottom: Color(hex: 0xE11D48)) // primary → tertiary

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

/// §3.2 / §3.3 / §3.5 — the dark accent and gradient values. Source: `ExtendedColors.kt:92-130`.
private enum DarkAccentPalette {
    // medications — ExtendedColors.kt:78-83
    static let medicationsAccent = Color(hex: 0x66D6B8)
    static let medicationsOnAccent = Color(hex: 0x00382D)
    static let medicationsContainer = Color(hex: 0x0F4A3D)
    static let medicationsOnContainer = Color(hex: 0xBFF2E3)

    // vitals — ExtendedColors.kt:90-95
    static let vitalsAccent = Color(hex: 0x86CFA1)
    static let vitalsOnAccent = Color(hex: 0x0C3A22)
    static let vitalsContainer = Color(hex: 0x245538)
    static let vitalsOnContainer = Color(hex: 0xD0EDD9)

    // appointments — ExtendedColors.kt:96-101
    static let appointmentsAccent = Color(hex: 0x8BD6B2)
    static let appointmentsOnAccent = Color(hex: 0x0A3B26)
    static let appointmentsContainer = Color(hex: 0x275B43)
    static let appointmentsOnContainer = Color(hex: 0xC4E8D2)

    // trends — ExtendedColors.kt:103-108
    static let trendsAccent = Color(hex: 0xBAC3FF)
    static let trendsOnAccent = Color(hex: 0x1E2578)
    static let trendsContainer = Color(hex: 0x363E90)
    static let trendsOnContainer = Color(hex: 0xDEE0FF)

    // cycle — ExtendedColors.kt:129-134. The cycle accent is the tertiary role itself — see the
    // light set.
    static let cycleAccent = Color(hex: 0xFB7185) // TertiaryDark — rose-400
    static let cycleOnAccent = Color(hex: 0x4C0519) // OnTertiaryDark — rose-950
    static let cycleContainer = Color(hex: 0x4C0519) // TertiaryContainerDark — rose-950
    static let cycleOnContainer = Color(hex: 0xFECDD3) // OnTertiaryContainerDark — rose-200

    // §3.3 status colors
    static let success = Color(hex: 0x7ED29A) // ExtendedColors.kt:124
    static let warning = Color(hex: 0xE5B85C) // ExtendedColors.kt:125

    // §3.5 hero gradient — ExtendedColors.kt:158-161. Subtle in dark: the hero rises out of the
    // app ground into the primary container instead of being a painted panel of its own.
    static let heroTop = Color(hex: 0x090D0B) // BackgroundDark
    static let heroBottom = Color(hex: 0x064E3B) // PrimaryContainerDark
    static let hero = SalusGradient(top: heroTop, bottom: heroBottom)

    // §3.6 structural and metric roles — ExtendedColors.kt:162-172
    static let cardBorder = Color(hex: 0x2A352E) // OutlineDark
    static let accentGlow = Color(hex: 0x34D399).opacity(0.24) // PrimaryDark @ 24 %
    static let overline = Color(hex: 0x10B981) // emerald-500 — the palette 500
    static let metricUp = Color(hex: 0x34D399) // PrimaryDark
    static let metricDown = Color(hex: 0xFB7185) // TertiaryDark
    static let aiGradient = SalusGradient(top: Color(hex: 0x34D399), bottom: Color(hex: 0xFB7185)) // primary → tertiary

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
    /// §3.1 / §3.3 / §3.5 / §3.6 — light.
    public static let light = SalusExtendedColors(
        medications: LightAccentPalette.medications,
        cycle: LightAccentPalette.cycle,
        vitals: LightAccentPalette.vitals,
        appointments: LightAccentPalette.appointments,
        trends: LightAccentPalette.trends,
        success: LightAccentPalette.success,
        warning: LightAccentPalette.warning,
        hero: LightAccentPalette.hero,
        cardBorder: LightAccentPalette.cardBorder,
        accentGlow: LightAccentPalette.accentGlow,
        overline: LightAccentPalette.overline,
        metricUp: LightAccentPalette.metricUp,
        metricDown: LightAccentPalette.metricDown,
        aiGradient: LightAccentPalette.aiGradient
    )

    /// §3.2 / §3.3 / §3.5 / §3.6 — dark.
    public static let dark = SalusExtendedColors(
        medications: DarkAccentPalette.medications,
        cycle: DarkAccentPalette.cycle,
        vitals: DarkAccentPalette.vitals,
        appointments: DarkAccentPalette.appointments,
        trends: DarkAccentPalette.trends,
        success: DarkAccentPalette.success,
        warning: DarkAccentPalette.warning,
        hero: DarkAccentPalette.hero,
        cardBorder: DarkAccentPalette.cardBorder,
        accentGlow: DarkAccentPalette.accentGlow,
        overline: DarkAccentPalette.overline,
        metricUp: DarkAccentPalette.metricUp,
        metricDown: DarkAccentPalette.metricDown,
        aiGradient: DarkAccentPalette.aiGradient
    )
}
