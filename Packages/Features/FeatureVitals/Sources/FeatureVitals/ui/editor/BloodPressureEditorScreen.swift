// Ported from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/editor/BloodPressureEditorScreen.kt`.
//
// The Material → SwiftUI mapping is `WeightEditorScreen.swift`'s, and so is the `rangeHint` ruling.
// The one thing this editor adds: Compose gives the stepper a `unit` slot *and* a `hint` slot and
// passes both here (`:66-68`, `:79-81`), where the iOS component ports one text slot (spec §3.3).
// The two are joined with the separator the catalog already owns — `vitals_kpi_chip`, "%1$@ · %2$@"
// — rather than by inventing a punctuation rule in Swift. No new copy, and both halves survive.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// Owns the ViewModel and wires it to the shell (`BloodPressureEditorScreen.kt:29-42`).
public struct BloodPressureEditorRoute: View {
    private let entryId: String?

    @Environment(\.vitalsModule) private var module
    @State private var viewModel: BloodPressureEditorViewModel?

    public init(entryId: String?) {
        self.entryId = entryId
    }

    public var body: some View {
        Group {
            if let viewModel {
                BloodPressureEditorScreen(state: viewModel.state, onEvent: viewModel.onEvent)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard viewModel == nil, let module else { return }
            viewModel = module.makeBloodPressureEditorViewModel(entryId)
        }
    }
}

/// The stateless editor (`BloodPressureEditorScreen.kt:44-140`).
struct BloodPressureEditorScreen: View {
    let state: BloodPressureEditorUiState
    let onEvent: (BloodPressureEditorEvent) -> Void

    var body: some View {
        VitalsEditorChrome(
            isEdit: !state.isNew,
            saveEnabled: state.saveEnabled,
            onSave: { onEvent(.saveClicked) },
            // Explicit `content:` rather than a trailing closure: `onSave` is a closure argument
            // too, and SwiftLint's `multiple_closures_with_trailing_closure` is right that the
            // trailing form hides which one is which.
            content: {
                // The hints state the range a reading is usually reported in. They are informational
                // only: this screen classifies nothing and passes no verdict on a value. On a new
                // reading each stepper shows its suggestion dimmed — a prompt to type over, not a
                // reading the app is claiming — and the first field opens focused
                // (`BloodPressureEditorScreen.kt:56-59`).
                systolicStepper
                diastolicStepper
                pulseStepper

                if let error = state.error {
                    SalusInfoNote(
                        text: Self.message(for: error),
                        systemImage: "exclamationmark.triangle",
                        tone: .warning
                    )
                }

                EditorDateField(dateEpochDay: state.dateEpochDay) { onEvent(.dateSelected($0)) }

                noteField

                // `BloodPressureEditorScreen.kt:121-127`.
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

    /// `BloodPressureEditorScreen.kt:60-71`.
    private var systolicStepper: some View {
        wholeNumberStepper(
            label: VitalsStrings.systolicLabel,
            text: state.systolicText,
            suggestion: state.suggestedSystolic,
            range: VitalsLimits.systolicMmHg,
            rangeHint: VitalsStrings.kpiChip(VitalsUnits.mmHg, VitalsStrings.bpHintSys),
            placeholder: !state.hasSystolic,
            autoFocus: state.isNew,
            write: { onEvent(.systolicChanged($0)) }
        )
    }

    /// `BloodPressureEditorScreen.kt:73-83`.
    private var diastolicStepper: some View {
        wholeNumberStepper(
            label: VitalsStrings.diastolicLabel,
            text: state.diastolicText,
            suggestion: state.suggestedDiastolic,
            range: VitalsLimits.diastolicMmHg,
            rangeHint: VitalsStrings.kpiChip(VitalsUnits.mmHg, VitalsStrings.bpHintDia),
            placeholder: !state.hasDiastolic,
            autoFocus: false,
            write: { onEvent(.diastolicChanged($0)) }
        )
    }

    /// `BloodPressureEditorScreen.kt:85-93` — optional, so it may stay a suggestion for the life
    /// of the form.
    private var pulseStepper: some View {
        wholeNumberStepper(
            label: VitalsStrings.pulseLabel,
            text: state.pulseText,
            suggestion: state.suggestedPulse,
            range: VitalsLimits.pulseBpm,
            rangeHint: VitalsUnits.bpm,
            placeholder: state.pulseText.isEmpty,
            autoFocus: false,
            write: { onEvent(.pulseChanged($0)) }
        )
    }

    // The parameters are the stepper's own, one for one.
    // swiftlint:disable function_parameter_count

    /// The three fields are one shape with three bounds — Kotlin repeats the call three times
    /// because a `@Composable` cannot be curried; Swift can say it once.
    private func wholeNumberStepper(
        label: String,
        text: String,
        suggestion: Double,
        range: ClosedRange<Double>,
        rangeHint: String,
        placeholder: Bool,
        autoFocus: Bool,
        write: @escaping (String) -> Void
    ) -> some View {
        SalusStepperField(
            label: label,
            value: editorWholeText(stepperValue(of: text, fallback: suggestion)),
            placeholder: placeholder,
            rangeHint: rangeHint,
            autoFocus: autoFocus,
            keyboard: .standard,
            parse: { clampedStepperText($0, in: range) != nil },
            onValueChange: { typed in
                // Answered, accepted or clamped, never dropped — the caller contract
                // `SalusStepperField.swift` writes down.
                guard let clamped = clampedStepperText(typed, in: range) else { return }
                write(editorWholeText(clamped))
            },
            onDecrement: {
                write(editorWholeText(
                    nudgedStepperValue(from: text, fallback: suggestion, by: -Self.step, in: range)
                ))
            },
            onIncrement: {
                write(editorWholeText(
                    nudgedStepperValue(from: text, fallback: suggestion, by: Self.step, in: range)
                ))
            }
        )
    }

    // swiftlint:enable function_parameter_count

    /// `BloodPressureEditorScreen.kt:107-117`.
    private var noteField: some View {
        SalusTextField(
            text: Binding(get: { state.noteText }, set: { onEvent(.noteChanged($0)) }),
            label: VitalsStrings.noteLabel,
            placeholder: VitalsStrings.notePlaceholder,
            isSingleLine: false,
            capitalization: .sentences
        )
    }

    /// `BloodPressureError.messageRes()` (`BloodPressureEditorScreen.kt:142-147`).
    private static func message(for error: BloodPressureError) -> String {
        switch error {
        case .invalidSystolic: VitalsStrings.invalidSystolic
        case .invalidDiastolic: VitalsStrings.invalidDiastolic
        case .invalidPulse: VitalsStrings.invalidPulse
        case .systolicNotAboveDiastolic: VitalsStrings.invalidBpDifference
        }
    }

    /// Compose's default `step = 1.0` (`SalusStepperField.kt:85`), which all three fields take.
    private static let step = 1.0
}

#Preview("Blood pressure editor — new, showing the suggestions") {
    SalusPreviewPalettes {
        BloodPressureEditorScreen(
            state: BloodPressureEditorUiState(dateEpochDay: 20700),
            onEvent: { _ in }
        )
    }
}

#Preview("Blood pressure editor — existing entry, rejected pair") {
    SalusPreviewPalettes {
        BloodPressureEditorScreen(
            state: BloodPressureEditorUiState(
                isNew: false,
                systolicText: "128",
                diastolicText: "82",
                pulseText: "72",
                dateEpochDay: 20700,
                error: .systolicNotAboveDiastolic
            ),
            onEvent: { _ in }
        )
    }
}

#Preview("Blood pressure editor — xxxLarge") {
    BloodPressureEditorScreen(
        state: BloodPressureEditorUiState(
            systolicText: "128",
            diastolicText: "82",
            dateEpochDay: 20700
        ),
        onEvent: { _ in }
    )
    .dynamicTypeSize(.xxxLarge)
}
