import Foundation
import SalusModel
import SwiftUI
import Testing

@testable import SalusDesignSystem

// Pinning tests for the per-palette extended colors: which feature accents and hero gradient a
// premium palette draws.
//
// Source of truth, transcribed from the Kotlin file rather than remembered:
// `salus-android/core/designsystem/.../theme/PremiumExtendedColors.kt`, tabulated in
// `salus-android/docs/design/design-tokens.md` §4.6. The Android twin of this suite is
// `PremiumExtendedColorsTest.kt`.
//
// The brand (CLASSIC) values are pinned by `SalusDesignTokensTests` against §3 and are not
// restated here; what this file asserts is that CLASSIC stays *identical* to them and that the
// three premium palettes land on §4.6's hexes.

/// Which of the five feature accents a parity row is about.
///
/// A `KeyPath<SalusExtendedColors, FeatureAccent>` would be the natural spelling, but `KeyPath`
/// does not conform to `Sendable` under Swift 6 strict concurrency, and `@Test(arguments:)`
/// requires the row type to. The `rawValue` doubles as the failure label.
enum PremiumAccentFeature: String, Sendable {
    case medications
    case cycle
    case vitals
    case appointments
    case trends

    func accent(of colors: SalusExtendedColors) -> FeatureAccent {
        switch self {
        case .medications: colors.medications
        case .cycle: colors.cycle
        case .vitals: colors.vitals
        case .appointments: colors.appointments
        case .trends: colors.trends
        }
    }
}

/// One feature-accent row: palette, mode, which accent, and its four hexes.
typealias PremiumAccentRow = (
    palette: PremiumTheme,
    dark: Bool,
    feature: PremiumAccentFeature,
    accent: UInt32,
    onAccent: UInt32,
    container: UInt32,
    onContainer: UInt32
)

/// One hero row: palette, mode, and the two gradient stops.
typealias PremiumHeroRow = (palette: PremiumTheme, dark: Bool, top: UInt32, bottom: UInt32)

/// The §4.6 tables. 3 premium palettes x 2 modes x 5 features.
enum PremiumExtendedColorTables {
    static let accents: [PremiumAccentRow] = [
        (.ocean, false, .medications, 0x1E7A68, 0xFFFFFF, 0xD4F0EA, 0x0B4136),
        (.ocean, false, .cycle, 0xBB2FA3, 0xFFFFFF, 0xF0D4EB, 0x410B38),
        (.ocean, false, .vitals, 0x2F6DBD, 0xFFFFFF, 0xD4E0F0, 0x0B2341),
        (.ocean, false, .appointments, 0x257592, 0xFFFFFF, 0xD4E8F0, 0x0B3341),
        (.ocean, false, .trends, 0x5347D1, 0xFFFFFF, 0xD6D4F0, 0x100B41),
        (.ocean, true, .medications, 0x8ADDCD, 0x084438, 0x1F5147, 0xCAF0E8),
        (.ocean, true, .cycle, 0xDD8ACF, 0x37062F, 0x511F49, 0xF0CAE9),
        (.ocean, true, .vitals, 0x8AAEDD, 0x072143, 0x1F3551, 0xCADAF0),
        (.ocean, true, .appointments, 0x8AC7DD, 0x083546, 0x1F4451, 0xCAE5F0),
        (.ocean, true, .trends, 0x918ADD, 0x08052E, 0x241F51, 0xCDCAF0),
        (.sunset, false, .medications, 0xAA552A, 0xFFFFFF, 0xF0DDD4, 0x411D0B),
        (.sunset, false, .cycle, 0xC83257, 0xFFFFFF, 0xF0D4DB, 0x410B19),
        (.sunset, false, .vitals, 0x876822, 0xFFFFFF, 0xF0E7D4, 0x41310B),
        (.sunset, false, .appointments, 0xC33D31, 0xFFFFFF, 0xF0D6D4, 0x41100B),
        (.sunset, false, .trends, 0xBD2F9A, 0xFFFFFF, 0xF0D4E9, 0x410B34),
        (.sunset, true, .medications, 0xDDA68A, 0x441C08, 0x51301F, 0xF0D6CA),
        (.sunset, true, .cycle, 0xDD8A9F, 0x330611, 0x511F2C, 0xF0CAD3),
        (.sunset, true, .vitals, 0xDDC48A, 0x473408, 0x51421F, 0xF0E4CA),
        (.sunset, true, .appointments, 0xDD918A, 0x380A06, 0x51241F, 0xF0CDCA),
        (.sunset, true, .trends, 0xDD8AC8, 0x37062A, 0x511F44, 0xF0CAE6),
        (.forest, false, .medications, 0x1F7D3E, 0xFFFFFF, 0xD4F0DD, 0x0B411D),
        (.forest, false, .cycle, 0xC3317A, 0xFFFFFF, 0xF0D4E2, 0x410B26),
        (.forest, false, .vitals, 0x447A1E, 0xFFFFFF, 0xDFF0D4, 0x22410B),
        (.forest, false, .appointments, 0x1F7A63, 0xFFFFFF, 0xD4F0E9, 0x0B4134),
        (.forest, false, .trends, 0x27749A, 0xFFFFFF, 0xD4E6F0, 0x0B2F41),
        (.forest, true, .medications, 0x8ADDA6, 0x08441C, 0x1F5130, 0xCAF0D6),
        (.forest, true, .cycle, 0xDD8AB4, 0x35061D, 0x511F38, 0xF0CADD),
        (.forest, true, .vitals, 0xADDD8A, 0x214508, 0x34511F, 0xD9F0CA),
        (.forest, true, .appointments, 0x8ADDC8, 0x084435, 0x1F5144, 0xCAF0E6),
        (.forest, true, .trends, 0x8AC2DD, 0x083246, 0x1F4051, 0xCAE3F0)
    ]

    /// 3 premium palettes x 2 modes, hero top/bottom.
    static let heroes: [PremiumHeroRow] = [
        (.ocean, false, 0x26606C, 0x327683),
        (.ocean, true, 0x1C4048, 0x26535C),
        (.sunset, false, 0x6C4326, 0x835432),
        (.sunset, true, 0x482E1C, 0x5C3C26),
        (.forest, false, 0x266C31, 0x32833F),
        (.forest, true, 0x1C4823, 0x265C2F)
    ]

    /// Every palette and mode, including CLASSIC.
    static let allPalettesAndModes: [(palette: PremiumTheme, dark: Bool)] = [
        (.classic, false), (.classic, true),
        (.ocean, false), (.ocean, true),
        (.sunset, false), (.sunset, true),
        (.forest, false), (.forest, true)
    ]
}

@Suite("CLASSIC is the brand extended set (PremiumExtendedColors.kt:294)")
struct ClassicExtendedColorsIdentityTests {
    @Test("CLASSIC returns the brand instance in both modes")
    func classicIsBrand() {
        #expect(SalusTheme.extendedColors(dark: false, premiumTheme: .classic) == .light)
        #expect(SalusTheme.extendedColors(dark: true, premiumTheme: .classic) == .dark)
    }

    @Test("the palette-less overload still answers the brand set")
    func defaultOverloadIsBrand() {
        #expect(SalusTheme.extendedColors(dark: false) == .light)
        #expect(SalusTheme.extendedColors(dark: true) == .dark)
    }
}

@Suite("resolve threads the palette into the extended colors (Theme.kt:97-98)")
struct PremiumExtendedColorsResolutionTests {
    @Test("a light OCEAN resolution draws the OCEAN light extended set")
    func oceanLight() {
        let resolved = SalusTheme.resolve(premiumTheme: .ocean, systemIsDark: false)
        #expect(resolved.extendedColors == .oceanLight)
    }

    @Test("a dark FOREST resolution draws the FOREST dark extended set")
    func forestDark() {
        let resolved = SalusTheme.resolve(premiumTheme: .forest, systemIsDark: true)
        #expect(resolved.extendedColors == .forestDark)
    }

    @Test("an explicit LIGHT mode ignores a dark system for the extended set too")
    func explicitLightModeWins() {
        let resolved = SalusTheme.resolve(mode: .light, premiumTheme: .sunset, systemIsDark: true)
        #expect(resolved.extendedColors == .sunsetLight)
    }
}

@Suite("Feature accent hex parity with Android (§4.6)")
struct PremiumExtendedColorsHexParityTests {
    @Test(
        "each feature accent matches PremiumExtendedColors.kt",
        arguments: PremiumExtendedColorTables.accents
    )
    func featureAccent(_ row: PremiumAccentRow) {
        let colors = SalusTheme.extendedColors(dark: row.dark, premiumTheme: row.palette)
        let feature = row.feature.accent(of: colors)
        let label = "\(row.palette.rawValue) dark=\(row.dark) \(row.feature.rawValue)"
        #expect(feature.accent == Color(hex: row.accent), "\(label) accent")
        #expect(feature.onAccent == Color(hex: row.onAccent), "\(label) onAccent")
        #expect(feature.container == Color(hex: row.container), "\(label) container")
        #expect(feature.onContainer == Color(hex: row.onContainer), "\(label) onContainer")
    }

    @Test(
        "each hero gradient matches PremiumExtendedColors.kt",
        arguments: PremiumExtendedColorTables.heroes
    )
    func hero(_ row: PremiumHeroRow) {
        let colors = SalusTheme.extendedColors(dark: row.dark, premiumTheme: row.palette)
        let label = "\(row.palette.rawValue) dark=\(row.dark)"
        #expect(colors.hero.top == Color(hex: row.top), "\(label) hero.top")
        #expect(colors.hero.bottom == Color(hex: row.bottom), "\(label) hero.bottom")
    }

    @Test("the table covers 3 palettes x 2 modes x 5 features, plus 6 hero rows")
    func tableIsComplete() {
        #expect(PremiumExtendedColorTables.accents.count == 30)
        #expect(PremiumExtendedColorTables.heroes.count == 6)
    }
}

@Suite("Status colors never move with the palette (§4.6)")
struct PremiumExtendedColorsStatusTests {
    @Test(
        "success and warning stay the brand values",
        arguments: PremiumExtendedColorTables.allPalettesAndModes
    )
    func statusColors(_ row: (palette: PremiumTheme, dark: Bool)) {
        let colors = SalusTheme.extendedColors(dark: row.dark, premiumTheme: row.palette)
        let brand: SalusExtendedColors = row.dark ? .dark : .light
        let label = "\(row.palette.rawValue) dark=\(row.dark)"
        #expect(colors.success == brand.success, "\(label) success")
        #expect(colors.warning == brand.warning, "\(label) warning")
    }
}

@Suite("WCAG AA over the §4.6 parity table")
struct PremiumExtendedColorsContrastTests {
    /// Relative luminance of an opaque `0xRRGGBB` per WCAG 2.1.
    static func relativeLuminance(_ hex: UInt32) -> Double {
        func channel(_ raw: UInt32) -> Double {
            let value = Double(raw) / 255
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let red = channel((hex >> 16) & 0xFF)
        let green = channel((hex >> 8) & 0xFF)
        let blue = channel(hex & 0xFF)
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    /// The WCAG contrast ratio `(lighter + 0.05) / (darker + 0.05)`.
    static func contrastRatio(_ one: UInt32, _ other: UInt32) -> Double {
        let first = relativeLuminance(one)
        let second = relativeLuminance(other)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    /// Deliberately the premium table only. The brand (CLASSIC) light set predates this rule and
    /// has two sub-AA pairs of its own (medications 4.45:1, vitals 4.05:1); asserting AA on it
    /// would be changing a shipped brand value from a test, which the port does not do.
    @Test(
        "both content pairs clear 4.5:1",
        arguments: PremiumExtendedColorTables.accents
    )
    func contentPairsClearAA(_ row: PremiumAccentRow) {
        let label = "\(row.palette.rawValue) dark=\(row.dark) \(row.feature.rawValue)"
        let onAccent = Self.contrastRatio(row.onAccent, row.accent)
        let onContainer = Self.contrastRatio(row.onContainer, row.container)
        #expect(onAccent >= 4.5, "\(label) onAccent/accent is \(onAccent)")
        #expect(onContainer >= 4.5, "\(label) onContainer/container is \(onContainer)")
    }

    @Test("the ratio helper agrees with the two WCAG anchors")
    func helperIsCalibrated() {
        // Black on white is the definitional 21:1; a color against itself is 1:1.
        #expect(abs(Self.contrastRatio(0x000000, 0xFFFFFF) - 21) < 0.001)
        #expect(abs(Self.contrastRatio(0x3E7D5F, 0x3E7D5F) - 1) < 0.001)
    }
}
