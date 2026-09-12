// Ported from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// ui/detail/MedicationDetailSections.kt:65-177` — the hero, the reminders row and the plan card.
// The supply card and the history card are `MedicationSupplyCard.swift` and
// `MedicationHistoryCard.swift`: Kotlin keeps all five in one 347-line file, and five here would run
// this one past the 500-line limit.
//
// Kotlin can keep them together because a `private @Composable` is invisible outside its file; Swift
// has no per-file privacy for a `View` used from another file, so these are internal types rather
// than private functions. Nothing outside this package can name them — the package exports the
// Route and nothing else.
//
// Material → SwiftUI, the same table `MedicationsScreen.swift` already lists:
//   `Switch(checked:onCheckedChange:)` → `Toggle(_:isOn:)` over a get/set `Binding`, in
//                                        `SalusListItem`'s trailing slot.
//   `FlowRow`                          → `ChipFlowLayout`.
//   `Icons.Outlined.Notifications`     → the `bell` SF Symbol.
//   `Icons.Outlined.Info`              → `info.circle`, `SalusInfoNote`'s own leading glyph.
//
// ONE LAYOUT DIFFERENCE FROM THE KOTLIN, inherited from M4 rather than invented here: Compose pads
// the whole scrolling column horizontally and each card fills it, so a card here carries no inset of
// its own and the screen's `VStack` applies the `lg` — the drawn result is the same inset, reached
// from the other side.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// The hero: what this medication is, at a glance (`MedicationDetailSections.kt:65-94`).
struct MedicationDetailHero: View {
    let medication: Medication

    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusCard(tone: .elevated) {
            HStack(alignment: .center, spacing: SalusSpacing.lg) {
                SalusIconBadge(
                    systemImage: medication.form.systemImage,
                    accent: theme.extendedColors.medications,
                    size: .large
                )
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: medication.name)
                        .font(SalusTypography.headlineMedium.font)
                        .foregroundStyle(theme.colorScheme.onSurface)
                    Text(verbatim: subtitle)
                        .font(SalusTypography.bodyMedium.font)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                }
                // `Modifier.weight(1f)` (`MedicationDetailSections.kt:77`).
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// `listOfNotNull(listOfNotNull(strength, unit).joinToString(" ").takeIf { it.isNotBlank() },
    /// stringResource(form.labelRes())).joinToString(" · ")` (`MedicationDetailSections.kt:79-85`).
    ///
    /// The form label is never absent, so the subtitle is never empty — which is why this returns a
    /// `String` where the list card's twin returns an optional.
    private var subtitle: String {
        let strength = [medication.strengthValue.map(formatAmount), medication.strengthUnit]
            .compactMap(\.self)
            .joined(separator: " ")
        return [strength.isBlank ? nil : strength, medication.form.label]
            .compactMap(\.self)
            .joined(separator: " · ")
    }
}

/// The immediate reminder switch (`MedicationDetailSections.kt:96-117`).
///
/// It mirrors the cycle reminder row: one tap silences this medication's alarms. It stays active
/// and its doses stay on Home, which the "off" subtitle says out loud.
struct MedicationRemindersRow: View {
    let enabled: Bool
    let onToggle: (Bool) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        // `contentPadding = PaddingValues(all = SalusSpacing.xs)`
        // (`MedicationDetailSections.kt:102`, `:344-347`): the list item draws its own row padding,
        // so the card around it adds almost none.
        SalusCard(contentPadding: MedicationRemindersRowDefaults.contentPadding) {
            SalusListItem(
                title: MedicationsStrings.remindersTitle,
                subtitle: description,
                systemImage: "bell",
                accent: theme.extendedColors.medications
            ) {
                // The label is given and then hidden rather than omitted: `Toggle("")` would
                // announce an unnamed switch to VoiceOver, where Compose's `Switch` inherits the
                // row's text from the semantics around it.
                Toggle(MedicationsStrings.remindersTitle, isOn: isOn)
                    .labelsHidden()
            }
        }
    }

    /// `medications_detail_reminder_subtitle` / `medication_reminders_off_desc`
    /// (`MedicationDetailSections.kt:106-112`). M15 replaced the "on" line with the shorter one; the
    /// "off" line is unchanged and still says the doses stay on Home.
    private var description: String {
        enabled ? MedicationsStrings.detailReminderSubtitle : MedicationsStrings.remindersOffDescription
    }

    /// `checked = enabled, onCheckedChange = onToggle` (`MedicationDetailSections.kt:114`). The
    /// switch draws what the repository last emitted, never a local copy: a failed write therefore
    /// snaps it back rather than leaving the UI ahead of the row.
    ///
    /// The setter is a closure literal rather than `onToggle` passed straight through: `Binding`'s
    /// setter is `@isolated(any) @Sendable`, and only a literal written here picks up this view's
    /// main-actor isolation. Handing it the stored non-`Sendable` function value instead is a
    /// strict-concurrency warning.
    private var isOn: Binding<Bool> {
        Binding(get: { enabled }, set: { onToggle($0) })
    }
}

/// "Kullanım Planı": when the doses are, how many of them, and anything written on the box
/// (`MedicationDetailSections.kt:119-177`).
struct MedicationPlanCard: View {
    let medication: Medication
    let schedules: [MedicationSchedule]

    @Environment(\.salusTheme) private var theme
    @Environment(\.locale) private var locale

    var body: some View {
        SalusCard {
            VStack(alignment: .leading, spacing: SalusSpacing.md) {
                Text(verbatim: MedicationsStrings.detailPlan)
                    .font(SalusTypography.titleLarge.font)
                    .foregroundStyle(theme.colorScheme.onSurface)

                // `Row(spacedBy(md)) { tile.weight(1f) × 2 }` (`MedicationDetailSections.kt:134-148`).
                HStack(alignment: .top, spacing: SalusSpacing.md) {
                    SalusMetricTile(
                        overline: MedicationsStrings.detailMetricTime,
                        value: times.first.map { formatTime(minuteOfDay: $0, locale: locale) }
                            ?? MedicationsStrings.metricNone
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    SalusMetricTile(
                        overline: MedicationsStrings.detailMetricAmount,
                        value: schedules.first.map { formatAmount($0.doseAmount) }
                            ?? MedicationsStrings.metricNone,
                        unit: medication.strengthUnit
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                chips

                // `instructions?.takeIf { it.isNotBlank() }` (`MedicationDetailSections.kt:167-175`).
                if let instructions = medication.instructions, !instructions.isBlank {
                    // Kotlin's `SalusInfoNote(title = medication_detail_instructions)` has no iOS
                    // twin — `SalusUI.SalusInfoNote` ports one text slot (spec §3.3) — so the label
                    // leads the sentence the way the note's own copy does elsewhere in this port.
                    SalusInfoNote(
                        text: "\(MedicationsStrings.detailInstructions): \(instructions)",
                        systemImage: "info.circle",
                        tone: .neutral
                    )
                }
            }
        }
    }

    /// The recurrence, how many doses a day and the rest of the clock times
    /// (`MedicationDetailSections.kt:151-165`).
    private var chips: some View {
        ChipFlowLayout(spacing: SalusSpacing.sm) {
            SalusStatusChip(
                label: recurrenceLabel(schedules: schedules, strings: .localized),
                status: .accent
            )
            if !isAsNeeded, !times.isEmpty {
                SalusStatusChip(label: MedicationsStrings.detailPerDay(times: times.count), status: .neutral)
                // `times.drop(1)`: the first is already the "Doz saati" tile above.
                ForEach(times.dropFirst(), id: \.self) { time in
                    SalusStatusChip(label: formatTime(minuteOfDay: time, locale: locale), status: .neutral)
                }
            }
        }
    }

    /// `MedicationDetailSections.kt:126`.
    private var times: [Int] {
        doseTimes(schedules: schedules)
    }

    /// `MedicationDetailSections.kt:127`.
    private var isAsNeeded: Bool {
        schedules.first?.recurrence == .asNeeded
    }
}

/// What the reminders row measures itself with. Not a design token — one card's padding.
enum MedicationRemindersRowDefaults {
    /// `SalusListItemPadding` (`MedicationDetailSections.kt:344-347`).
    static let contentPadding = EdgeInsets(
        top: SalusSpacing.xs,
        leading: SalusSpacing.xs,
        bottom: SalusSpacing.xs,
        trailing: SalusSpacing.xs
    )
}

extension String {
    /// Kotlin's `String.isNotBlank()`, negated — whitespace-only counts as absent.
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
