// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusOptionRow.kt:42-135`.
//
// Material → SwiftUI, and the three places the spelling differs:
//
//   `Surface(shape = CircleShape, …)`   → a `Button` whose label is drawn over
//                                         `SalusShapes.pill` — the same hand-drawn capsule
//                                         `SalusPillButton` documents, and for the same reason:
//                                         the row has to *draw* its 88 pt and be hittable across
//                                         exactly that.
//   `Modifier.selectable(role =         → `.buttonStyle(.plain)` plus the `.isSelected`
//    Role.RadioButton)`                   accessibility trait. VoiceOver then announces the row
//                                         once, selected or not, which is the whole point of
//                                         Kotlin drawing the radio mark by hand rather than
//                                         composing a second selectable `RadioButton`
//                                         (`SalusOptionRow.kt:99-103`).
//   `ImageVector`                       → an SF Symbol name, the same mapping `SalusIconBadge`
//                                         and `SalusPillButton` make.
//
// The five component dimensions come from `SalusOptionRowDefaults` (`SalusOptionRow.kt:127-135`).
// They are component values that live in `:core:ui` on Android too — not `design-tokens.md` tokens
// — so they are spelled here, exactly as `SalusIconBadge`'s 40/22 are.

import SalusDesignSystem
import SwiftUI

/// Pill-shaped single-choice row: a tinted icon circle, a label, and a radio indicator at the
/// trailing edge (`SalusOptionRow.kt:35-41`).
///
/// The whole row is the touch target — a separate radio control would give the user a second,
/// smaller thing to aim at for the same action. Pass the feature's `accent` to tint the icon
/// circle; it defaults to the primary role.
public struct SalusOptionRow: View {
    // Internal rather than private: the API test round-trips the selected flag and the accent
    // default, and neither is visible outside this module anyway.
    let systemImage: String
    let label: String
    let isSelected: Bool
    let accent: FeatureAccent?
    let onSelected: () -> Void

    @Environment(\.salusTheme) private var theme

    /// - Parameters:
    ///   - systemImage: SF Symbol name — the iOS twin of Kotlin's `ImageVector`
    ///     (`SalusOptionRow.kt:44`).
    ///   - accent: the feature accent that tints the icon circle, or nil for the primary role
    ///     (`SalusOptionRow.kt:49`).
    public init(
        systemImage: String,
        label: String,
        isSelected: Bool,
        accent: FeatureAccent? = nil,
        onSelected: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.label = label
        self.isSelected = isSelected
        self.accent = accent
        self.onSelected = onSelected
    }

    public var body: some View {
        Button(action: onSelected) {
            HStack(spacing: SalusSpacing.lg) {
                iconCircle
                // `Modifier.weight(1f)` (`SalusOptionRow.kt:92`).
                Text(verbatim: label)
                    .font(SalusTypography.titleMedium.font)
                    .tracking(SalusTypography.titleMedium.tracking)
                    .foregroundStyle(colors.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
                indicator
            }
            .padding(.horizontal, SalusSpacing.lg)
            // `heightIn(min = SalusOptionRowDefaults.Height)` on the surface
            // (`SalusOptionRow.kt:55-56`), so the capsule draws its full height rather than
            // reserving dead space around a short label.
            .frame(maxWidth: .infinity, minHeight: Self.height)
            .background(SalusShapes.pill.fill(SalusOptionRowStyle.container(selected: isSelected, colors: colors)))
            .overlay {
                if let border = SalusOptionRowStyle.border(selected: isSelected, colors: colors) {
                    SalusShapes.pill.stroke(border, lineWidth: Self.selectedBorder)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // Kotlin's `role = Role.RadioButton` (`SalusOptionRow.kt:57`), which is what makes a
        // screen reader say "selected" for the row rather than for a control inside it.
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// `SalusOptionRow.kt:75-87` — the icon in its tinted circle.
    private var iconCircle: some View {
        SalusShapes.pill
            .fill(SalusOptionRowStyle.iconBackground(accent: accent, colors: colors))
            .frame(width: Self.iconCircleSize, height: Self.iconCircleSize)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: Self.iconSize))
                    .foregroundStyle(SalusOptionRowStyle.iconTint(accent: accent, colors: colors))
            }
            // `contentDescription = null` (`SalusOptionRow.kt:83`): the label beside it already
            // says what the option is.
            .accessibilityHidden(true)
    }

    /// `SalusOptionRow.kt:104-125` — the radio mark, drawn rather than composed so it stays purely
    /// visual.
    private var indicator: some View {
        SalusShapes.pill
            .stroke(
                SalusOptionRowStyle.indicatorRing(selected: isSelected, colors: colors),
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

    /// `SalusOptionRowDefaults` (`SalusOptionRow.kt:127-135`). Component dimensions, not design
    /// tokens — Android keeps them in `:core:ui` too, not in `:core:designsystem`.
    private static let height: CGFloat = 88
    private static let iconCircleSize: CGFloat = 56
    private static let iconSize: CGFloat = 24
    private static let indicatorSize: CGFloat = 24
    private static let indicatorBorder: CGFloat = 2
    private static let indicatorDotSize: CGFloat = 12
    private static let selectedBorder: CGFloat = 2
}

/// The four colour decisions ``SalusOptionRow`` makes, lifted out of the view so they can be tested
/// without SwiftUI — the arrangement ``SalusDateFieldState`` sets.
enum SalusOptionRowStyle {
    /// `SalusOptionRow.kt:59-63`.
    static func container(selected: Bool, colors: SalusColorScheme) -> Color {
        selected ? colors.primaryContainer : colors.surfaceVariant
    }

    /// `SalusOptionRow.kt:64-68` — `null` rather than a transparent colour, because Kotlin passes
    /// no `BorderStroke` at all for an unselected row.
    static func border(selected: Bool, colors: SalusColorScheme) -> Color? {
        selected ? colors.primary : nil
    }

    /// `SalusOptionRow.kt:51`.
    static func iconTint(accent: FeatureAccent?, colors: SalusColorScheme) -> Color {
        accent?.accent ?? colors.primary
    }

    /// `SalusOptionRow.kt:52`.
    static func iconBackground(accent: FeatureAccent?, colors: SalusColorScheme) -> Color {
        accent?.container ?? colors.primaryContainer
    }

    /// `SalusOptionRow.kt:106-110`.
    static func indicatorRing(selected: Bool, colors: SalusColorScheme) -> Color {
        selected ? colors.primary : colors.outlineVariant
    }
}

#Preview("Option rows") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    return ZStack {
        theme.colorScheme.background
        VStack(spacing: SalusSpacing.lg) {
            // The two rows of `SalusOptionRowPreview` (`SalusOptionRow.kt:137-163`).
            SalusOptionRow(
                systemImage: "person",
                label: "Kadın",
                isSelected: false,
                accent: theme.extendedColors.cycle,
                onSelected: {}
            )
            SalusOptionRow(
                systemImage: "person.fill",
                label: "Erkek",
                isSelected: true,
                accent: theme.extendedColors.vitals,
                onSelected: {}
            )
            // The accent-less row, which Kotlin's preview does not draw.
            SalusOptionRow(systemImage: "person.2", label: "Diğer", isSelected: false) {}
        }
        .padding(SalusSpacing.lg)
    }
    .frame(height: 340)
    .salusTheme(theme)
}
