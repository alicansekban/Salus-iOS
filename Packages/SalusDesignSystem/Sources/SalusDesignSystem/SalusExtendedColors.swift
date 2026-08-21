import SwiftUI

// Mirrors `salus-android/docs/design/design-tokens.md` §3
// (Android: `core/designsystem/.../theme/ExtendedColors.kt`).
//
// Colors with no Material role: one accent set per feature area, plus two shared status
// colors. Member names are kept byte-identical to the Kotlin ones so the two files stay
// diffable by eye.

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
    public var allTokens: [String: Color] {
        [
            "accent": accent,
            "onAccent": onAccent,
            "container": container,
            "onContainer": onContainer,
        ]
    }
}

/// A feature accent paired with the feature name it belongs to.
public struct SalusFeatureAccentEntry: Equatable, Sendable {
    public let name: String
    public let accent: FeatureAccent
}

/// The Salus colors that sit outside the Material roles, for one theme.
///
/// The premium theme (§4) recolors Material accent roles only — these are unaffected by it.
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

    /// The five feature accents in document order.
    public var featureAccents: [SalusFeatureAccentEntry] {
        [
            SalusFeatureAccentEntry(name: "medications", accent: medications),
            SalusFeatureAccentEntry(name: "cycle", accent: cycle),
            SalusFeatureAccentEntry(name: "vitals", accent: vitals),
            SalusFeatureAccentEntry(name: "appointments", accent: appointments),
            SalusFeatureAccentEntry(name: "trends", accent: trends),
        ]
    }

    /// The 20 feature accent colors of this theme, keyed `<feature>.<member>`.
    public var accentTokens: [String: Color] {
        var tokens: [String: Color] = [:]
        for entry in featureAccents {
            for (member, color) in entry.accent.allTokens {
                tokens["\(entry.name).\(member)"] = color
            }
        }
        return tokens
    }

    /// The two status colors of this theme.
    public var statusTokens: [String: Color] {
        ["success": success, "warning": warning]
    }
}

extension SalusExtendedColors {
    /// §3.1 / §3.3 — light. Source: `ExtendedColors.kt:39-74`.
    ///
    /// `appointments` deliberately equals the brand `primary` — that is not a copy-paste
    /// slip, do not "differentiate" it.
    public static let light = SalusExtendedColors(
        medications: FeatureAccent(  // ExtendedColors.kt:39-44
            accent: Color(hex: 0x17876D),
            onAccent: Color(hex: 0xFFFFFF),
            container: Color(hex: 0xC4EFE3),
            onContainer: Color(hex: 0x063D33)
        ),
        cycle: FeatureAccent(  // ExtendedColors.kt:45-50
            accent: Color(hex: 0xAE5064),
            onAccent: Color(hex: 0xFFFFFF),
            container: Color(hex: 0xF8DCE2),
            onContainer: Color(hex: 0x451723)
        ),
        vitals: FeatureAccent(  // ExtendedColors.kt:51-56
            accent: Color(hex: 0x3E8D5F),
            onAccent: Color(hex: 0xFFFFFF),
            container: Color(hex: 0xCDEBD6),
            onContainer: Color(hex: 0x0D2E1C)
        ),
        appointments: FeatureAccent(  // ExtendedColors.kt:57-62
            accent: Color(hex: 0x3E7D5F),
            onAccent: Color(hex: 0xFFFFFF),
            container: Color(hex: 0xD5E8DC),
            onContainer: Color(hex: 0x10281C)
        ),
        trends: FeatureAccent(  // ExtendedColors.kt:67-72
            accent: Color(hex: 0x4F5AA8),
            onAccent: Color(hex: 0xFFFFFF),
            container: Color(hex: 0xDEE0FF),
            onContainer: Color(hex: 0x00105C)
        ),
        success: Color(hex: 0x2E7D4F),  // ExtendedColors.kt:73
        warning: Color(hex: 0xA66B00)  // ExtendedColors.kt:74
    )

    /// §3.2 / §3.3 — dark. Source: `ExtendedColors.kt:78-110`.
    public static let dark = SalusExtendedColors(
        medications: FeatureAccent(  // ExtendedColors.kt:78-83
            accent: Color(hex: 0x66D6B8),
            onAccent: Color(hex: 0x00382D),
            container: Color(hex: 0x0F4A3D),
            onContainer: Color(hex: 0xBFF2E3)
        ),
        cycle: FeatureAccent(  // ExtendedColors.kt:84-89
            accent: Color(hex: 0xEC93A8),
            onAccent: Color(hex: 0x4C1926),
            container: Color(hex: 0x5C2735),
            onContainer: Color(hex: 0xFBD5DE)
        ),
        vitals: FeatureAccent(  // ExtendedColors.kt:90-95
            accent: Color(hex: 0x86CFA1),
            onAccent: Color(hex: 0x0C3A22),
            container: Color(hex: 0x245538),
            onContainer: Color(hex: 0xD0EDD9)
        ),
        appointments: FeatureAccent(  // ExtendedColors.kt:96-101
            accent: Color(hex: 0x8BD6B2),
            onAccent: Color(hex: 0x0A3B26),
            container: Color(hex: 0x275B43),
            onContainer: Color(hex: 0xC4E8D2)
        ),
        trends: FeatureAccent(  // ExtendedColors.kt:103-108
            accent: Color(hex: 0xBAC3FF),
            onAccent: Color(hex: 0x1E2578),
            container: Color(hex: 0x363E90),
            onContainer: Color(hex: 0xDEE0FF)
        ),
        success: Color(hex: 0x7ED29A),  // ExtendedColors.kt:109
        warning: Color(hex: 0xE5B85C)  // ExtendedColors.kt:110
    )
}
