// Ported from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// ui/detail/MedicationDetailScreen.kt:174-372` — the six section composables the screen stacks,
// plus the `LabelledValue` and `IntakeStatus` helpers they share.
//
// Split out of `MedicationDetailScreen.swift` the way `MedicationCard.swift` was split out of
// `MedicationsScreen.swift` and for the same reason: the screen file stays the screen's shape and
// neither file approaches the 500-line limit. Kotlin keeps all of it in one file because a
// `private @Composable` is invisible outside it; Swift has no per-file privacy for a `View` used
// from another file, so these are internal types rather than private functions. Nothing outside
// this package can name them — the package exports the Route and nothing else.
//
// Material → SwiftUI, the same table `MedicationsScreen.swift` and `AppointmentDetailScreen.swift`
// already list:
//   `Switch(checked:onCheckedChange:)` → `Toggle(_:isOn:)` over a get/set `Binding`.
//   `SalusPillButton`                  → `Button` + `.borderedProminent` (primary) / `.bordered`
//                                        (tonal), `.buttonBorderShape(.capsule)` for the pill.
//   `Icons.Outlined.NotificationsOff`  → the `bell.slash` SF Symbol, the same one the list card's
//                                        silenced chip draws.
//   `DateTimeFormatter.ofPattern`      → `LocalDate.formatted(pattern:locale:)`.
//
// TWO LAYOUT DIFFERENCES FROM THE KOTLIN, both inherited from M4 rather than invented here.
//
// 1. Compose pads the whole scrolling column horizontally and hands each `SalusSectionHeader` a
//    `contentPadding` with no horizontal component, while `SalusUI.SalusSectionHeader` pads itself
//    (and deliberately does not port that parameter). So the cards carry the `lg` inset and the
//    headers keep their own — the drawn result is the same inset, reached from the other side.
// 2. A section that is a header *and* a card wraps the two in a `VStack(spacing: md)` rather than
//    emitting them as two siblings of the screen's stack. Kotlin's `Column(spacedBy = md)` puts
//    the same `md` between them; the wrapper is what makes a section one view the screen can stack
//    without relying on how a multi-element body flattens into its parent.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// Badge, name, strength and the silenced chip (`MedicationDetailScreen.kt:174-208`).
struct MedicationDetailHeader: View {
    let medication: Medication

    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusCard {
            HStack(alignment: .center, spacing: 0) {
                SalusIconBadge(
                    systemImage: medication.form.systemImage,
                    accent: theme.extendedColors.medications
                )
                // `Spacer(width = lg)` (`MedicationDetailScreen.kt:182`).
                .padding(.trailing, SalusSpacing.lg)

                VStack(alignment: .leading, spacing: 0) {
                    Text(medication.name)
                        .font(SalusTypography.headlineSmall.font)
                        .foregroundStyle(theme.colorScheme.onSurface)
                    Text(subtitle)
                        .font(SalusTypography.bodyMedium.font)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)

                    // `MedicationDetailScreen.kt:197-204` — the same chip the list card draws for
                    // a silenced medication, so the two screens say it the same way.
                    if !medication.remindersEnabled {
                        Spacer()
                            .frame(height: SalusSpacing.sm)
                        SalusStatusChip(
                            label: MedicationsStrings.remindersOff,
                            status: .neutral,
                            systemImage: "bell.slash"
                        )
                    }
                }
                // `Modifier.weight(1f)` (`MedicationDetailScreen.kt:183`).
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, SalusSpacing.lg)
    }

    /// `listOfNotNull(listOfNotNull(strength, unit).joinToString(" ").takeIf { it.isNotBlank() },
    /// stringResource(form.labelRes())).joinToString(" · ")` (`MedicationDetailScreen.kt:185-191`).
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

/// The immediate reminder switch (`MedicationDetailScreen.kt:210-239`).
///
/// It mirrors the cycle reminder row: one tap silences this medication's alarms. It stays active
/// and its doses stay on Home, which the subtitle says out loud.
struct MedicationRemindersCard: View {
    let enabled: Bool
    let onToggle: (Bool) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusCard {
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(MedicationsStrings.remindersTitle)
                        .font(SalusTypography.titleMedium.font)
                        .foregroundStyle(theme.colorScheme.onSurface)
                    Text(description)
                        .font(SalusTypography.bodySmall.font)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                }
                // `Modifier.weight(1f)` (`MedicationDetailScreen.kt:218`).
                .frame(maxWidth: .infinity, alignment: .leading)

                // The label is given and then hidden rather than omitted: `Toggle("")` would
                // announce an unnamed switch to VoiceOver, where Compose's `Switch` inherits the
                // row's text from the semantics around it.
                Toggle(MedicationsStrings.remindersTitle, isOn: isOn)
                    .labelsHidden()
                    // `Spacer(width = sm)` (`MedicationDetailScreen.kt:235`).
                    .padding(.leading, SalusSpacing.sm)
            }
        }
        .padding(.horizontal, SalusSpacing.lg)
    }

    /// `medication_reminders_on_desc` / `_off_desc` (`MedicationDetailScreen.kt:223-233`).
    private var description: String {
        enabled ? MedicationsStrings.remindersOnDescription : MedicationsStrings.remindersOffDescription
    }

    /// `checked = enabled, onCheckedChange = onToggle` (`MedicationDetailScreen.kt:236`). The
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

/// Schedule summary, dose and instructions (`MedicationDetailScreen.kt:241-269`).
struct MedicationDetailsSection: View {
    let medication: Medication
    let schedules: [MedicationSchedule]

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.md) {
            SalusSectionHeader(title: MedicationsStrings.detailSchedule)
            SalusCard {
                LabelledValue(
                    label: MedicationsStrings.detailWhen,
                    value: scheduleSummary(schedules: schedules, strings: .localized, locale: locale)
                )
                // `schedules.firstOrNull()?.let { … }` (`MedicationDetailScreen.kt:256-264`) — the
                // dose belongs to the first slot, exactly as the recurrence above it does.
                if let schedule = schedules.first {
                    LabelledValue(
                        label: MedicationsStrings.detailDose,
                        value: MedicationsStrings.detailDoseValue(amount: formatAmount(schedule.doseAmount))
                    )
                }
                // `instructions?.takeIf { it.isNotBlank() }` (`MedicationDetailScreen.kt:265-267`).
                if let instructions = medication.instructions, !instructions.isBlank {
                    LabelledValue(label: MedicationsStrings.detailInstructions, value: instructions)
                }
            }
            .padding(.horizontal, SalusSpacing.lg)
        }
    }
}

/// Stock on hand and the low-stock chip (`MedicationDetailScreen.kt:271-293`).
///
/// Drawn only when ``MedicationDetailUiState/showSupply`` says stock tracking is on. There is no
/// stock-adjust affordance here — stock moves when a dose is recorded, on both platforms.
struct MedicationSupplySection: View {
    let medication: Medication

    var body: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.md) {
            SalusSectionHeader(title: MedicationsStrings.detailSupply)
            SalusCard {
                LabelledValue(label: MedicationsStrings.detailStock, value: stock)
                if medication.isLowOnStock {
                    Spacer()
                        .frame(height: SalusSpacing.sm)
                    SalusStatusChip(label: MedicationsStrings.lowStock(remaining: stock), status: .warning)
                }
            }
            .padding(.horizontal, SalusSpacing.lg)
        }
    }

    /// `formatAmount(medication.stockCount ?: 0.0)` (`MedicationDetailScreen.kt:280`, `:287`) —
    /// the same fallback, spelled once because both call sites print the same number.
    private var stock: String {
        formatAmount(medication.stockCount ?? 0.0)
    }
}

/// The last 30 days of recorded doses, newest first (`MedicationDetailScreen.kt:295-331`).
///
/// Read-only: a row is a record, written from Home's dose list or a notification action. There is
/// no dose-logging affordance on this screen on either platform.
struct MedicationHistorySection: View {
    let history: [IntakeHistoryItem]

    @Environment(\.salusTheme) private var theme
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.md) {
            SalusSectionHeader(title: MedicationsStrings.detailHistory)
            SalusCard {
                if history.isEmpty {
                    Text(MedicationsStrings.detailHistoryEmpty)
                        .font(SalusTypography.bodyMedium.font)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    // The item is the identity: a day, a minute, a status and a dose name one
                    // record, and the ViewModel has already dropped every log that is not this
                    // medication's.
                    ForEach(history, id: \.self) { item in
                        row(item)
                    }
                }
            }
            .padding(.horizontal, SalusSpacing.lg)
        }
    }

    /// `MedicationDetailScreen.kt:312-328`.
    private func row(_ item: IntakeHistoryItem) -> some View {
        HStack(alignment: .center, spacing: SalusSpacing.sm) {
            Text(when(item))
                .font(SalusTypography.bodyMedium.font)
                .foregroundStyle(theme.colorScheme.onSurface)
                // `Modifier.weight(1f)` (`MedicationDetailScreen.kt:322`).
                .frame(maxWidth: .infinity, alignment: .leading)
            SalusStatusChip(label: item.status.label, status: item.status.chipStatus)
        }
        .padding(.vertical, SalusSpacing.xs)
        // The date, the time and the verdict are one fact; VoiceOver reads them as one row.
        .accessibilityElement(children: .combine)
    }

    /// `LocalDate.ofEpochDay(epochDay).format(ofPattern("d MMM", locale)) + " · " +
    /// formatTime(minuteOfDay, locale)` (`MedicationDetailScreen.kt:319-320`).
    private func when(_ item: IntakeHistoryItem) -> String {
        let day = LocalDate(epochDay: item.epochDay).formatted(pattern: historyDatePattern, locale: locale)
        return "\(day) · \(formatTime(minuteOfDay: item.minuteOfDay, locale: locale))"
    }
}

/// The two pill buttons (`MedicationDetailScreen.kt:333-347`).
struct MedicationDetailActions: View {
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        // Compose emits both as children of the screen's own `Column(spacedBy = md)`, so they are
        // spaced `md` here too.
        VStack(spacing: SalusSpacing.md) {
            Button(action: onEdit) {
                Text(MedicationsStrings.detailEdit)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            // `tonal = true` (`MedicationDetailScreen.kt:344`).
            Button(action: onDelete) {
                Text(MedicationsStrings.detailDelete)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.large)
        // What makes a `SalusPillButton` a pill — Kotlin's `shape = CircleShape`.
        .buttonBorderShape(.capsule)
        // `Spacer(height = sm)` before the block (`MedicationDetailScreen.kt:335`): the actions sit
        // one step further from the section above them than the sections sit from each other.
        .padding(.top, SalusSpacing.sm)
        .padding(.horizontal, SalusSpacing.lg)
    }
}

/// One label over its value (`MedicationDetailScreen.kt:349-359`).
private struct LabelledValue: View {
    let label: String
    let value: String

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(SalusTypography.labelMedium.font)
                .tracking(SalusTypography.labelMedium.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            Text(value)
                .font(SalusTypography.bodyLarge.font)
                .foregroundStyle(theme.colorScheme.onSurface)
        }
        .padding(.vertical, SalusSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The label names the value beside it; one element, one announcement.
        .accessibilityElement(children: .combine)
    }
}

extension IntakeStatus {
    /// `IntakeStatus.labelRes()` (`MedicationDetailScreen.kt:361-366`) — the `intake_status_*` four.
    ///
    /// The cases are in the repo's alphabetical order (`.swiftformat`'s `sortSwitchCases`) rather
    /// than Kotlin's; the four arms and what they answer are the same.
    fileprivate var label: String {
        switch self {
        case .missed: MedicationsStrings.intakeStatusMissed
        case .pending: MedicationsStrings.intakeStatusPending
        case .skipped: MedicationsStrings.intakeStatusSkipped
        case .taken: MedicationsStrings.intakeStatusTaken
        }
    }

    /// `IntakeStatus.chipStatus()` (`MedicationDetailScreen.kt:368-372`), ported arm for arm.
    ///
    /// **`missed` is `warning`, not `error`**, and `skipped` shares `neutral` with `pending`: a
    /// dose with no record against it is a gap in the record, not a fault, and a skip the user
    /// entered deliberately carries no verdict at all. Reading the four any other way would let
    /// the screen editorialise where Android does not.
    fileprivate var chipStatus: SalusStatus {
        switch self {
        case .missed: .warning
        case .pending, .skipped: .neutral
        case .taken: .success
        }
    }
}

extension String {
    /// Kotlin's `String.isNotBlank()`, negated — whitespace-only counts as absent.
    fileprivate var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// `MedicationDetailScreen.kt:310`.
private let historyDatePattern = "d MMM"
