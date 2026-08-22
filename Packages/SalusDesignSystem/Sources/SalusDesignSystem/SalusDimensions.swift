import SwiftUI

// Mirrors `salus-android/docs/design/design-tokens.md` §5–§8
// (Android: `core/designsystem/.../theme/Spacing.kt` and `theme/Shape.kt`).
//
// Android `dp` and iOS `pt` are the same unit of measure. The scale is 1:1 — a `16.dp`
// padding is `16` here, never converted.

/// §5 — spacing steps. Source: `Spacing.kt:7-12`.
///
/// Screens and components use these instead of ad-hoc values. Do not rely on SwiftUI's
/// default `VStack` spacing (8) implicitly — pass `spacing: SalusSpacing.sm` so the value is
/// visible and greppable, exactly as the Compose side does.
public enum SalusSpacing {
    public static let xs: CGFloat = 4 // Spacing.kt:7
    public static let sm: CGFloat = 8 // Spacing.kt:8
    public static let md: CGFloat = 12 // Spacing.kt:9
    public static let lg: CGFloat = 16 // Spacing.kt:10
    public static let xl: CGFloat = 24 // Spacing.kt:11
    public static let xxl: CGFloat = 32 // Spacing.kt:12

    package static var allTokens: [String: CGFloat] {
        ["xs": xs, "sm": sm, "md": md, "lg": lg, "xl": xl, "xxl": xxl]
    }
}

/// §6 — corner radii. Source: `Shape.kt:10-14`.
///
/// Cards sit on `large`, sheets and dialogs on `extraLarge` (`Shape.kt:7-8`). Use
/// `style: .continuous`: the squircle is the platform-correct rendering of the same radius
/// and reads as the same shape as Compose's circular rounding at these sizes.
public enum SalusShapes {
    public static let extraSmall: CGFloat = 8 // Shape.kt:10
    public static let small: CGFloat = 12 // Shape.kt:11
    public static let medium: CGFloat = 16 // Shape.kt:12
    public static let large: CGFloat = 24 // Shape.kt:13
    public static let extraLarge: CGFloat = 28 // Shape.kt:14

    /// A continuous-corner rectangle at one of the radii above.
    public static func rounded(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    public static var extraSmallShape: RoundedRectangle { rounded(extraSmall) }
    public static var smallShape: RoundedRectangle { rounded(small) }
    public static var mediumShape: RoundedRectangle { rounded(medium) }
    public static var largeShape: RoundedRectangle { rounded(large) }
    public static var extraLargeShape: RoundedRectangle { rounded(extraLarge) }

    /// The fully rounded pill Compose spells as `CircleShape` (`Shape.kt:8`). It is a shape,
    /// not a radius, so it carries no dimension token.
    public static var pill: Capsule { Capsule() }

    /// The five named corner radii.
    package static var allTokens: [String: CGFloat] {
        [
            "extraSmall": extraSmall,
            "small": small,
            "medium": medium,
            "large": large,
            "extraLarge": extraLarge
        ]
    }
}

/// §7 — elevation steps in dp. Source: `Spacing.kt:17-20`.
///
/// The token is the dp step; the iOS shadow is a translation of it, not a token. Two things
/// to respect: Material's elevation also tints the surface, so keep the card fill at
/// `surfaceContainerLowest` (§1) and let the shadow do the lifting; and in dark mode drop the
/// shadow entirely (opacity 0) — a black shadow on a `#0A0F0C` ground is invisible on
/// Android too, where the tonal tint carries the elevation instead.
public enum SalusElevation {
    /// Flat surfaces — no shadow.
    public static let none: CGFloat = 0 // Spacing.kt:17
    /// Every card. Light mode: `.shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)`.
    public static let card: CGFloat = 2 // Spacing.kt:18
    /// Raised controls. Light mode: `radius: 4, y: 2`.
    public static let raised: CGFloat = 4 // Spacing.kt:19
    /// Overlays. Light mode: `radius: 8, y: 4`.
    public static let overlay: CGFloat = 8 // Spacing.kt:20

    package static var allTokens: [String: CGFloat] {
        ["none": none, "card": card, "raised": raised, "overlay": overlay]
    }
}

/// §8 — minimum touch target. Source: `Spacing.kt:29`.
///
/// 44 is Apple's HIG floor; Salus uses 48 to stay identical to Android. This token exists for
/// the rows and buttons built by hand, where the visible content can be shorter than the
/// finger that has to hit it: `.frame(minWidth: 48, minHeight: 48).contentShape(Rectangle())`.
public enum SalusTouchTarget {
    public static let min: CGFloat = 48 // Spacing.kt:29

    package static var allTokens: [String: CGFloat] { ["min": min] }
}
