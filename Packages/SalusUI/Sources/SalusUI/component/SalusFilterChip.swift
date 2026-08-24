// The twin of Material 3's `FilterChip` as Kotlin uses it — bare, with no color or shape overrides
// — in `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/appointments/
// ui/editor/AppointmentEditorScreen.kt:316-320` (the reminder-offset row).
//
// SwiftUI has no chip, so the metrics come from Material 3's `FilterChipDefaults`, which Android
// inherits without naming: 32 dp tall, a 1 dp `outline` border while unselected, a
// `secondaryContainer` fill and a leading checkmark once selected, `labelLarge` text, 16 dp of
// horizontal padding and 8 dp between the checkmark and the label. `design-tokens.md` carries no
// component sizes, so those four numbers stay here rather than becoming tokens Android has no
// counterpart for; the paddings, radii and the touch target *are* tokens and are spelled as such.

import SalusDesignSystem
import SwiftUI

/// Multi-select filter chip: tap to toggle. Selected chips lead with a checkmark, exactly as
/// Material's does (`FilterChipDefaults`' `selectedIcon` slot, which Kotlin leaves at its default).
public struct SalusFilterChip: View {
    private let label: String
    private let isSelected: Bool
    private let action: () -> Void

    @Environment(\.salusTheme) private var theme

    public init(label: String, isSelected: Bool, action: @escaping () -> Void) {
        self.label = label
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: SalusSpacing.sm) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: Self.iconSize))
                }
                Text(label)
                    .font(SalusTypography.labelLarge.font)
                    .tracking(SalusTypography.labelLarge.tracking)
            }
            .foregroundStyle(isSelected ? colors.onSecondaryContainer : colors.onSurfaceVariant)
            .padding(.horizontal, SalusSpacing.lg)
            .frame(height: Self.containerHeight)
            .background(background)
            // Compose's `minimumInteractiveComponentSize()`, which every Material chip applies:
            // the chip still *draws* 32 dp tall, but it is hittable across the full touch target.
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
            SalusShapes.pill.fill(colors.secondaryContainer)
        } else {
            // `strokeBorder`, not `stroke`: Material draws the chip's outline inside the
            // 32 dp box, and a centred stroke would spill half a point past it.
            SalusShapes.pill.strokeBorder(colors.outline, lineWidth: Self.borderWidth)
        }
    }

    /// `FilterChipDefaults.Height`, `IconSize` and `borderWidth` — Material component dimensions,
    /// not design tokens.
    private static let containerHeight: CGFloat = 32
    private static let iconSize: CGFloat = 18
    private static let borderWidth: CGFloat = 1
}

#Preview("Filter chips") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    return ZStack {
        theme.colorScheme.background
        HStack(spacing: SalusSpacing.sm) {
            SalusFilterChip(label: "1 hour before", isSelected: true, action: {})
            SalusFilterChip(label: "1 day before", isSelected: false, action: {})
            SalusFilterChip(label: "1 week before", isSelected: false, action: {})
        }
        .padding(SalusSpacing.lg)
    }
    .frame(height: 120)
    .salusTheme(theme)
}
