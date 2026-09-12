// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusChoiceTile.kt:53-140`.
//
// Kotlin's `subtitle` and `accent` (`SalusChoiceTile.kt:60-61`) are not ported: spec §3.3 names the
// tile as "icon + label tile for grids … selected = `primary` border + check badge", and every M16
// grid that uses one (medication form, sex, theme mode) is a plain icon-over-label. An unused knob
// is a knob that drifts.

import SalusDesignSystem
import SwiftUI

/// Icon-over-label tile for choice grids (medication form, sex, theme mode). Selection is carried
/// by the border and a check badge rather than by a fill, so the icon keeps its own colour and the
/// grid stays readable when several tiles sit side by side (`SalusChoiceTile.kt:47-50`).
public struct SalusChoiceTile: View {
    private let label: String
    private let systemImage: String
    private let isSelected: Bool
    private let action: () -> Void

    @Environment(\.salusTheme) private var theme

    /// - Parameter systemImage: SF Symbol name — the iOS twin of Kotlin's `ImageVector`.
    public init(
        label: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            // `Arrangement.spacedBy(SalusSpacing.sm)` in a centred column (`SalusChoiceTile.kt:89-93`).
            VStack(spacing: SalusSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: SalusChoiceTileDefaults.iconSize))
                    .foregroundStyle(isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant)
                    // `contentDescription = null` (`SalusChoiceTile.kt:96`): the label below it
                    // names the choice.
                    .accessibilityHidden(true)
                // `Text(verbatim:)` because `label` is already a resolved string.
                Text(verbatim: label)
                    .font(SalusTypography.labelLarge.font)
                    .tracking(SalusTypography.labelLarge.tracking)
                    .foregroundStyle(theme.colorScheme.onSurface)
                    .multilineTextAlignment(.center)
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

    /// `border(BorderStroke(borderWidth, borderColor), shape)` (`SalusChoiceTile.kt:85`), whose
    /// two ends are animated by the modifier above. `strokeBorder`, not `stroke`: the edge sits
    /// inside the tile, and a centred stroke would spill half its width past it.
    private var border: some View {
        SalusShapes.mediumShape.strokeBorder(
            isSelected ? theme.colorScheme.primary : theme.extendedColors.cardBorder,
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
                .fill(theme.colorScheme.primary)
                .frame(width: SalusChoiceTileDefaults.badgeSize, height: SalusChoiceTileDefaults.badgeSize)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: SalusChoiceTileDefaults.badgeIconSize))
                        .foregroundStyle(theme.colorScheme.onPrimary)
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
    }
}
