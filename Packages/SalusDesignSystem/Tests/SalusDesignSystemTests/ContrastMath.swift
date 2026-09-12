import Foundation

/// WCAG 2.1 luminance and contrast helpers shared by the colour-contrast suites.
///
/// The premium-accent suite (`SalusPremiumExtendedColorsTests`) feeds raw `0xRRGGBB` literals
/// straight through; the scheme suite (`SalusColorSchemeContrastTests`) resolves `SwiftUI.Color`
/// roles, folds them back to their opaque sRGB hex, and reuses the same arithmetic. Both mirror
/// the Android twins' `Color.luminance()` computation (`SalusColorSchemeContrastTest.kt:80-84`,
/// `PremiumExtendedColorsTest.kt:160-164`).
enum ContrastMath {
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
}
