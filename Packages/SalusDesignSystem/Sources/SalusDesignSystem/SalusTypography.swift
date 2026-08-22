import SwiftUI

// Mirrors `salus-android/docs/design/design-tokens.md` §9
// (Android: `core/designsystem/.../theme/Type.kt`).
//
// No custom font is bundled — Roboto on Android, SF here, both driven by the system
// font-size setting. `sp` and `pt` are the same unit; the difference is only how the system
// scales them.
//
// Four rules for this file's callers:
//   1. Keep the numeric sizes, not SF's semantic styles. `.body` is 17pt, not 16 — shipping
//      it where Android draws 16sp makes every screen drift. `dynamicTypeStyle` is only for
//      choosing the Dynamic Type curve.
//   2. Scale exactly once. `Font.system(size:weight:)` already scales with Dynamic Type. Do
//      not additionally multiply by `UIFontMetrics`, `@ScaledMetric`, or any home-grown
//      factor.
//   3. Line height: SF's natural line height is already tighter than M3's, and the two roles
//      Salus tightens (`headlineLarge` 40→38, `headlineMedium` 36→34) tighten toward SF's
//      natural metric. Use SwiftUI's default line height and add no `.lineSpacing()`.
//      `lineHeight` is carried here as the transcribed token, not as something to apply.
//   4. Letter spacing: apply with `.tracking(_:)` in points. `0.0` rows need no modifier.

/// One type role: the four metrics the design doc lists, plus the SwiftUI font built from
/// them.
public struct SalusTextStyle: Equatable, Sendable {
    /// Point size — the Android `sp` value, 1:1.
    public let size: CGFloat
    /// The M3 line height in points. Carried for parity; see rule 3 above before applying it.
    public let lineHeight: CGFloat
    public let weight: Font.Weight
    /// Letter spacing in points, applied with `.tracking(_:)`.
    public let tracking: CGFloat
    /// The Dynamic Type curve this role should follow — never the size to ship.
    public let dynamicTypeStyle: Font.TextStyle

    /// The font to draw with. Scales with Dynamic Type on its own; never scale it again.
    public var font: Font { .system(size: size, weight: weight) }
}

/// §9 — the twelve type roles Salus draws.
///
/// Six are overridden in `Type.kt` (§9.1); six are inherited unchanged from the Material 3
/// baseline (§9.2) and spelled out here so nothing has to be looked up.
/// `displayLarge` / `displayMedium` / `displaySmall` exist in the baseline but Salus never
/// draws them, so they are deliberately absent.
public enum SalusTypography {
    // §9.1 — overridden roles.

    /// Bold; baseline was 32/40/Regular. Source: `Type.kt:12-16`.
    public static let headlineLarge = SalusTextStyle(
        size: 32, lineHeight: 38, weight: .bold, tracking: 0.0, dynamicTypeStyle: .largeTitle
    )
    /// Bold; baseline was 28/36/Regular. Source: `Type.kt:17-21`.
    public static let headlineMedium = SalusTextStyle(
        size: 28, lineHeight: 34, weight: .bold, tracking: 0.0, dynamicTypeStyle: .title
    )
    /// Weight only (was Regular). Source: `Type.kt:22-24`.
    public static let headlineSmall = SalusTextStyle(
        size: 24, lineHeight: 32, weight: .semibold, tracking: 0.0, dynamicTypeStyle: .title2
    )
    /// Weight only (was Regular). Source: `Type.kt:25-27`.
    public static let titleLarge = SalusTextStyle(
        size: 22, lineHeight: 28, weight: .semibold, tracking: 0.0, dynamicTypeStyle: .title3
    )
    /// Weight only (was Medium). Source: `Type.kt:28-30`.
    public static let titleMedium = SalusTextStyle(
        size: 16, lineHeight: 24, weight: .semibold, tracking: 0.2, dynamicTypeStyle: .headline
    )
    /// Weight restated (already Medium). Source: `Type.kt:31-33`.
    public static let labelLarge = SalusTextStyle(
        size: 14, lineHeight: 20, weight: .medium, tracking: 0.1, dynamicTypeStyle: .footnote
    )

    // §9.2 — inherited M3 baseline roles the app draws.

    public static let titleSmall = SalusTextStyle(
        size: 14, lineHeight: 20, weight: .medium, tracking: 0.1, dynamicTypeStyle: .subheadline
    )
    public static let bodyLarge = SalusTextStyle(
        size: 16, lineHeight: 24, weight: .regular, tracking: 0.5, dynamicTypeStyle: .body
    )
    public static let bodyMedium = SalusTextStyle(
        size: 14, lineHeight: 20, weight: .regular, tracking: 0.2, dynamicTypeStyle: .callout
    )
    public static let bodySmall = SalusTextStyle(
        size: 12, lineHeight: 16, weight: .regular, tracking: 0.4, dynamicTypeStyle: .caption
    )
    public static let labelMedium = SalusTextStyle(
        size: 12, lineHeight: 16, weight: .medium, tracking: 0.5, dynamicTypeStyle: .caption
    )
    public static let labelSmall = SalusTextStyle(
        size: 11, lineHeight: 16, weight: .medium, tracking: 0.5, dynamicTypeStyle: .caption2
    )

    /// The twelve roles keyed by Material role name.
    public static var allTokens: [String: SalusTextStyle] {
        [
            "headlineLarge": headlineLarge,
            "headlineMedium": headlineMedium,
            "headlineSmall": headlineSmall,
            "titleLarge": titleLarge,
            "titleMedium": titleMedium,
            "titleSmall": titleSmall,
            "bodyLarge": bodyLarge,
            "bodyMedium": bodyMedium,
            "bodySmall": bodySmall,
            "labelLarge": labelLarge,
            "labelMedium": labelMedium,
            "labelSmall": labelSmall
        ]
    }
}
