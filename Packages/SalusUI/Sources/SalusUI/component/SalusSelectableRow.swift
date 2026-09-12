// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusSelectableRow.kt:45-107` in its M15 shape.
//
// Material → SwiftUI, and the places the spelling differs:
//
//   `Modifier.selectable(role = Role.RadioButton)` → a `Button` with the `.isSelected` accessibility
//     trait. VoiceOver then announces the row once, selected or not, which is the whole point of
//     Kotlin drawing the radio mark by hand (`SalusSelectableRow.kt:60-64`).
//   `leading` (a `@Composable` slot: a colour swatch or an icon) → `swatch: Color?` /
//     `systemImage: String?` + `accent`. The two leading shapes the M15 preview draws.
//   `ImageVector` → an SF Symbol name, the same mapping `SalusIconBadge` makes.
//
// The component dimensions come from `SalusSelectableRowDefaults` (`SalusSelectableRow.kt:109-114`).
// They are component values that live in `:core:ui` on Android too — not `design-tokens.md` tokens
// — so they are spelled here, exactly as `SalusIconBadge`'s 40/22 are.

import SalusDesignSystem
import SwiftUI

/// Single-choice row: a leading swatch or icon, a title (+ subtitle), and a radio indicator at the
/// trailing edge (`SalusSelectableRow.kt:56-68`).
///
/// The whole row is the touch target — a separate radio control would give the user a second,
/// smaller thing to aim at for the same action. Pass the feature's `accent` to tint the icon
/// circle; it defaults to the primary role.
public struct SalusSelectableRow: View {
    // Internal rather than private: the API test round-trips the selected flag and the accent
    // default, and neither is visible outside this module anyway.
    let title: String
    let subtitle: String?
    let swatch: Color?
    let systemImage: String?
    let accent: FeatureAccent?
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.salusTheme) private var theme

    /// - Parameters:
    ///   - title: the option's name, in `titleMedium`.
    ///   - subtitle: an optional supporting line, in `bodySmall`.
    ///   - swatch: a colour dot for palette rows (`SalusSelectableRowDefaults.SwatchSize`, 24 pt).
    ///     Mutually exclusive with `systemImage`, exactly as Kotlin's `leading` slot is one view.
    ///   - systemImage: SF Symbol name for an icon leading — the iOS twin of Kotlin's `ImageVector`.
    ///   - accent: the feature accent that tints the icon circle, or nil for the primary role
    ///     (`SalusSelectableRow.kt:51-52`).
    public init(
        title: String,
        subtitle: String? = nil,
        swatch: Color? = nil,
        systemImage: String? = nil,
        accent: FeatureAccent? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.swatch = swatch
        self.systemImage = systemImage
        self.accent = accent
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: SalusSpacing.lg) {
                leading
                // `Modifier.weight(1f)` (`SalusSelectableRow.kt:79`).
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: title)
                        .font(SalusTypography.titleMedium.font)
                        .tracking(SalusTypography.titleMedium.tracking)
                        .foregroundStyle(colors.onSurface)
                    if let subtitle {
                        Text(verbatim: subtitle)
                            .font(SalusTypography.bodySmall.font)
                            .tracking(SalusTypography.bodySmall.tracking)
                            .foregroundStyle(colors.onSurfaceVariant)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                indicator
            }
            .padding(.horizontal, SalusSpacing.lg)
            .frame(maxWidth: .infinity, minHeight: SalusTouchTarget.min)
            .background(SalusShapes.pill.fill(SalusSelectableRowStyle.container(selected: isSelected, colors: colors)))
            .overlay {
                if let border = SalusSelectableRowStyle.border(selected: isSelected, colors: colors) {
                    SalusShapes.pill.stroke(border, lineWidth: Self.selectedBorder)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // Kotlin's `role = Role.RadioButton` (`SalusSelectableRow.kt:63`), which is what makes a
        // screen reader say "selected" for the row rather than for a control inside it.
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// The option's own leading visual (`SalusSelectableRow.kt:69`).
    @ViewBuilder
    private var leading: some View {
        if let swatch {
            // The palette row's colour dot (`SalusSelectableRowDefaults.SwatchSize`).
            Circle()
                .fill(swatch)
                .frame(width: Self.swatchSize, height: Self.swatchSize)
                .accessibilityHidden(true)
        } else if let systemImage {
            // The icon in its tinted circle (`SalusSelectableRow.kt:75-87`).
            SalusShapes.pill
                .fill(SalusSelectableRowStyle.iconBackground(accent: accent, colors: colors))
                .frame(width: Self.iconCircleSize, height: Self.iconCircleSize)
                .overlay {
                    Image(systemName: systemImage)
                        .font(.system(size: Self.iconSize))
                        .foregroundStyle(SalusSelectableRowStyle.iconTint(accent: accent, colors: colors))
                }
                // `contentDescription = null` (`SalusSelectableRow.kt:83`): the label beside it
                // already says what the option is.
                .accessibilityHidden(true)
        }
    }

    /// `SalusSelectableRow.kt:104-125` — the radio mark, drawn rather than composed so it stays purely
    /// visual.
    private var indicator: some View {
        SalusShapes.pill
            .stroke(
                SalusSelectableRowStyle.indicatorRing(selected: isSelected, colors: colors),
                lineWidth: Self.indicatorBorder
            )
            .frame(width: Self.indicatorSize, height: Self.indicatorSize)
            .overlay {
                if isSelected {
                    SalusShapes.pill
                        .fill(colors.primary)
                        .frame(width: Self.indicatorDotSize, height: Self.indicatorDotSize)
                }
            }
            .accessibilityHidden(true)
    }

    private var colors: SalusColorScheme { theme.colorScheme }

    /// `SalusSelectableRowDefaults` (`SalusSelectableRow.kt:109-114`). Component dimensions, not
    /// design tokens — Android keeps them in `:core:ui` too, not in `:core:designsystem`.
    private static let swatchSize: CGFloat = 24
    private static let iconCircleSize: CGFloat = 56
    private static let iconSize: CGFloat = 24
    private static let indicatorSize: CGFloat = 24
    private static let indicatorBorder: CGFloat = 2
    private static let indicatorDotSize: CGFloat = 12
    private static let selectedBorder: CGFloat = 2
}

/// The four colour decisions ``SalusSelectableRow`` makes, lifted out of the view so they can be
/// tested without SwiftUI — the arrangement ``SalusDateFieldState`` sets.
enum SalusSelectableRowStyle {
    /// `SalusSelectableRow.kt:73`.
    static func container(selected: Bool, colors: SalusColorScheme) -> Color {
        selected ? colors.primaryContainer : colors.surfaceVariant
    }

    /// `SalusSelectableRow.kt:74` — `null` rather than a transparent colour, because Kotlin passes
    /// no `BorderStroke` at all for an unselected row.
    static func border(selected: Bool, colors: SalusColorScheme) -> Color? {
        selected ? colors.primary : nil
    }

    /// `SalusSelectableRow.kt:51`.
    static func iconTint(accent: FeatureAccent?, colors: SalusColorScheme) -> Color {
        accent?.accent ?? colors.primary
    }

    /// `SalusSelectableRow.kt:52`.
    static func iconBackground(accent: FeatureAccent?, colors: SalusColorScheme) -> Color {
        accent?.container ?? colors.primaryContainer
    }

    /// `SalusSelectableRow.kt:100-104`.
    static func indicatorRing(selected: Bool, colors: SalusColorScheme) -> Color {
        selected ? colors.primary : colors.outlineVariant
    }
}

#Preview("Selectable rows") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    ZStack {
        theme.colorScheme.background
        VStack(spacing: SalusSpacing.lg) {
            SalusSelectableRow(
                title: "Classic",
                subtitle: "The Salus emerald",
                swatch: theme.colorScheme.primary,
                isSelected: true
            ) {}
            SalusSelectableRow(
                title: "Rose",
                swatch: theme.extendedColors.metricDown,
                isSelected: false
            ) {}
            SalusSelectableRow(
                title: "Kadın",
                systemImage: "person",
                accent: theme.extendedColors.cycle,
                isSelected: false
            ) {}
        }
        .padding(SalusSpacing.lg)
    }
    .frame(height: 340)
    .salusTheme(theme)
}

#Preview("Selectable rows — dark") {
    let theme = SalusTheme.resolve(systemIsDark: true)
    ZStack {
        theme.colorScheme.background
        VStack(spacing: SalusSpacing.lg) {
            SalusSelectableRow(
                title: "Classic",
                subtitle: "The Salus emerald",
                swatch: theme.colorScheme.primary,
                isSelected: true
            ) {}
            SalusSelectableRow(
                title: "Kadın",
                systemImage: "person",
                accent: theme.extendedColors.cycle,
                isSelected: false
            ) {}
        }
        .padding(SalusSpacing.lg)
    }
    .frame(height: 200)
    .salusTheme(theme)
}
