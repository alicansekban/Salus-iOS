// Ported from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/editor/WeightEditorScreen.kt`.
//
// Compose → SwiftUI, M15 shapes only — the M2 `Form` and its hand-drawn `VitalsEditorField` are
// both gone:
//   `VitalsEditorChrome(isEdit:onBack:onSave:saveEnabled:)` → the Swift view of the same name,
//                               which draws the inline title, the trailing "Kaydet", the scrolling
//                               body, the tip and the bottom "Ölçümü Kaydet" (see its file header
//                               for the two places the frame is not literally Kotlin's).
//   `SalusStepperField(value:step:range:format:unit:)`
//                             → `SalusUI.SalusStepperField`, whose iOS twin owns no arithmetic:
//                               `value` is the text already written, `onValueChange` reports an
//                               edit and `onDecrement`/`onIncrement` are the two nudges. The step
//                               and the bounds are Kotlin's, applied here through `VitalsLimits` —
//                               the same object the save validates against.
//   `SalusTextField(minLines:)` → `SalusUI.SalusTextField(isSingleLine: false)`.
//   `AlertDialog`             → `.salusConfirmDialog(isPresented:…)`.
//
// **`rangeHint` carries the unit.** The iOS component ports one text slot under the value and no
// unit slot (spec §3.3), where Compose has both; Task 7 settled that the unit goes in that slot,
// and this editor follows it.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// Owns the ViewModel and wires it to the shell (`WeightEditorScreen.kt:30-43`).
///
/// The module comes from the environment, exactly as `koinViewModel(parameters = …)` reaches Koin's
/// graph — see `VitalsModule.swift` for what the composition root injects.
public struct WeightEditorRoute: View {
    private let entryId: String?

    @Environment(\.vitalsModule) private var module
    @State private var viewModel: WeightEditorViewModel?

    public init(entryId: String?) {
        self.entryId = entryId
    }

    public var body: some View {
        Group {
            if let viewModel {
                WeightEditorScreen(state: viewModel.state, onEvent: viewModel.onEvent)
            } else {
                // Only until `.task` has run, or if the shell forgot to inject the module.
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard viewModel == nil, let module else { return }
            viewModel = module.makeWeightEditorViewModel(entryId)
        }
    }
}

/// The stateless editor (`WeightEditorScreen.kt:45-117`).
struct WeightEditorScreen: View {
    let state: WeightEditorUiState
    let onEvent: (WeightEditorEvent) -> Void

    /// The in-app language pick the shell publishes (`RootView+Locale.swift`) — the number in the
    /// field is written in it, exactly as Kotlin's `format = { String.format(locale, …) }` does.
    @Environment(\.locale) private var locale

    var body: some View {
        VitalsEditorChrome(
            isEdit: !state.isNew,
            saveEnabled: state.saveEnabled,
            onSave: { onEvent(.saveClicked) },
            // Explicit `content:` rather than a trailing closure: `onSave` is a closure argument
            // too, and SwiftLint's `multiple_closures_with_trailing_closure` is right that the
            // trailing form hides which one is which.
            content: {
                weightStepper

                if state.showInvalidWeight {
                    SalusInfoNote(
                        text: VitalsStrings.invalidWeight,
                        systemImage: "exclamationmark.triangle",
                        tone: .warning
                    )
                }

                EditorDateField(dateEpochDay: state.dateEpochDay) { onEvent(.dateSelected($0)) }

                noteField

                // `WeightEditorScreen.kt:98-104` — the delete action exists only for an existing entry.
                if !state.isNew {
                    SalusButton(
                        VitalsStrings.delete,
                        variant: .destructive,
                        action: { onEvent(.deleteClicked) }
                    )
                }
            }
        )
        .salusConfirmDialog(
            isPresented: Binding(
                get: { state.showDeleteConfirm },
                set: { isPresented in
                    guard !isPresented else { return }
                    onEvent(.deleteDismissed)
                }
            ),
            title: VitalsStrings.deleteTitle,
            message: VitalsStrings.deleteMessage,
            confirm: SalusDialogAction(label: SalusUIStrings.delete) { onEvent(.deleteConfirmed) },
            dismiss: SalusDialogAction(label: SalusUIStrings.cancel) { onEvent(.deleteDismissed) }
        )
    }

    /// `WeightEditorScreen.kt:58-70`.
    ///
    /// A new entry shows the suggestion dimmed and opens focused: it is a prompt to type over, not
    /// a weight the app is claiming the user has.
    private var weightStepper: some View {
        SalusStepperField(
            label: VitalsStrings.weightLabel,
            value: String(
                format: "%.1f",
                locale: locale,
                stepperValue(of: state.valueText, fallback: state.suggestedKilograms)
            ),
            placeholder: !state.hasValue,
            rangeHint: VitalsUnits.kilograms,
            autoFocus: state.isNew,
            keyboard: .decimal,
            parse: { clampedStepperText($0, in: VitalsLimits.weightKg) != nil },
            onValueChange: { typed in
                // The caller contract `SalusStepperField.swift` writes down: every report is
                // answered, accepted or clamped, never dropped.
                guard let clamped = clampedStepperText(typed, in: VitalsLimits.weightKg) else { return }
                onEvent(.valueChanged(editorDecimalText(clamped)))
            },
            onDecrement: { nudge(by: -Self.step) },
            onIncrement: { nudge(by: Self.step) }
        )
    }

    /// `WeightEditorScreen.kt:84-94` — a two-line note, sentence capitalisation.
    private var noteField: some View {
        SalusTextField(
            text: Binding(get: { state.noteText }, set: { onEvent(.noteChanged($0)) }),
            label: VitalsStrings.noteLabel,
            placeholder: VitalsStrings.notePlaceholder,
            isSingleLine: false,
            capitalization: .sentences
        )
    }

    /// `step = WeightStep` and `range = VitalsLimits.WEIGHT_KG` (`WeightEditorScreen.kt:64-65`,
    /// `:119`), applied here because the iOS component owns no arithmetic.
    private func nudge(by step: Double) {
        let next = nudgedStepperValue(
            from: state.valueText,
            fallback: state.suggestedKilograms,
            by: step,
            in: VitalsLimits.weightKg
        )
        onEvent(.valueChanged(editorDecimalText(next)))
    }

    /// `WeightEditorScreen.kt:119`.
    private static let step = 0.1
}

#Preview("Weight editor — new, showing the suggestion") {
    SalusPreviewPalettes {
        WeightEditorScreen(
            state: WeightEditorUiState(dateEpochDay: 20700),
            onEvent: { _ in }
        )
    }
}

#Preview("Weight editor — existing entry, rejected value") {
    SalusPreviewPalettes {
        WeightEditorScreen(
            state: WeightEditorUiState(
                isNew: false,
                valueText: "5",
                noteText: "After breakfast",
                dateEpochDay: 20700,
                showInvalidWeight: true
            ),
            onEvent: { _ in }
        )
    }
}

#Preview("Weight editor — xxxLarge") {
    WeightEditorScreen(
        state: WeightEditorUiState(isNew: false, valueText: "78.7", dateEpochDay: 20700),
        onEvent: { _ in }
    )
    .dynamicTypeSize(.xxxLarge)
}
