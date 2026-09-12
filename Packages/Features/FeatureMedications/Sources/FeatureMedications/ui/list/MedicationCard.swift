// Ported from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// ui/list/MedicationsScreen.kt:239-347` (`MedicationCard` + `MedicationStock`) in its M15 shape.
// Split into its own file the way M4 split `AppointmentDetailScreen`'s sections: the screen file
// stays the screen's shape.
//
// THREE SHAPES THE KOTLIN DOES NOT NEED.
//
// 1. **The delete affordance is a button, not a long press.** Kotlin wraps the card in
//    `combinedClickable(onClick, onLongClick = onDelete)` (`MedicationsScreen.kt:254-258`), which is
//    Android's idiom and TalkBack's named action. iOS has no long-press convention for destructive
//    row actions — the platform's is a swipe, and a `ScrollView` of cards has no swipe gesture to
//    hang it on — so the trash stays the explicit `SalusIconButton(tone: .destructive)` this card
//    already drew, as its own sibling of the tap target. `VitalsRow` settled the sibling shape and
//    `AppointmentCard` copies it: `SalusCard(onTap:)` is a `Button`, and a second `Button` inside
//    its label is swallowed by the outer one, so "open" is a tap gesture on the content column with
//    the button semantics added back by hand and the trash is a real `Button` beside it.
//
// 2. **"Hemen Al" is a third target inside that card**, so it is a sibling of the tap column too,
//    for the same dispatch reason. Kotlin can nest it because its card is a `Box` with a
//    `combinedClickable` modifier rather than a `Button`.
//
// 3. **Two columns, not one.** The M15 list is a two-column grid (`MedicationsScreen.kt:106`), so
//    the card is narrow: the badge and the day chip share the top row, and everything else stacks
//    under them exactly as Kotlin's `SalusCard` column does.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// One medication (`MedicationsScreen.kt:239-325`).
///
/// Internal rather than private: the file split is a length decision, not an API one.
struct MedicationCard: View {
    let item: MedicationListItem
    let onTap: () -> Void
    let onDelete: () -> Void
    let onTakeDose: (PendingDose) -> Void

    @Environment(\.salusTheme) private var theme
    @Environment(\.locale) private var locale

    var body: some View {
        SalusCard(contentPadding: MedicationCardDefaults.contentPadding) {
            VStack(alignment: .leading, spacing: 0) {
                topRow
                details
                    // The column already fills every point the row above it does, and
                    // `contentShape` makes the empty space beside a short name tappable too.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onTap)
                    // A tap gesture is invisible to VoiceOver, where Compose's `combinedClickable`
                    // is announced as a button. `.combine` reads the card's lines as one element,
                    // the trait announces it as activatable, and the action is what a double tap
                    // runs.
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction(.default, onTap)

                stock

                // `item.dueDose?.let { … }` (`MedicationsScreen.kt:315-323`).
                if let dose = item.dueDose {
                    SalusButton(
                        MedicationsStrings.takeNow,
                        size: .medium,
                        accent: theme.extendedColors.medications
                    ) { onTakeDose(dose) }
                        .padding(.top, SalusSpacing.md)
                }
            }
        }
    }

    /// The form badge and today's chip (`MedicationsScreen.kt:261-275`).
    ///
    /// A sibling of the tap column rather than part of it: the trash button lives here, and two
    /// targets must be disjoint by layout rather than merely ordered by dispatch rules.
    private var topRow: some View {
        HStack(alignment: .center, spacing: SalusSpacing.sm) {
            SalusIconBadge(
                systemImage: item.medication.form.systemImage,
                accent: theme.extendedColors.medications
            )
            Spacer(minLength: 0)
            if let status = item.dayStatus {
                SalusStatusChip(label: status.label, status: status.chipStatus)
            }
            // `onLongClickLabel = medications_delete` (`MedicationsScreen.kt:257`), spelled as a
            // button for the reason in this file's header.
            SalusIconButton(
                systemImage: "trash",
                accessibilityLabel: MedicationsStrings.delete,
                tone: .destructive,
                action: onDelete
            )
        }
        .padding(.bottom, SalusSpacing.md)
    }

    /// Everything a tap on the card opens (`MedicationsScreen.kt:277-311`).
    private var details: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: item.medication.name)
                .font(SalusTypography.titleMedium.font)
                .foregroundStyle(theme.colorScheme.onSurface)
                // `maxLines = 2, overflow = Ellipsis` (`MedicationsScreen.kt:281-282`).
                .lineLimit(2)
            if let strength {
                Text(verbatim: strength)
                    .font(SalusTypography.bodySmall.font)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            }

            // `nextDoseMinuteOfDay?.let { formatTime(it) } ?: recurrenceLabel(schedules)`
            // (`MedicationsScreen.kt:296-302`): the clock time while a dose is outstanding, the
            // plan's own words when none is.
            Text(verbatim: nextDoseOrRecurrence)
                .font(SalusTypography.labelMedium.font)
                .tracking(SalusTypography.labelMedium.tracking)
                .foregroundStyle(theme.extendedColors.medications.accent)
                .padding(.top, SalusSpacing.xs)

            // `MedicationsScreen.kt:304-311`.
            if !item.medication.remindersEnabled {
                SalusStatusChip(
                    label: MedicationsStrings.remindersOff,
                    status: .neutral,
                    systemImage: "bell.slash"
                )
                .padding(.top, SalusSpacing.sm)
            }
        }
    }

    /// `MedicationStock` (`MedicationsScreen.kt:333-347`) — how many are left and, when the user
    /// said what "low" means, the bar that says how low.
    @ViewBuilder
    private var stock: some View {
        if let remaining = item.medication.stockCount {
            VStack(alignment: .leading, spacing: SalusSpacing.xs) {
                Text(verbatim: MedicationsStrings.stockLeft(remaining: formatAmount(remaining)))
                    .font(SalusTypography.bodySmall.font)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                if let threshold = item.medication.stockThreshold {
                    SalusProgressBar(
                        progress: StockBar.fill(remaining: remaining, threshold: threshold),
                        tone: StockBar.tone(remaining: remaining, threshold: threshold)
                    )
                }
            }
            .padding(.top, SalusSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            // The number and the bar are one fact; VoiceOver reads them as one element.
            .accessibilityElement(children: .combine)
        }
    }

    /// `listOfNotNull(strengthValue?.let(::formatAmount), strengthUnit).joinToString(" ")`
    /// (`MedicationsScreen.kt:284-288`), with Kotlin's `isNotBlank()` guard spelled as the optional
    /// this returns — a medication with neither field draws no second line at all.
    private var strength: String? {
        let parts = [item.medication.strengthValue.map(formatAmount), item.medication.strengthUnit]
            .compactMap(\.self)
        let joined = parts.joined(separator: " ")
        return joined.trimmingCharacters(in: .whitespaces).isEmpty ? nil : joined
    }

    /// `MedicationsScreen.kt:298-299`.
    private var nextDoseOrRecurrence: String {
        if let minute = item.nextDoseMinuteOfDay {
            return formatTime(minuteOfDay: minute, locale: locale)
        }
        return recurrenceLabel(schedules: item.schedules, strings: .localized)
    }
}

/// What the card measures itself with. Not design tokens — one component's padding.
enum MedicationCardDefaults {
    /// `contentPadding = PaddingValues(SalusSpacing.md)` (`MedicationsScreen.kt:259`): a narrower
    /// inset than `SalusCard`'s own `lg`, because the M15 card sits in a two-column grid.
    static let contentPadding = EdgeInsets(
        top: SalusSpacing.md,
        leading: SalusSpacing.md,
        bottom: SalusSpacing.md,
        trailing: SalusSpacing.md
    )
}
