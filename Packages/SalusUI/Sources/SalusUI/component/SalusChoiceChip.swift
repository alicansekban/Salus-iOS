// The twin of Material 3's `ChoiceChip` (`SalusChoiceChip.kt:40-115`) — a selectable pill for
// single- or multi-choice rows (symptom pickers, filters). Selected fills with `primaryContainer`
// and `onPrimaryContainer` text; unselected is an outlined pill on the card ground.
//
// SwiftUI has no chip, so the metrics come from `SalusChoiceChipDefaults`
// (`SalusChoiceChip.kt:117-122`), which Android inherits without naming: 36 dp tall, a 1 dp
// `cardBorder` edge while unselected, `labelLarge` text, 16 dp of horizontal padding and 8 dp
// between the optional icon and the label. `design-tokens.md` carries no component sizes, so
// those numbers stay here rather than becoming tokens Android has no counterpart for; the
// paddings, radii and the touch target *are* tokens and are spelled as such.

import SalusDesignSystem
import SwiftUI

/// Selectable pill for single- or multi-choice rows: tap to toggle. Selected chips fill with
/// `primaryContainer` and read their label in `onPrimaryContainer`, exactly as Material's does
/// (`SalusChoiceChip.kt:57-77`).
public struct SalusChoiceChip: View {
    private let label: String
    private let isSelected: Bool
    private let systemImage: String?
    private let action: () -> Void

    @Environment(\.salusTheme) private var theme

    /// - Parameter systemImage: SF Symbol name for a leading icon inside the chip
    ///   (`SalusChoiceChip.kt:101-107`).
    public init(
        label: String,
        isSelected: Bool,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.isSelected = isSelected
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: SalusSpacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: Self.iconSize))
                } else if isSelected {
                    // `FilterChipDefaults`'s leading checkmark goes away in the M15
                    // `ChoiceChip` — the `primaryContainer` fill alone carries the selection, so
                    // the chip gains an icon slot for the caller's own leading symbol.
                    Image(systemName: "checkmark")
                        .font(.system(size: Self.iconSize))
                }
                // `Text(verbatim:)` because `label` is already a resolved string — the plain
                // initializer would re-read it as a `LocalizedStringKey` against the main bundle
                // (the M7 `c726e22` finding).
                Text(verbatim: label)
                    .font(SalusTypography.labelLarge.font)
                    .tracking(SalusTypography.labelLarge.tracking)
                    // A chip label is one short phrase ("1 hour before"); wrapping it would turn
                    // the row into a paragraph. Material's chip does not wrap either.
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? colors.onPrimaryContainer : colors.onSurfaceVariant)
            .padding(.horizontal, SalusSpacing.lg)
            // `minHeight`, not `height`: at the larger Dynamic Type sizes the label is taller
            // than the fixed 36 pt and the chip has to grow with it rather than clip.
            .frame(minHeight: Self.containerHeight)
            .background(background)
            // Compose's `minimumInteractiveComponentSize()`, which every Material chip applies:
            // the chip still *draws* 36 dp tall, but it is hittable across the full touch target.
            .frame(minHeight: SalusTouchTarget.min)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var colors: SalusColorScheme { theme.colorScheme }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            // `if (selected) primaryContainer` (`SalusChoiceChip.kt:60`).
            SalusShapes.pill.fill(colors.primaryContainer)
        } else {
            // `border(BorderStroke(if (selected) Transparent else cardBorder))`
            // (`SalusChoiceChip.kt:84-90`). `strokeBorder`, not `stroke`: the edge sits inside
            // the 36 dp box, and a centred stroke would spill half a point past it.
            SalusShapes.pill.strokeBorder(
                theme.extendedColors.cardBorder,
                lineWidth: Self.borderWidth
            )
        }
    }

    /// `SalusChoiceChipDefaults` (`SalusChoiceChip.kt:117-122`. Component dimensions, not design
    /// tokens.
    private static let containerHeight: CGFloat = 36
    private static let iconSize: CGFloat = 16
    private static let borderWidth: CGFloat = 1
}

#Preview("Choice chips") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    ZStack {
        theme.colorScheme.background
        HStack(spacing: SalusSpacing.sm) {
            SalusChoiceChip(label: "Cramps", isSelected: true, action: {})
            SalusChoiceChip(label: "Headache", isSelected: false, action: {})
            SalusChoiceChip(label: "Mood", isSelected: true, systemImage: "face.smiling", action: {})
        }
        .padding(SalusSpacing.lg)
    }
    .frame(height: 120)
    .salusTheme(theme)
}

#Preview("Choice chips — dark") {
    let theme = SalusTheme.resolve(systemIsDark: true)
    ZStack {
        theme.colorScheme.background
        HStack(spacing: SalusSpacing.sm) {
            SalusChoiceChip(label: "Cramps", isSelected: true, action: {})
            SalusChoiceChip(label: "Headache", isSelected: false, action: {})
        }
        .padding(SalusSpacing.lg)
    }
    .frame(height: 100)
    .salusTheme(theme)
}
