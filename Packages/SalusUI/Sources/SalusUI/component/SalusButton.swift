// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusButton.kt:38-201` in its M15 shape.
//
// The brand button: a pill in every variant and size, labelled `labelLarge`. Four variants and two
// sizes, decided in one place so every screen draws the same primary / secondary / outlined /
// destructive vocabulary (`SalusButton.kt:39-46`).
//
// Width is part of the size. `large` is the 56 pt full-width primary action of a screen; `medium` is
// the 44 pt button that wraps its own content. The pill is hand-drawn — `.buttonStyle(.plain)` over
// a `SalusShapes.pill` background — so the drawn capsule and its touch target are the same shape,
// the reason `SalusPillButton` documented (iOS-M7), carried into the renamed component.

import SalusDesignSystem
import SwiftUI

/// The brand button: a pill in every variant and size, labelled `labelLarge`.
public struct SalusButton: View {
    /// Weight of a button (`SalusButtonVariant`, `SalusButton.kt:43`). `destructive` is reserved
    /// for actions that delete data — using it for anything else spends the one colour the user
    /// has learned to stop at.
    public enum Variant {
        /// The screen's main action: `primary` fill, `onPrimary` text. In dark mode it carries
        /// the `accentGlow` wash that separates it from the ground.
        case primary
        /// A supporting action: `primaryContainer` fill, `onPrimaryContainer` text.
        case secondary
        /// The quiet way out: `cardBorder` stroke, `primary` text, no fill.
        case outlined
        /// A delete action: `error` fill, `onError` text.
        case destructive
    }

    /// `SalusButtonSize` (`SalusButton.kt:46`). `large` is the full-width primary action of a
    /// screen; `medium` wraps its own content.
    public enum Size {
        /// 56 pt, `fillMaxWidth()` — the screen's primary action (`SalusButton.kt:108-110`).
        case large
        /// 44 pt, content width (`SalusButton.kt:112-114`).
        case medium
    }

    private let title: String
    private let variant: Variant
    private let size: Size
    private let systemImage: String?
    private let accent: FeatureAccent?
    private let enabled: Bool
    private let action: () -> Void

    @Environment(\.salusTheme) private var theme

    /// - Parameters:
    ///   - title: the button's label, in `labelLarge`.
    ///   - variant: the button's weight (`SalusButton.kt:60`).
    ///   - size: width and height (`SalusButton.kt:61`).
    ///   - systemImage: SF Symbol name for the leading icon, which labels the action and leads
    ///     the text (`SalusButton.kt:149-156`). Kotlin takes an `ImageVector` from `Icons`; the
    ///     iOS twin of that catalogue is SF Symbols, named rather than referenced.
    ///   - accent: tints the primary variant with a feature's own colour; ignored by the other
    ///     variants, which carry meaning of their own a feature accent would overwrite
    ///     (`SalusButton.kt:48-53`).
    ///   - enabled: `false` dims the button to 0.38 and blocks it (`SalusButton.kt:62`).
    public init(
        _ title: String,
        variant: Variant = .primary,
        size: Size = .large,
        systemImage: String? = nil,
        accent: FeatureAccent? = nil,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.size = size
        self.systemImage = systemImage
        self.accent = accent
        self.enabled = enabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: SalusSpacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: Self.iconSize))
                }
                // `Text(verbatim:)` because `title` is already a resolved string — the plain
                // initializer would read it as a `LocalizedStringKey` against the main bundle
                // (the M7 `c726e22` finding).
                Text(verbatim: title)
                    .font(SalusTypography.labelLarge.font)
                    .tracking(SalusTypography.labelLarge.tracking)
            }
            .padding(.horizontal, contentPadding)
            .frame(
                maxWidth: size == .large ? .infinity : nil,
                minHeight: size == .large ? Self.largeHeight : Self.mediumHeight
            )
            .foregroundStyle(contentColor)
            .background(background)
            .contentShape(SalusShapes.pill)
        }
        .buttonStyle(.plain)
        // Kotlin passes `enabled` to the button, which swaps in `ButtonDefaults`' disabled colors;
        // the label draws those colors itself at 0.38 and keeps the flag for everything else —
        // the tap, VoiceOver's disabled trait, focus.
        .disabled(!enabled)
    }

    private var contentPadding: CGFloat {
        size == .large ? SalusSpacing.xl : SalusSpacing.lg
    }

    /// The variant's container — spelled per variant rather than left to Material, because its
    /// default disabled ground is a filled grey, which would give the outlined variant a fill it
    /// never has (`SalusButton.kt:66-97`). An accent tints only the primary fill.
    private var containerColor: Color {
        if !enabled {
            return colors.onSurface.opacity(Self.disabledContentAlpha)
        }
        return switch variant {
        case .primary: accent?.accent ?? colors.primary
        case .secondary: colors.primaryContainer
        case .outlined: Color.clear
        case .destructive: colors.error
        }
    }

    private var contentColor: Color {
        if !enabled {
            return colors.onSurface.opacity(Self.disabledContentAlpha)
        }
        return switch variant {
        case .primary: accent?.onAccent ?? colors.onPrimary
        case .secondary: colors.onPrimaryContainer
        case .outlined: colors.primary
        case .destructive: colors.onError
        }
    }

    private var background: some View {
        Group {
            if variant == .outlined {
                // `border = BorderStroke(cardBorder)` (`SalusButton.kt:129-136`).
                SalusShapes.pill.strokeBorder(
                    enabled ? theme.extendedColors.cardBorder : colors.onSurface.opacity(Self.disabledContentAlpha),
                    lineWidth: Self.borderWidth
                )
            } else {
                SalusShapes.pill.fill(containerColor)
            }
        }
        // The `accentGlow` shadow is what separates the primary action from the ground in dark
        // mode; in light mode the same wash under a saturated button only reads as a smudge, so
        // it is dropped (`SalusButton.kt:101-105`). The other variants carry a plain edge at most.
        .modifier(SalusButtonGlow(
            isDark: theme.isDark,
            variant: variant,
            enabled: enabled,
            color: theme.extendedColors.accentGlow
        ))
    }

    private var colors: SalusColorScheme { theme.colorScheme }

    /// `SalusButtonDefaults` (`SalusButton.kt:161-171`). Component dimensions, not design
    /// tokens — Android keeps them in `:core:ui` too, not in `:core:designsystem`.
    private static let largeHeight: CGFloat = 56
    private static let mediumHeight: CGFloat = 44
    private static let iconSize: CGFloat = 18
    private static let borderWidth: CGFloat = 1
    /// `SalusButtonDefaults.GlowElevation` (`SalusButton.kt:166`).
    private static let glowRadius: CGFloat = 12
    /// `SalusButtonDefaults.DisabledContentAlpha` (`SalusButton.kt:168`).
    static let disabledContentAlpha = 0.38
}

/// The dark-mode `accentGlow` wash that sits under the primary button, as a modifier so the
/// outlined variant can apply it only over its stroked capsule.
private struct SalusButtonGlow: ViewModifier {
    let isDark: Bool
    let variant: SalusButton.Variant
    let enabled: Bool
    let color: Color

    func body(content: Content) -> some View {
        if variant == .primary, enabled, isDark {
            content.shadow(color: color, radius: SalusButtonGlowDefaults.radius, x: 0, y: 0)
        } else {
            content
        }
    }
}

private enum SalusButtonGlowDefaults {
    static let radius: CGFloat = 12
}

#Preview("Buttons") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    ZStack {
        theme.colorScheme.background
        VStack(spacing: SalusSpacing.md) {
            SalusButton("Save", systemImage: "checkmark", action: {})
            SalusButton("Disabled", enabled: false, action: {})
            SalusButton("Later", variant: .secondary, action: {})
            SalusButton("Cancel", variant: .outlined, action: {})
            SalusButton("Delete", variant: .destructive, action: {})
            SalusButton("Edit — medium", size: .medium, action: {})
        }
        .padding(SalusSpacing.lg)
    }
    .frame(height: 420)
    .salusTheme(theme)
}

#Preview("Buttons — dark") {
    let theme = SalusTheme.resolve(systemIsDark: true)
    ZStack {
        theme.colorScheme.background
        VStack(spacing: SalusSpacing.md) {
            SalusButton("Save", action: {})
            SalusButton("Disabled", enabled: false, action: {})
            SalusButton("Later", variant: .secondary, action: {})
            SalusButton("Delete", variant: .destructive, action: {})
        }
        .padding(SalusSpacing.lg)
    }
    .frame(height: 360)
    .salusTheme(theme)
}
