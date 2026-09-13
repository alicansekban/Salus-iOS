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
//   `badge` → `badge: String?` — the qualifying label drawn as an accent `SalusStatusChip`
//     ("Varsayılan" on the Classic palette row of the theme sheet, `SalusSelectableRow.kt:84-86`).
//   `locked` → `locked: Bool` — draws a 20 pt lock glyph in place of the radio mark, exactly as
//     Kotlin swaps `Icon(Lock)` for the `RadioButton` (`SalusSelectableRow.kt:87-99`). A locked
//     row stays clickable; what the tap does is the caller's decision.
//
// **The row has no ground of its own, and never had one in Kotlin.** `SalusSelectableRow.kt:56-68`
// is a bare `Row(fillMaxWidth().defaultMinSize(minHeight = SalusTouchTarget.min).selectable(…)
// .padding(horizontal = SalusSpacing.lg, vertical = SalusSpacing.md))` with `spacedBy(md)` — no
// `Surface`, no background, no border, in either state. Until owner QA round 3 (D1) this file drew
// a `surfaceVariant` pill under every row and a `primaryContainer` fill plus a `primary` stroke
// under the selected one, carried over from the pre-M16 `SalusOptionRow` it was renamed from while
// citing Kotlin lines that say something else. The selection is the radio mark alone, as on
// Android; the rows stack with no gap beyond their own `md` padding; and because each row applies
// the screen's `lg` itself, the sheet body around them needs no inset of its own.
//
// The component dimensions come from `SalusSelectableRowDefaults` (`SalusSelectableRow.kt:109-114`)
// — `LockSize` 20, `SwatchSize` 24. They are component values that live in `:core:ui` on Android
// too — not `design-tokens.md` tokens — so they are spelled here, exactly as `SalusIconBadge`'s
// 40/22 are. The icon tile is the one dimension Kotlin leaves to the caller, `leading` being a slot
// there: the only caller that passes an icon is the language sheet, at `SalusIconBadge(size =
// Small, iconSize = SmallIconSize)` (`LanguageSheet.kt:70-76`), and 24/14 is what is drawn here.

import SalusDesignSystem
import SwiftUI

/// Single-choice row: a leading swatch or icon, a title (+ subtitle), an optional badge, and a
/// radio indicator at the trailing edge (`SalusSelectableRow.kt:56-68`).
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
    let badge: String?
    let locked: Bool
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
    ///   - badge: a qualifying label drawn as an accent `SalusStatusChip` ("Varsayılan").
    ///   - locked: `true` draws a 20 pt lock glyph in place of the radio mark
    ///     (`SalusSelectableRow.kt:87-99`). Independent of `isSelected`: a locked row still reports
    ///     its selection state and stays clickable.
    public init(
        title: String,
        subtitle: String? = nil,
        swatch: Color? = nil,
        systemImage: String? = nil,
        accent: FeatureAccent? = nil,
        badge: String? = nil,
        locked: Bool = false,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.swatch = swatch
        self.systemImage = systemImage
        self.accent = accent
        self.badge = badge
        self.locked = locked
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            // `horizontalArrangement = Arrangement.spacedBy(SalusSpacing.md)`
            // (`SalusSelectableRow.kt:67`).
            HStack(spacing: SalusSpacing.md) {
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
                // A qualified option carries its badge between the label and the control
                // (`SalusSelectableRow.kt:84-86`).
                if let badge {
                    SalusStatusChip(label: badge, status: .accent)
                }
                indicator
            }
            // `padding(horizontal = SalusSpacing.lg, vertical = SalusSpacing.md)` over
            // `defaultMinSize(minHeight = SalusTouchTarget.min)` (`SalusSelectableRow.kt:59-65`):
            // the minimum is the padded row's, so a short row still clears the touch target and a
            // tall one is not clipped to it. No ground and no border in either state — the row is
            // transparent on whatever it is drawn over.
            .padding(.horizontal, SalusSpacing.lg)
            .padding(.vertical, SalusSpacing.md)
            .frame(maxWidth: .infinity, minHeight: SalusTouchTarget.min)
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
                        .font(.system(size: Self.iconGlyphSize))
                        .foregroundStyle(SalusSelectableRowStyle.iconTint(accent: accent, colors: colors))
                }
                // `contentDescription = null` (`SalusSelectableRow.kt:83`): the label beside it
                // already says what the option is.
                .accessibilityHidden(true)
        }
    }

    /// `SalusSelectableRow.kt:87-99` — a locked row swaps the radio mark for a 20 pt lock glyph, so
    /// it reads as "the thing the row offers is behind a subscription" rather than as a plain
    /// unselected option. The row stays tappable; opening the paywall is the caller's job.
    @ViewBuilder
    private var indicator: some View {
        if locked {
            Image(systemName: "lock.fill")
                .font(.system(size: Self.lockSize))
                .foregroundStyle(colors.onSurfaceVariant)
                .accessibilityHidden(true)
        } else {
            // The radio mark (`SalusSelectableRow.kt:104-125`).
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
    }

    private var colors: SalusColorScheme { theme.colorScheme }

    /// `SalusSelectableRowDefaults` (`SalusSelectableRow.kt:109-114`). Component dimensions, not
    /// design tokens — Android keeps them in `:core:ui` too, not in `:core:designsystem`.
    private static let swatchSize: CGFloat = 24
    /// The icon leading is Kotlin's caller-supplied slot, and its one caller is
    /// `SalusIconBadge(size = SalusIconBadgeDefaults.Small, iconSize = SmallIconSize)`
    /// (`LanguageSheet.kt:70-76`) — 24 / 14, the same 24 pt box the swatch fills. A larger tile
    /// (this file drew 56 / 24 until owner QA round 3) is what made an iOS row outgrow the twin's
    /// 48 pt, since nothing else in the row is that tall.
    private static let iconCircleSize: CGFloat = SalusIconBadgeDefaults.small
    private static let iconGlyphSize: CGFloat = SalusIconBadgeDefaults.smallIconSize
    private static let indicatorSize: CGFloat = 24
    private static let indicatorBorder: CGFloat = 2
    private static let indicatorDotSize: CGFloat = 12
    /// `SalusSelectableRowDefaults.LockSize` (`SalusSelectableRow.kt:111`).
    private static let lockSize: CGFloat = 20
}

/// The three colour decisions ``SalusSelectableRow`` makes, lifted out of the view so they can be
/// tested without SwiftUI — the arrangement ``SalusDateFieldState`` sets.
///
/// There is no container or border decision here: the row draws neither
/// (`SalusSelectableRow.kt:56-68`), so there is nothing for a state to swap.
enum SalusSelectableRowStyle {
    /// The icon tile's glyph tint — `SalusIconBadge`'s `accent`/`primary` pair, which is what
    /// Kotlin's `leading` slot hands the badge (`SalusIconBadge.kt:38-44`, `LanguageSheet.kt:70-76`).
    static func iconTint(accent: FeatureAccent?, colors: SalusColorScheme) -> Color {
        accent?.accent ?? colors.primary
    }

    /// The icon tile's ground, the other half of the same pair.
    static func iconBackground(accent: FeatureAccent?, colors: SalusColorScheme) -> Color {
        accent?.container ?? colors.primaryContainer
    }

    /// `RadioButtonDefaults.colors(selectedColor = primary, unselectedColor = onSurfaceVariant)`
    /// (`SalusSelectableRow.kt:100-103`). `onSurfaceVariant`, not `outlineVariant`: this file drew
    /// the lighter outline tone until owner QA round 3 (D1), which read as a disabled control next
    /// to the twin's.
    static func indicatorRing(selected: Bool, colors: SalusColorScheme) -> Color {
        selected ? colors.primary : colors.onSurfaceVariant
    }
}

/// The samples the palette fan-out renders — a view of its own for the reason
/// `SalusDateTilePreviewSamples` is: the swatch and the accent are palette-dependent, and the
/// swatch is the whole point of the theme sheet's row.
private struct SalusSelectableRowPreviewSamples: View {
    @Environment(\.salusTheme) private var theme

    var body: some View {
        // No gap between the rows: Android's callers stack them in a plain `Column`
        // (`ThemeSheet.kt:114-129`, `LanguageSheet.kt:64-79`) and each row's own `md` padding is
        // the whole separation.
        VStack(spacing: 0) {
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
    }
}

#Preview("Selectable rows") {
    SalusPreviewPalettes {
        SalusSelectableRowPreviewSamples()
    }
}
