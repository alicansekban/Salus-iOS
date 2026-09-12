// Ported from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// ui/editor/MedicationEditorSections.kt:54-216` — the basics card, the plan card and the dates card,
// plus the two shared labels every card heads its groups with. The form grid, the dose-time card and
// the stock card are `MedicationFormGrid.swift`, `MedicationDoseTimesCard.swift` and
// `MedicationStockCard.swift`: Kotlin keeps all six in one 422-line file, and six here would run
// this one past the 500-line limit.
//
// Material → SwiftUI, per the mapping table in `docs/ios-feature-template.md`:
//   `SalusTextField(value:onValueChange:)` → `SalusUI.SalusTextField(text: Binding)`; Kotlin's
//                                            `KeyboardOptions` split into `keyboard:` and
//                                            `capitalization:`, and `imeAction` has no twin (the
//                                            iOS keyboards these fields raise carry their own
//                                            return key, and a numeric pad draws none at all).
//   `SalusSegmentedTabs(options:selected:)` → the same component, `label:` closure and all.
//   `SalusStepperField(value:step:range:)`  → the iOS twin owns no arithmetic: `value` is the text
//                                            already written, `onValueChange` reports an edit and
//                                            `onDecrement`/`onIncrement` are the two nudges. The
//                                            step and the bounds are Kotlin's, applied here.
//   `FlowRow`                               → `ChipFlowLayout`.
//   `Icons.Filled.Close`                    → the `xmark` SF Symbol.
//
// **THE PLAN CARD IS `MedicationEditorPlanCard`, not `MedicationPlanCard`.** Kotlin can call the
// editor's card and the detail's card the same thing because they live in different packages; one
// Swift module has one namespace, so the editor's takes the qualifier. The detail's keeps the plain
// name, which is the one a reader of `MedicationDetailScreen` expects.
//
// **THE STEPPERS' `rangeHint` CARRIES THE UNIT, or nothing.** Kotlin passes `hint = null` to both
// steppers and hands the dose one a `unit` (`MedicationEditorSections.kt:255-263`);
// `SalusUI.SalusStepperField` ports one text slot under the value and no unit slot (spec §3.3), so
// the strength the user typed goes there and the interval stepper's stays empty. No new copy is
// invented for it.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// Name, form, strength and instructions — what the medication *is*
/// (`MedicationEditorSections.kt:54-127`).
struct MedicationBasicsCard: View {
    let state: MedicationEditorUiState
    let onEvent: (MedicationEditorEvent) -> Void

    var body: some View {
        SalusCard {
            VStack(alignment: .leading, spacing: SalusSpacing.lg) {
                EditorSectionTitle(text: MedicationsStrings.editorSectionBasics)

                SalusTextField(
                    text: Binding(get: { state.name }, set: { onEvent(.nameChanged($0)) }),
                    label: MedicationsStrings.editorName,
                    placeholder: MedicationsStrings.editorNamePlaceholder,
                    isError: state.error == .emptyName,
                    capitalization: .words
                )

                MedicationFormGrid(selected: state.form) { onEvent(.formSelected($0)) }

                // `Row(spacedBy(md)) { field.weight(1f) × 2 }` (`MedicationEditorSections.kt:82-110`).
                HStack(alignment: .top, spacing: SalusSpacing.md) {
                    SalusTextField(
                        text: Binding(
                            get: { state.strengthValueInput },
                            set: { onEvent(.strengthValueChanged($0)) }
                        ),
                        label: MedicationsStrings.editorStrength,
                        placeholder: MedicationsStrings.editorStrengthPlaceholder,
                        // The unit the user is typing next door, echoed inside the value field so
                        // the number is read with its unit rather than as a bare figure
                        // (`MedicationEditorSections.kt:93-95`).
                        suffix: state.strengthUnitInput.isBlank ? nil : state.strengthUnitInput,
                        keyboard: .decimal
                    )
                    SalusTextField(
                        text: Binding(
                            get: { state.strengthUnitInput },
                            set: { onEvent(.strengthUnitChanged($0)) }
                        ),
                        label: MedicationsStrings.editorStrengthUnit,
                        placeholder: MedicationsStrings.editorStrengthUnitPlaceholder
                    )
                }

                SalusTextField(
                    text: Binding(get: { state.instructions }, set: { onEvent(.instructionsChanged($0)) }),
                    label: MedicationsStrings.editorInstructions,
                    placeholder: MedicationsStrings.editorInstructionsPlaceholder,
                    // `singleLine = false, minLines = 2` (`MedicationEditorSections.kt:117-118`).
                    isSingleLine: false,
                    capitalization: .sentences
                )
            }
        }
    }
}

/// The recurrence and whatever that recurrence needs on top of it
/// (`MedicationEditorSections.kt:129-170`).
struct MedicationEditorPlanCard: View {
    let state: MedicationEditorUiState
    let onEvent: (MedicationEditorEvent) -> Void

    var body: some View {
        SalusCard {
            VStack(alignment: .leading, spacing: SalusSpacing.md) {
                EditorSectionTitle(text: MedicationsStrings.editorScheduleSection)

                SalusSegmentedTabs(
                    options: Recurrence.allCases,
                    selected: state.recurrence,
                    label: Self.tabLabel
                ) { onEvent(.recurrenceSelected($0)) }

                switch state.recurrence {
                case .daysOfWeek:
                    DaysOfWeekChips(mask: state.daysOfWeekMask) { onEvent(.dayOfWeekToggled(mondayBasedIndex: $0)) }

                case .intervalDays:
                    intervalStepper

                case .asNeeded, .daily:
                    EmptyView()
                }
            }
        }
    }

    /// `SalusStepperField(label:value:step:range:)` (`MedicationEditorSections.kt:156-165`).
    ///
    /// The step and the bounds are Kotlin's, applied here because the iOS component owns no
    /// arithmetic. Every `onValueChange` is answered — the ViewModel stores whatever text arrives
    /// (`MedicationEditorViewModel.onEvent`, `.intervalDaysChanged`) — which is the caller contract
    /// `SalusStepperField.swift` writes down.
    private var intervalStepper: some View {
        SalusStepperField(
            label: MedicationsStrings.editorIntervalDays,
            value: state.intervalDaysInput,
            rangeHint: "",
            keyboard: .standard,
            parse: { Int($0) != nil },
            onValueChange: { onEvent(.intervalDaysChanged($0)) },
            onDecrement: { nudgeInterval(by: -MedicationEditorDefaults.intervalStep) },
            onIncrement: { nudgeInterval(by: MedicationEditorDefaults.intervalStep) }
        )
    }

    /// `step = 1.0, range = MIN_INTERVAL_DAYS..MAX_INTERVAL_DAYS`
    /// (`MedicationEditorSections.kt:163-164`, `:418-419`).
    private func nudgeInterval(by step: Int) {
        let current = Int(state.intervalDaysInput) ?? MedicationEditorDefaults.defaultIntervalDays
        let next = min(
            MedicationEditorDefaults.maxIntervalDays,
            max(MedicationEditorDefaults.minIntervalDays, current + step)
        )
        onEvent(.intervalDaysChanged(String(next)))
    }

    /// `Recurrence.tabLabelRes()` (`MedicationEditorSections.kt:398-403`) — short enough to sit in a
    /// four-way segmented control; the long names stay on the cards.
    private static func tabLabel(_ recurrence: Recurrence) -> String {
        switch recurrence {
        case .asNeeded: MedicationsStrings.recurrenceAsNeeded
        case .daily: MedicationsStrings.recurrenceDaily
        case .daysOfWeek: MedicationsStrings.recurrenceTabDays
        case .intervalDays: MedicationsStrings.recurrenceTabInterval
        }
    }
}

/// When the course starts, and when it ends if it ever does
/// (`MedicationEditorSections.kt:172-215`).
struct MedicationDatesCard: View {
    let state: MedicationEditorUiState
    let onEvent: (MedicationEditorEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusCard {
            VStack(alignment: .leading, spacing: SalusSpacing.md) {
                EditorSectionTitle(text: MedicationsStrings.editorSectionDates)

                VStack(alignment: .leading, spacing: SalusSpacing.sm) {
                    EditorFieldLabel(text: MedicationsStrings.editorStartDateLabel)
                    SalusDateField(
                        title: MedicationsStrings.editorStartDateLabel,
                        epochDay: state.startDateEpochDay,
                        placeholder: MedicationsStrings.editorStartDatePlaceholder,
                        seedEpochDay: state.startDateEpochDay
                    ) { onEvent(.startDateSelected(epochDay: $0)) }
                        .labelsHidden()
                }

                VStack(alignment: .leading, spacing: SalusSpacing.sm) {
                    EditorFieldLabel(text: MedicationsStrings.editorEndDateLabel)
                    HStack(alignment: .center, spacing: SalusSpacing.sm) {
                        SalusDateField(
                            title: MedicationsStrings.editorEndDateLabel,
                            epochDay: state.endDateEpochDay,
                            placeholder: MedicationsStrings.editorNoEndDate,
                            // `initialEpochDay = endDateEpochDay ?: startDateEpochDay`
                            // (`MedicationEditorSections.kt:189`).
                            seedEpochDay: state.endDateEpochDay ?? state.startDateEpochDay
                        ) { onEvent(.endDateSelected(epochDay: $0)) }
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // `MedicationEditorSections.kt:196-203`.
                        if state.endDateEpochDay != nil {
                            SalusIconButton(
                                systemImage: "xmark",
                                accessibilityLabel: MedicationsStrings.editorClearEndDate
                            ) { onEvent(.endDateSelected(epochDay: nil)) }
                        }
                    }
                }

                // `MedicationEditorSections.kt:205-213` — this one error is drawn under the field it
                // is about rather than only in the banner at the top.
                if state.error == .endBeforeStart {
                    Text(verbatim: MedicationsStrings.editorErrorEndBeforeStart)
                        .font(SalusTypography.bodySmall.font)
                        .foregroundStyle(theme.colorScheme.error)
                }
            }
        }
    }
}

/// `DaysOfWeekChips` (`MedicationEditorSections.kt:381-396`) — Monday first, and bit 0 is Monday.
struct DaysOfWeekChips: View {
    let mask: Int
    let onToggle: (Int) -> Void

    var body: some View {
        ChipFlowLayout(spacing: SalusSpacing.sm) {
            ForEach(Array(Self.dayLabels.enumerated()), id: \.offset) { index, label in
                SalusChoiceChip(label: label, isSelected: mask & (1 << index) != 0) {
                    onToggle(index)
                }
            }
        }
    }

    /// `MedicationEditorSections.kt:382-385` — Monday .. Sunday, the order the mask's bits are in.
    ///
    /// Computed rather than stored, for `ScheduleSummaryStrings.localized`'s reason: a stored static
    /// resolves once per process and would keep the locale that was current when the first editor
    /// opened.
    private static var dayLabels: [String] { [
        MedicationsStrings.dayMon,
        MedicationsStrings.dayTue,
        MedicationsStrings.dayWed,
        MedicationsStrings.dayThu,
        MedicationsStrings.dayFri,
        MedicationsStrings.daySat,
        MedicationsStrings.daySun
    ] }
}

/// `SectionTitle` (`MedicationEditorSections.kt:363-366`) — the `titleLarge` line every card opens
/// with.
struct EditorSectionTitle: View {
    let text: String

    @Environment(\.salusTheme) private var theme

    var body: some View {
        Text(verbatim: text)
            .font(SalusTypography.titleLarge.font)
            .foregroundStyle(theme.colorScheme.onSurface)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// `FieldLabel` (`MedicationEditorSections.kt:368-376`) — the overline above a group that is not a
/// `SalusTextField` (which draws its own label).
struct EditorFieldLabel: View {
    let text: String

    @Environment(\.salusTheme) private var theme

    var body: some View {
        Text(verbatim: text)
            .font(SalusTypography.labelSmall.font)
            .tracking(SalusTypography.labelSmall.tracking)
            .foregroundStyle(theme.extendedColors.overline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Kotlin's seven `private const val`s at the bottom of `MedicationEditorSections.kt:412-418`, plus
/// the two the screen file owns (`MedicationEditorScreen.kt:228-230`). Step sizes and bounds, not
/// design tokens.
enum MedicationEditorDefaults {
    /// `DOSE_STEP` (`MedicationEditorSections.kt:412`).
    static let doseStep = 0.5
    /// `DEFAULT_DOSE_AMOUNT` (`:413`).
    static let defaultDoseAmount = 1.0
    /// `MAX_DOSE_AMOUNT` (`:414`); the minimum is the step itself, as Kotlin's `range` spells it.
    static let maxDoseAmount = 99.0
    /// `DEFAULT_INTERVAL_DAYS` (`:415`).
    static let defaultIntervalDays = 2
    /// `MIN_INTERVAL_DAYS` (`:416`).
    static let minIntervalDays = 1
    /// `MAX_INTERVAL_DAYS` (`:417`).
    static let maxIntervalDays = 365
    /// One day per nudge (`:163`).
    static let intervalStep = 1
    /// `FORM_GRID_COLUMNS` (`:418`).
    static let formGridColumns = 4
    /// `DEFAULT_DOSE_MINUTES` (`MedicationEditorScreen.kt:229`).
    static let defaultDoseMinutes = 8 * 60
}
