// Ported from `MedicationEditorScreen.kt:381-450` (`DoseTimesSection`), split into its own file
// under the 500-line rule; `MedicationEditorScreen.swift`'s header carries the Material → SwiftUI
// mapping this follows.
//
// **The add row is the one gesture that had to be re-drawn, and this is why.** Kotlin's "+ add
// time" is an `OutlinedButton` that opens a `TimePicker` `AlertDialog` and emits `DoseTimeAdded`
// from its Confirm button. `SalusTimeField` is the button and its wheel in one view, and it reports
// *every* turn of the wheel — which is right for "set this row's time" and wrong for "append a
// row", where it would add one row per intermediate minute the wheel passed through. So the add row
// is the wheel plus an explicit add button: the wheel writes to this view's own `@State`, and the
// button is the Confirm that emits the event. Two taps on both platforms, one row per confirmation.
//
// The `-1 = add new` sentinel of Kotlin's `timePickerTarget` (`MedicationEditorScreen.kt:385`) has
// no twin for the same reason: each row owns its wheel here, so there is no shared target to encode.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// The dose-time builder: one row per dose, plus the way to add another
/// (`MedicationEditorScreen.kt:381-450`).
struct DoseTimesSection: View {
    let state: MedicationEditorUiState
    let onEvent: (MedicationEditorEvent) -> Void

    @Environment(\.salusTheme) private var theme

    /// What the add row's wheel is showing, or nil while it still shows the seed. Presentation
    /// state, not editor state: nothing is added until the add button is tapped.
    @State private var newDoseMinuteOfDay: Int?

    /// `MedicationEditorScreen.kt:435` — where the wheel opens when there is nothing to open at.
    private static let defaultDoseMinutes = 8 * 60

    var body: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.md) {
            // `MedicationEditorScreen.kt:387-390`.
            Text(verbatim: MedicationsStrings.editorTimesSection)
                .font(SalusTypography.labelLarge.font)
                .foregroundStyle(theme.colorScheme.onSurface)

            // `MedicationEditorScreen.kt:392-420`. Keyed by position because that is what every
            // event carries: the rows are a list the ViewModel re-sorts, not a set of identities.
            ForEach(Array(state.doseTimes.enumerated()), id: \.offset) { index, row in
                doseRow(index: index, row: row)
            }

            addRow
        }
    }

    /// One dose: when it is taken, how much, and the way to drop it
    /// (`MedicationEditorScreen.kt:393-419`).
    private func doseRow(index: Int, row: DoseTimeUi) -> some View {
        HStack(spacing: SalusSpacing.md) {
            SalusTimeField(
                title: MedicationsStrings.editorTimesSection,
                minuteOfDay: row.minuteOfDay,
                // Unreachable — a row always has a time — but the field takes one.
                placeholder: MedicationsStrings.editorAddTime,
                seedMinuteOfDay: Self.defaultDoseMinutes
            ) { onEvent(.doseTimeChanged(index: index, minuteOfDay: $0)) }
                .labelsHidden()

            TextField(
                MedicationsStrings.editorDoseAmount,
                text: Binding(
                    get: { row.amountInput },
                    set: { onEvent(.doseAmountChanged(index: index, value: $0)) }
                )
            )
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: .infinity)
            #if os(iOS)
                .keyboardType(.decimalPad)
            #endif

            // `MedicationEditorScreen.kt:412-418`.
            Button {
                onEvent(.doseTimeRemoved(index: index))
            } label: {
                Label(MedicationsStrings.editorRemoveTime, systemImage: "xmark")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
        }
    }

    /// `MedicationEditorScreen.kt:422-426` — the wheel and its Confirm, for the reason in this
    /// file's header.
    private var addRow: some View {
        HStack(spacing: SalusSpacing.md) {
            SalusTimeField(
                title: MedicationsStrings.editorAddTime,
                minuteOfDay: newDoseMinuteOfDay,
                placeholder: MedicationsStrings.editorAddTime,
                seedMinuteOfDay: Self.defaultDoseMinutes
            ) { newDoseMinuteOfDay = $0 }
                .labelsHidden()

            Button {
                onEvent(.doseTimeAdded(minuteOfDay: newDoseMinuteOfDay ?? Self.defaultDoseMinutes))
                // Back to the placeholder, which is also what closes the wheel
                // (`SalusTimeField.clearsPicker(whenValueBecomes:)`): the next add starts at the
                // seed rather than resuming where the last one left off.
                newDoseMinuteOfDay = nil
            } label: {
                Label(MedicationsStrings.editorAddTime, systemImage: "plus")
            }
            .buttonStyle(.bordered)
        }
    }
}
