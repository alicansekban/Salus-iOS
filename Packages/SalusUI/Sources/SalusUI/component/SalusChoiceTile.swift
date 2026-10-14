// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusChoiceTile.kt:53-140`.
//
// Kotlin's `subtitle` and `accent` (`SalusChoiceTile.kt:60-61`) were left out until iOS-M17: spec
// §3.3 names the tile as "icon + label tile for grids … selected = `primary` border + check badge",
// and every M16 grid that used one (medication form, sex, theme mode) is a plain icon-over-label.
// The smoking setup is the first caller of both — its mode and product tiles carry a caption and
// the feature's amber — so the knobs are ported now, with Kotlin's semantics: `accent` recolours
// the selected border, the icon and the check badge; `subtitle` is a `bodySmall` line under the label.
//
// **The glyph has two sources on both platforms.** Here it is a ``SalusChoiceTileGlyph`` — an SF
// Symbol name, or a line of text drawn in the same slot at the same size and tint; Kotlin spells
// the same pair as two `SalusChoiceTile` overloads, `icon: ImageVector` and `glyph: String`. Both
// text cases are shared: the app-language tiles' country flags (the 2026-09-13 merge). What is
// **divergence (aa) (owner QA round 2, C3)** is only the sex grid, which uses the text slot here —
// SF Symbols ships no venus, mars or transgender glyph, so all three tiles shared one neutral
// person symbol — while Kotlin has `Icons.Outlined.Female / Male / Transgender` for it
// (`ProfileScreen.kt:259-263`, `OnboardingPages.kt:379-383`). `SalusSexGlyph` is the one place the
// three Unicode signs are chosen; this component only knows how to draw a string where a symbol
// would go.

import SalusDesignSystem
import SwiftUI

/// What a ``SalusChoiceTile`` draws above its label: an SF Symbol, or a Unicode glyph for the signs
/// SF Symbols has none of (divergence (aa)).
public enum SalusChoiceTileGlyph: Equatable, Hashable, Sendable {
    /// SF Symbol name — the iOS twin of Kotlin's `ImageVector`, and what nearly every grid uses.
    case symbol(String)
    /// A short line of text — one or two characters — drawn where the symbol would be, at the same
    /// ``SalusChoiceTileDefaults/iconSize``, and in the same tint unless it is a colour emoji,
    /// which keeps its own colours. For the glyphs SF Symbols does not ship: `♀`, `♂`, `⚧` (see
    /// `SalusSexGlyph`) and the app-language tiles' country flags. Not a second label slot — the
    /// label is below.
    case text(String)
}

/// Icon-over-label tile for choice grids (medication form, sex, theme mode). Selection is carried
/// by the border and a check badge rather than by a fill, so the icon keeps its own colour and the
/// grid stays readable when several tiles sit side by side (`SalusChoiceTile.kt:47-50`).
public struct SalusChoiceTile: View {
    private let label: String
    private let glyph: SalusChoiceTileGlyph
    private let isSelected: Bool
    private let subtitle: String?
    private let accent: FeatureAccent?
    private let action: () -> Void

    @Environment(\.salusTheme) private var theme

    /// - Parameters:
    ///   - glyph: the SF Symbol or Unicode sign over the label (divergence (aa)).
    ///   - subtitle: a caption under the label (`SalusChoiceTile.kt:60`).
    ///   - accent: recolours the icon, the selected border and the badge for feature-owned grids;
    ///     `nil` is the primary role (`SalusChoiceTile.kt:61`).
    public init(
        label: String,
        glyph: SalusChoiceTileGlyph,
        isSelected: Bool,
        subtitle: String? = nil,
        accent: FeatureAccent? = nil,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.glyph = glyph
        self.isSelected = isSelected
        self.subtitle = subtitle
        self.accent = accent
        self.action = action
    }

    /// The SF Symbol spelling, which is what every grid but the sex one passes.
    /// - Parameter systemImage: SF Symbol name — the iOS twin of Kotlin's `ImageVector`.
    public init(
        label: String,
        systemImage: String,
        isSelected: Bool,
        subtitle: String? = nil,
        accent: FeatureAccent? = nil,
        action: @escaping () -> Void
    ) {
        self.init(
            label: label,
            glyph: .symbol(systemImage),
            isSelected: isSelected,
            subtitle: subtitle,
            accent: accent,
            action: action
        )
    }

    /// The colour of the selected border, the badge and the icon (`SalusChoiceTile.kt:141`).
    private var selectedColor: Color {
        accent?.accent ?? theme.colorScheme.primary
    }

    public var body: some View {
        Button(action: action) {
            // `Arrangement.spacedBy(SalusSpacing.sm)` in a centred column (`SalusChoiceTile.kt:89-93`).
            VStack(spacing: SalusSpacing.sm) {
                glyphView
                    .font(.system(size: SalusChoiceTileDefaults.iconSize))
                    .foregroundStyle(isSelected ? selectedColor : theme.colorScheme.onSurfaceVariant)
                    // `contentDescription = null` (`SalusChoiceTile.kt:96`): the label below it
                    // names the choice.
                    .accessibilityHidden(true)
                // `Text(verbatim:)` because `label` is already a resolved string.
                Text(verbatim: label)
                    .font(SalusTypography.labelLarge.font)
                    .tracking(SalusTypography.labelLarge.tracking)
                    .foregroundStyle(theme.colorScheme.onSurface)
                    .multilineTextAlignment(.center)
                if let subtitle {
                    Text(verbatim: subtitle)
                        .font(SalusTypography.bodySmall.font)
                        .tracking(SalusTypography.bodySmall.tracking)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(SalusSpacing.md)
            .frame(maxWidth: .infinity, minHeight: SalusTouchTarget.min)
            .background(SalusShapes.mediumShape.fill(theme.colorScheme.surfaceContainerHigh))
            .overlay { border }
            .overlay(alignment: .topTrailing) { badge }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: SalusMotion.feedbackDurationSeconds), value: isSelected)
        // `Role.RadioButton` (`SalusChoiceTile.kt:86`) — one of a set, and the set is the grid.
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// The two glyph sources in one slot: the font, the tint and the accessibility treatment are
    /// applied to whichever this answers, so a Unicode sign is the same size and colour as a symbol
    /// and neither is read out (divergence (aa)).
    ///
    /// `Text(verbatim:)` because the glyph is a literal sign, never a localised string — and the
    /// sign carries U+FE0E in `SalusSexGlyph`, which is what keeps it a glyph in the app's tint
    /// rather than a colour emoji.
    @ViewBuilder private var glyphView: some View {
        switch glyph {
        case let .symbol(name):
            Image(systemName: name)
        case let .text(sign):
            Text(verbatim: sign)
        }
    }

    /// `border(BorderStroke(borderWidth, borderColor), shape)` (`SalusChoiceTile.kt:85`), whose
    /// two ends are animated by the modifier above. `strokeBorder`, not `stroke`: the edge sits
    /// inside the tile, and a centred stroke would spill half its width past it.
    private var border: some View {
        SalusShapes.mediumShape.strokeBorder(
            isSelected ? selectedColor : theme.extendedColors.cardBorder,
            lineWidth: isSelected
                ? SalusChoiceTileDefaults.selectedBorderWidth
                : SalusChoiceTileDefaults.borderWidth
        )
    }

    /// `SalusChoiceTile.kt:115-130` — the check disc in the top-trailing corner while picked.
    @ViewBuilder
    private var badge: some View {
        if isSelected {
            SalusShapes.pill
                .fill(selectedColor)
                .frame(width: SalusChoiceTileDefaults.badgeSize, height: SalusChoiceTileDefaults.badgeSize)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: SalusChoiceTileDefaults.badgeIconSize))
                        .foregroundStyle(accent?.onAccent ?? theme.colorScheme.onPrimary)
                }
                // `contentDescription = null` (`SalusChoiceTile.kt:125`): the selected trait on
                // the button is what states the selection.
                .accessibilityHidden(true)
        }
    }
}

/// `object SalusChoiceTileDefaults` (`SalusChoiceTile.kt:134-140`). Component dimensions, not
/// design tokens — Android keeps them in `:core:ui` too.
public enum SalusChoiceTileDefaults {
    /// `SalusChoiceTileDefaults.IconSize` (`SalusChoiceTile.kt:135`).
    public static let iconSize: CGFloat = 28
    /// `SalusChoiceTileDefaults.BorderWidth` (`SalusChoiceTile.kt:136`).
    public static let borderWidth: CGFloat = 1
    /// `SalusChoiceTileDefaults.SelectedBorderWidth` (`SalusChoiceTile.kt:137`).
    public static let selectedBorderWidth: CGFloat = 1.5
    /// `SalusChoiceTileDefaults.BadgeSize` (`SalusChoiceTile.kt:138`).
    public static let badgeSize: CGFloat = 20
    /// `SalusChoiceTileDefaults.BadgeIconSize` (`SalusChoiceTile.kt:139`).
    public static let badgeIconSize: CGFloat = 14
}

#Preview("Choice tiles") {
    SalusPreviewPalettes {
        HStack(spacing: SalusSpacing.md) {
            SalusChoiceTile(label: "Tablet", systemImage: "pills", isSelected: true) {}
            SalusChoiceTile(label: "Syrup", systemImage: "drop", isSelected: false) {}
            SalusChoiceTile(label: "Injection", systemImage: "syringe", isSelected: false) {}
        }
        HStack(spacing: SalusSpacing.md) {
            SalusChoiceTile(label: "Dark", systemImage: "moon", isSelected: false, subtitle: "Always on") {}
            SalusChoiceTile(
                label: "Quit",
                systemImage: "timer",
                isSelected: true,
                subtitle: "Start the counter",
                accent: SalusTheme.resolve(systemIsDark: false).extendedColors.smoking
            ) {}
        }
    }
}
