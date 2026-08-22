import SwiftUI
import Testing

@testable import SalusDesignSystem

// Pinning tests for the design tokens.
//
// The single source of truth is `salus-android/docs/design/design-tokens.md`.
// Every literal below is copied out of that document by hand; the token sources are
// transcribed from the same document independently. A typo on either side fails here.
//
// The count assertions are the drift detector: the doc declares 213 tokens and
// 5 `FeatureAccent` sets. If a token is added, removed or renamed in the doc without the
// Swift side following, the totals stop matching.

/// One sampled color row: token name, the transcribed value, the hex spelled out in the doc.
typealias ColorSample = (name: String, actual: Color, expected: UInt32)

/// One sampled dimension row: token name, the transcribed value, the value spelled out in the doc.
typealias DimensionSample = (name: String, actual: CGFloat, expected: CGFloat)

/// One sampled type role: role name, the transcribed style, the doc's four §9.1/§9.2 metrics
/// and its §9.3 Dynamic Type reference style.
typealias TypeSample = (
    role: String,
    style: SalusTextStyle,
    size: CGFloat,
    lineHeight: CGFloat,
    weight: Font.Weight,
    tracking: CGFloat,
    dynamicTypeStyle: Font.TextStyle
)

@Suite("Design token counts (drift detector)")
struct DesignTokenCountTests {
    /// `design-tokens.md` declares 213 tokens across all groups.
    @Test("the package exposes exactly 213 tokens")
    func totalTokenCountIs213() {
        #expect(SalusTokens.allTokenCount == 213)
    }

    /// §3 declares five feature accent sets: medications, cycle, vitals, appointments, trends.
    @Test("there are exactly 5 FeatureAccent sets per theme")
    func featureAccentCountIs5() {
        #expect(SalusExtendedColors.light.featureAccents.count == 5)
        #expect(SalusExtendedColors.dark.featureAccents.count == 5)
        #expect(
            SalusExtendedColors.light.featureAccents.map(\.name)
                == ["medications", "cycle", "vitals", "appointments", "trends"]
        )
    }

    @Test("per-group token counts match the document")
    func perGroupCounts() {
        let counts = Dictionary(
            uniqueKeysWithValues: SalusTokens.groupCounts.map { ($0.group, $0.count) }
        )
        // §1 Material color roles — light
        #expect(counts["colors.light"] == 35)
        // §2 Material color roles — dark
        #expect(counts["colors.dark"] == 35)
        // §3.1 / §3.2 feature accents: 5 features x 4 members
        #expect(counts["featureAccents.light"] == 20)
        #expect(counts["featureAccents.dark"] == 20)
        // §3.3 success + warning, light and dark
        #expect(counts["statusColors"] == 4)
        // §4 four palettes x 8 roles x light+dark
        #expect(counts["premiumAccents"] == 64)
        // §5 spacing
        #expect(counts["spacing"] == 6)
        // §6 corner radii (the pill is `Capsule()`, not a radius token)
        #expect(counts["shapes"] == 5)
        // §7 elevation
        #expect(counts["elevation"] == 4)
        // §8 touch target
        #expect(counts["touchTarget"] == 1)
        // §9 six overridden + six inherited roles
        #expect(counts["typography"] == 12)
        // §10 motion
        #expect(counts["motion"] == 7)
        #expect(counts.count == 12)
    }
}

@Suite("Material color roles (§1, §2)")
struct MaterialColorRoleTests {
    @Test(
        "light roles match design-tokens.md §1",
        arguments: [
            ("primary", SalusColorScheme.light.primary, UInt32(0x3E7D5F)),
            ("onPrimary", SalusColorScheme.light.onPrimary, UInt32(0xFFFFFF)),
            ("primaryContainer", SalusColorScheme.light.primaryContainer, UInt32(0xC4E8D2)),
            ("tertiary", SalusColorScheme.light.tertiary, UInt32(0x9C5566)),
            ("error", SalusColorScheme.light.error, UInt32(0xBA1A1A)),
            ("background", SalusColorScheme.light.background, UInt32(0xEAF2EC)),
            ("outlineVariant", SalusColorScheme.light.outlineVariant, UInt32(0xC0CBC2)),
            ("scrim", SalusColorScheme.light.scrim, UInt32(0x000000)),
            // Cards are white, not tonal — see the callout under §1.
            (
                "surfaceContainerLowest", SalusColorScheme.light.surfaceContainerLowest,
                UInt32(0xFFFFFF)
            ),
            (
                "surfaceContainerHighest", SalusColorScheme.light.surfaceContainerHighest,
                UInt32(0xFFFFFF)
            )
        ] as [ColorSample]
    )
    func lightRole(_ sample: ColorSample) {
        #expect(sample.actual == Color(hex: sample.expected), "light \(sample.name)")
    }

    @Test(
        "dark roles match design-tokens.md §2",
        arguments: [
            ("primary", SalusColorScheme.dark.primary, UInt32(0x8BD6B2)),
            ("onPrimary", SalusColorScheme.dark.onPrimary, UInt32(0x0A3B26)),
            ("tertiaryContainer", SalusColorScheme.dark.tertiaryContainer, UInt32(0x653747)),
            ("errorContainer", SalusColorScheme.dark.errorContainer, UInt32(0x93000A)),
            ("background", SalusColorScheme.dark.background, UInt32(0x0A0F0C)),
            ("outline", SalusColorScheme.dark.outline, UInt32(0x8A938C)),
            ("inversePrimary", SalusColorScheme.dark.inversePrimary, UInt32(0x3E7D5F)),
            ("surfaceBright", SalusColorScheme.dark.surfaceBright, UInt32(0x303632)),
            (
                "surfaceContainerLowest", SalusColorScheme.dark.surfaceContainerLowest,
                UInt32(0x050807)
            ),
            (
                "surfaceContainerHighest", SalusColorScheme.dark.surfaceContainerHighest,
                UInt32(0x2D3430)
            )
        ] as [ColorSample]
    )
    func darkRole(_ sample: ColorSample) {
        #expect(sample.actual == Color(hex: sample.expected), "dark \(sample.name)")
    }
}

@Suite("Feature accents and status colors (§3)")
struct FeatureAccentTests {
    @Test(
        "light feature accents match design-tokens.md §3.1",
        arguments: [
            ("medications.accent", SalusExtendedColors.light.medications.accent, UInt32(0x17876D)),
            (
                "medications.onContainer", SalusExtendedColors.light.medications.onContainer,
                UInt32(0x063D33)
            ),
            ("cycle.container", SalusExtendedColors.light.cycle.container, UInt32(0xF8DCE2)),
            ("vitals.accent", SalusExtendedColors.light.vitals.accent, UInt32(0x3E8D5F)),
            // §3 callout: appointments deliberately equals the brand primary.
            (
                "appointments.accent", SalusExtendedColors.light.appointments.accent,
                UInt32(0x3E7D5F)
            ),
            ("trends.accent", SalusExtendedColors.light.trends.accent, UInt32(0x4F5AA8)),
            ("trends.onContainer", SalusExtendedColors.light.trends.onContainer, UInt32(0x00105C))
        ] as [ColorSample]
    )
    func lightAccent(_ sample: ColorSample) {
        #expect(sample.actual == Color(hex: sample.expected), "light \(sample.name)")
    }

    @Test(
        "dark feature accents match design-tokens.md §3.2",
        arguments: [
            ("medications.accent", SalusExtendedColors.dark.medications.accent, UInt32(0x66D6B8)),
            (
                "medications.onAccent", SalusExtendedColors.dark.medications.onAccent,
                UInt32(0x00382D)
            ),
            ("cycle.accent", SalusExtendedColors.dark.cycle.accent, UInt32(0xEC93A8)),
            ("vitals.accent", SalusExtendedColors.dark.vitals.accent, UInt32(0x86CFA1)),
            (
                "appointments.container", SalusExtendedColors.dark.appointments.container,
                UInt32(0x275B43)
            ),
            ("trends.accent", SalusExtendedColors.dark.trends.accent, UInt32(0xBAC3FF))
        ] as [ColorSample]
    )
    func darkAccent(_ sample: ColorSample) {
        #expect(sample.actual == Color(hex: sample.expected), "dark \(sample.name)")
    }

    @Test("status colors match design-tokens.md §3.3")
    func statusColors() {
        #expect(SalusExtendedColors.light.success == Color(hex: 0x2E7D4F))
        #expect(SalusExtendedColors.light.warning == Color(hex: 0xA66B00))
        #expect(SalusExtendedColors.dark.success == Color(hex: 0x7ED29A))
        #expect(SalusExtendedColors.dark.warning == Color(hex: 0xE5B85C))
    }
}

@Suite("Premium accent palettes (§4)")
struct PremiumAccentPaletteTests {
    @Test(
        "premium palettes match design-tokens.md §4",
        arguments: [
            // §4.1 CLASSIC is the brand palette itself.
            ("classicLight.primary", SalusPremiumAccents.classicLight.primary, UInt32(0x3E7D5F)),
            (
                "classicDark.onSecondaryContainer",
                SalusPremiumAccents.classicDark.onSecondaryContainer, UInt32(0xD3E8DB)
            ),
            // §4.2 OCEAN
            ("oceanLight.primary", SalusPremiumAccents.oceanLight.primary, UInt32(0x0E7490)),
            (
                "oceanDark.primaryContainer", SalusPremiumAccents.oceanDark.primaryContainer,
                UInt32(0x004E5F)
            ),
            // §4.3 SUNSET
            ("sunsetLight.primary", SalusPremiumAccents.sunsetLight.primary, UInt32(0xB4491F)),
            (
                "sunsetLight.secondaryContainer",
                SalusPremiumAccents.sunsetLight.secondaryContainer, UInt32(0xFFDBCF)
            ),
            (
                "sunsetDark.onPrimaryContainer", SalusPremiumAccents.sunsetDark.onPrimaryContainer,
                UInt32(0xFFDBCF)
            ),
            // §4.4 FOREST
            (
                "forestLight.secondaryContainer",
                SalusPremiumAccents.forestLight.secondaryContainer, UInt32(0xD7E8CD)
            ),
            ("forestDark.primary", SalusPremiumAccents.forestDark.primary, UInt32(0x95D888))
        ] as [ColorSample]
    )
    func premiumRole(_ sample: ColorSample) {
        #expect(sample.actual == Color(hex: sample.expected), "\(sample.name)")
    }

    @Test("CLASSIC equals the brand accent roles of §1/§2")
    func classicEqualsBrand() {
        #expect(SalusPremiumAccents.classicLight.primary == SalusColorScheme.light.primary)
        #expect(
            SalusPremiumAccents.classicLight.secondaryContainer
                == SalusColorScheme.light.secondaryContainer
        )
        #expect(SalusPremiumAccents.classicDark.primary == SalusColorScheme.dark.primary)
        #expect(SalusPremiumAccents.classicDark.onPrimary == SalusColorScheme.dark.onPrimary)
    }
}

@Suite("Dimensions (§5–§8)")
struct DimensionTokenTests {
    @Test(
        "spacing matches design-tokens.md §5",
        arguments: [
            ("xs", SalusSpacing.xs, CGFloat(4)),
            ("sm", SalusSpacing.sm, CGFloat(8)),
            ("md", SalusSpacing.md, CGFloat(12)),
            ("lg", SalusSpacing.lg, CGFloat(16)),
            ("xl", SalusSpacing.xl, CGFloat(24)),
            ("xxl", SalusSpacing.xxl, CGFloat(32))
        ] as [DimensionSample]
    )
    func spacing(_ sample: DimensionSample) {
        #expect(sample.actual == sample.expected, "SalusSpacing.\(sample.name)")
    }

    @Test(
        "corner radii match design-tokens.md §6",
        arguments: [
            ("extraSmall", SalusShapes.extraSmall, CGFloat(8)),
            ("small", SalusShapes.small, CGFloat(12)),
            ("medium", SalusShapes.medium, CGFloat(16)),
            ("large", SalusShapes.large, CGFloat(24)),
            ("extraLarge", SalusShapes.extraLarge, CGFloat(28))
        ] as [DimensionSample]
    )
    func cornerRadius(_ sample: DimensionSample) {
        #expect(sample.actual == sample.expected, "SalusShapes.\(sample.name)")
    }

    @Test(
        "elevation steps match design-tokens.md §7",
        arguments: [
            ("none", SalusElevation.none, CGFloat(0)),
            ("card", SalusElevation.card, CGFloat(2)),
            ("raised", SalusElevation.raised, CGFloat(4)),
            ("overlay", SalusElevation.overlay, CGFloat(8))
        ] as [DimensionSample]
    )
    func elevation(_ sample: DimensionSample) {
        #expect(sample.actual == sample.expected, "SalusElevation.\(sample.name)")
    }

    /// §8: 44 is Apple's HIG floor — Salus uses 48 to stay identical to Android.
    @Test("touch target is 48, not Apple's 44")
    func touchTarget() {
        #expect(SalusTouchTarget.min == 48)
    }
}

@Suite("Typography (§9)")
struct TypographyTokenTests {
    /// The last column is §9.3's Dynamic Type reference style: the curve the role follows,
    /// never the size to ship.
    @Test(
        "text styles match design-tokens.md §9.1/§9.2/§9.3",
        arguments: [
            ("headlineLarge", SalusTypography.headlineLarge, 32, 38, Font.Weight.bold, 0.0, Font.TextStyle.largeTitle),
            ("headlineMedium", SalusTypography.headlineMedium, 28, 34, Font.Weight.bold, 0.0, Font.TextStyle.title),
            ("headlineSmall", SalusTypography.headlineSmall, 24, 32, Font.Weight.semibold, 0.0, Font.TextStyle.title2),
            ("titleLarge", SalusTypography.titleLarge, 22, 28, Font.Weight.semibold, 0.0, Font.TextStyle.title3),
            ("titleMedium", SalusTypography.titleMedium, 16, 24, Font.Weight.semibold, 0.2, Font.TextStyle.headline),
            ("titleSmall", SalusTypography.titleSmall, 14, 20, Font.Weight.medium, 0.1, Font.TextStyle.subheadline),
            ("bodyLarge", SalusTypography.bodyLarge, 16, 24, Font.Weight.regular, 0.5, Font.TextStyle.body),
            ("bodyMedium", SalusTypography.bodyMedium, 14, 20, Font.Weight.regular, 0.2, Font.TextStyle.callout),
            ("bodySmall", SalusTypography.bodySmall, 12, 16, Font.Weight.regular, 0.4, Font.TextStyle.caption),
            ("labelLarge", SalusTypography.labelLarge, 14, 20, Font.Weight.medium, 0.1, Font.TextStyle.footnote),
            ("labelMedium", SalusTypography.labelMedium, 12, 16, Font.Weight.medium, 0.5, Font.TextStyle.caption),
            ("labelSmall", SalusTypography.labelSmall, 11, 16, Font.Weight.medium, 0.5, Font.TextStyle.caption2)
        ] as [TypeSample]
    )
    func textStyle(_ sample: TypeSample) {
        #expect(sample.style.size == sample.size, "\(sample.role).size")
        #expect(sample.style.lineHeight == sample.lineHeight, "\(sample.role).lineHeight")
        #expect(sample.style.weight == sample.weight, "\(sample.role).weight")
        #expect(sample.style.tracking == sample.tracking, "\(sample.role).tracking")
        #expect(
            sample.style.dynamicTypeStyle == sample.dynamicTypeStyle,
            "\(sample.role).dynamicTypeStyle"
        )
    }

    /// §9.2: display roles exist in the M3 baseline but Salus never draws them.
    @Test("display roles are not ported")
    func displayRolesAbsent() {
        let names = Set(SalusTypography.allTokens.keys)
        #expect(names.isDisjoint(with: ["displayLarge", "displayMedium", "displaySmall"]))
    }
}

@Suite("Motion (§10)")
struct MotionTokenTests {
    @Test("motion constants match design-tokens.md §10")
    func motionConstants() {
        #expect(SalusMotion.pushPopDurationSeconds == 0.4)
        #expect(SalusMotion.pushPopEasing == SalusTimingCurve(0.4, 0.0, 0.2, 1.0))
        #expect(SalusMotion.parallaxDivisor == 4)
        #expect(SalusMotion.enterZIndexPush == 1)
        #expect(SalusMotion.enterZIndexPop == -1)
    }

    @Test("tab-root transition is an instant swap and no screen resizes")
    func instantTabSwap() {
        #expect(SalusMotion.allTokens["tabRootTransition"] == SalusMotionToken.noTransition)
        #expect(SalusMotion.allTokens["sizeTransform"] == SalusMotionToken.noSizeTransform)
    }
}

@Suite("Hex initializer")
struct ColorHexInitializerTests {
    /// The doc's §0 initializer: an opaque sRGB color, never Display P3.
    @Test("hex initializer produces opaque sRGB components")
    func hexComponents() {
        #expect(
            Color(hex: 0x3E7D5F)
                == Color(
                    .sRGB,
                    red: Double(0x3E) / 255,
                    green: Double(0x7D) / 255,
                    blue: Double(0x5F) / 255,
                    opacity: 1
                )
        )
        #expect(Color(hex: 0xFFFFFF) == Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 1))
        #expect(Color(hex: 0x000000) == Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 1))
    }
}
