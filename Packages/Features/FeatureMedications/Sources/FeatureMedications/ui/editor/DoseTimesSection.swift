// Ported from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// ui/editor/MedicationEditorSections.kt:217-270` (`MedicationDoseTimesCard`).
//
// One row per dose of the day: the clock time, the amount and a way to drop the row. The stepper is
// a full-width block of its own, so the time and the remove button share the row above it rather
// than being squeezed alongside a display-sized number — Kotlin's own reasoning, and the layout is
// the same here.
//
// TWO SHAPES THE KOTLIN DOES NOT NEED.
//
// 1. **The time is a `SalusTimeField`, not a `SalusChoiceChip` that opens a dialog.** Kotlin draws a
//    chip and hoists a `timePickerTarget` up to the screen, which renders an `AlertDialog` with a
//    Material `TimePicker` (`MedicationEditorScreen.kt:86`, `:155-170`, `:195-215`). SwiftUI's
//    `DatePicker` *is* the button plus its picker, which is exactly what `SalusTimeField` wraps
//    (`SalusTimeField.swift:1-23`) — so the chip, the dialog, its OK and its Cancel all collapse
//    into the one control, and the screen keeps no picker state at all. Rebuilding the chip and a
//    sheet around a second `DatePicker` would duplicate a shipped component to land on the same
//    two taps.
//
// 2. **The add button appends a row rather than opening a picker first.** With no dialog to open,
//    "Yeni doz saati ekle" adds a dose at `DEFAULT_DOSE_MINUTES` — the very minute Kotlin's picker
//    opens at (`MedicationEditorScreen.kt:157-158`, `:229`) — and the new row's own wheel is what
//    moves it. Same two taps to a non-default time, one fewer surface. The ViewModel sorts after
//    every append and deliberately does not de-duplicate: two rows at the same minute are two
//    doses, which is what a split dose looks like.
//
// The stepper's `rangeHint` carries the strength unit, or nothing — `MedicationEditorSections.swift`
// records why.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// The dose times card (`MedicationEditorSections.kt:222-270`).
struct MedicationDoseTimesCard: View {
    let state: MedicationEditorUiState
    let onEvent: (MedicationEditorEvent) -> Void

    var body: some View {
        SalusCard {
            VStack(alignment: .leading, spacing: SalusSpacing.lg) {
                EditorSectionTitle(text: MedicationsStrings.editorTimesSection)

                // Keyed by position because that is what every event carries: the rows are a list
                // the ViewModel re-sorts, not a set of identities
                // (`MedicationEditorSections.kt:226`).
                ForEach(Array(state.doseTimes.enumerated()), id: \.offset) { index, row in
                    doseRow(index: index, row: row)
                }

                // `MedicationEditorSections.kt:262-269`.
                SalusButton(
                    MedicationsStrings.addDoseTime,
                    variant: .outlined,
                    size: .medium,
                    systemImage: "plus"
                ) { onEvent(.doseTimeAdded(minuteOfDay: MedicationEditorDefaults.defaultDoseMinutes)) }
            }
        }
    }

    /// One dose: when it is taken, how much, and the way to drop it
    /// (`MedicationEditorSections.kt:227-261`).
    private func doseRow(index: Int, row: DoseTimeUi) -> some View {
        VStack(alignment: .leading, spacing: SalusSpacing.sm) {
            HStack(alignment: .center, spacing: SalusSpacing.sm) {
                SalusTimeField(
                    title: MedicationsStrings.editorTimesSection,
                    minuteOfDay: row.minuteOfDay,
                    // Unreachable — a row always has a time — but the field takes one.
                    placeholder: MedicationsStrings.addDoseTime,
                    seedMinuteOfDay: MedicationEditorDefaults.defaultDoseMinutes
                ) { onEvent(.doseTimeChanged(index: index, minuteOfDay: $0)) }
                    .labelsHidden()

                Spacer(minLength: 0)

                // `MedicationEditorSections.kt:252-257`.
                SalusIconButton(
                    systemImage: "xmark",
                    accessibilityLabel: MedicationsStrings.editorRemoveTime,
                    tone: .destructive
                ) { onEvent(.doseTimeRemoved(index: index)) }
            }

            amountStepper(index: index, row: row)
        }
    }

    /// `SalusStepperField(label:value:step:range:format:unit:)`
    /// (`MedicationEditorSections.kt:258-260`).
    ///
    /// The step and the bounds are Kotlin's, applied here because the iOS component owns no
    /// arithmetic. Every `onValueChange` is answered — the ViewModel stores whatever text arrives
    /// (`MedicationEditorViewModel.onEvent`, `.doseAmountChanged`) — which is the caller contract
    /// `SalusStepperField.swift` writes down.
    private func amountStepper(index: Int, row: DoseTimeUi) -> some View {
        SalusStepperField(
            label: MedicationsStrings.editorDoseAmount,
            value: row.amountInput,
            rangeHint: state.strengthUnitInput,
            parse: { Self.amount(of: $0) != nil },
            onValueChange: { onEvent(.doseAmountChanged(index: index, value: $0)) },
            onDecrement: { nudge(index: index, row: row, by: -MedicationEditorDefaults.doseStep) },
            onIncrement: { nudge(index: index, row: row, by: MedicationEditorDefaults.doseStep) }
        )
    }

    /// `step = DOSE_STEP, range = DOSE_STEP..MAX_DOSE_AMOUNT`
    /// (`MedicationEditorSections.kt:259-260`), reported through `formatAmount` exactly as Kotlin's
    /// `onValueChange` does (`:255-257`).
    private func nudge(index: Int, row: DoseTimeUi, by step: Double) {
        let current = Self.amount(of: row.amountInput) ?? MedicationEditorDefaults.defaultDoseAmount
        let next = min(
            MedicationEditorDefaults.maxDoseAmount,
            max(MedicationEditorDefaults.doseStep, current + step)
        )
        onEvent(.doseAmountChanged(index: index, value: formatAmount(next)))
    }

    /// `amountInput.replace(',', '.').toDoubleOrNull()` (`MedicationEditorSections.kt:254`): a
    /// Turkish decimal keypad types a comma, and the stored value is always a dot.
    private static func amount(of input: String) -> Double? {
        Double(input.replacingOccurrences(of: ",", with: "."))
    }
}
