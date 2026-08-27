// Ported from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// ui/list/MedicationsScreen.kt:170-253` (`MedicationCard`). Split into its own file the way M4
// split `AppointmentDetailScreen`'s sections: the screen file stays the screen's shape.
//
// TWO SHAPES THE KOTLIN DOES NOT NEED.
//
// 1. **The trash is a sibling, not a nested button.** Kotlin's card is `SalusCard(onClick = …)`
//    with an `IconButton` inside it. `SalusCard(onTap:)` is a `Button`, and a second `Button`
//    inside its label is treated as decoration — the outer button swallows the tap. `VitalsRow`
//    settled this and `AppointmentCard` copies it: a plain, non-interactive `SalusCard`, "open" as
//    a tap gesture on the content column with the button semantics added back by hand, and the
//    trash as a real `Button` that is the column's **sibling**, so the two targets are disjoint by
//    layout rather than merely ordered by dispatch rules.
//
// 2. **`LinearProgressIndicator(color:trackColor:)` has no full twin.** `ProgressView(value:)` takes
//    a tint and nothing else, so the accent is carried by `.tint` and the track is the platform's
//    own dimmed rendering of it rather than `accent.container`. Drawing the bar by hand would give
//    the token back and cost the platform's sizing, animation and accessibility; the bar is 72 pt
//    on both platforms, which is the measurement that matters.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// One medication (`MedicationsScreen.kt:170-253`).
///
/// Internal rather than private: the file split is a length decision, not an API one.
struct MedicationCard: View {
    let item: MedicationListItem
    let onTap: () -> Void
    let onDelete: () -> Void

    @Environment(\.salusTheme) private var theme
    @Environment(\.locale) private var locale

    var body: some View {
        SalusCard {
            HStack(alignment: .top, spacing: 0) {
                details
                    // The column already fills every point the trash button does not, and
                    // `contentShape` makes the empty space beside a short name tappable too.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onTap)
                    // A tap gesture is invisible to VoiceOver, where Compose's `SalusCard(onClick =)`
                    // is announced as a button. `.combine` reads the card's lines as one element,
                    // the trait announces it as activatable, and the action is what a double tap
                    // runs.
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction(.default, onTap)

                // `Spacer(width = sm)` + `IconButton` (`MedicationsScreen.kt:217-224`). A sibling of
                // the column, not a descendant of any Button.
                Button(action: onDelete) {
                    Label(MedicationsStrings.delete, systemImage: "trash")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(theme.colorScheme.error)
                }
                .buttonStyle(.plain)
                .padding(.leading, SalusSpacing.sm)
            }
        }
    }

    /// Everything a tap on the card opens (`MedicationsScreen.kt:176-252`, minus the trash).
    private var details: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.sm) {
            HStack(alignment: .center, spacing: 0) {
                SalusIconBadge(
                    systemImage: item.medication.form.systemImage,
                    accent: theme.extendedColors.medications
                )
                .padding(.trailing, SalusSpacing.lg)

                VStack(alignment: .leading, spacing: 0) {
                    Text(item.medication.name)
                        .font(SalusTypography.titleMedium.font)
                        .foregroundStyle(theme.colorScheme.onSurface)
                    if let strength {
                        Text(strength)
                            .font(SalusTypography.bodyMedium.font)
                            .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let percent = item.recordedDosePercent {
                    recordedDoses(percent: percent)
                }
            }

            // `MedicationsScreen.kt:226-231`.
            Text(scheduleSummary(schedules: item.schedules, strings: .localized, locale: locale))
                .font(SalusTypography.bodyMedium.font)
                .foregroundStyle(theme.colorScheme.onSurface)

            // `MedicationsScreen.kt:233-252`. Both chips can be up at once, and they stack rather
            // than flow: two lines is what Kotlin's `Spacer` + chip pair draws.
            if !item.medication.remindersEnabled {
                SalusStatusChip(
                    label: MedicationsStrings.remindersOff,
                    status: .neutral,
                    systemImage: "bell.slash"
                )
            }
            if item.medication.isLowOnStock {
                SalusStatusChip(
                    label: MedicationsStrings.lowStock(remaining: formatAmount(item.medication.stockCount ?? 0.0)),
                    status: .warning
                )
            }
        }
    }

    /// `listOfNotNull(strengthValue?.let(::formatAmount), strengthUnit).joinToString(" ")`
    /// (`MedicationsScreen.kt:189-200`), with Kotlin's `isNotBlank()` guard spelled as the optional
    /// this returns — a medication with neither field draws no second line at all.
    private var strength: String? {
        let parts = [item.medication.strengthValue.map(formatAmount), item.medication.strengthUnit]
            .compactMap(\.self)
        let joined = parts.joined(separator: " ")
        return joined.trimmingCharacters(in: .whitespaces).isEmpty ? nil : joined
    }

    /// The label and its bar (`MedicationsScreen.kt:201-216`).
    private func recordedDoses(percent: Int) -> some View {
        VStack(alignment: .trailing, spacing: SalusSpacing.xs) {
            Text(MedicationsStrings.recordedDoses(percent: percent))
                .font(SalusTypography.labelMedium.font)
                .foregroundStyle(theme.extendedColors.medications.accent)
            ProgressView(value: Double(percent) / percentMax)
                .progressViewStyle(.linear)
                .tint(theme.extendedColors.medications.accent)
                .frame(width: recordedDoseBarWidth)
        }
        // The bar repeats the label beside it; one element, one announcement.
        .accessibilityElement(children: .combine)
    }
}

/// `MedicationsScreen.kt:255`.
private let percentMax = 100.0
/// `MedicationsScreen.kt:256`, renamed with the field it draws.
private let recordedDoseBarWidth: CGFloat = 72
