// Ported from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/editor/GlucoseEditorScreen.kt`.
//
// The Material → SwiftUI mapping is `WeightEditorScreen.swift`'s, plus what this screen adds over
// the other two:
//   `FlowRow { SalusChoiceChip … }`   → `ChipFlowLayout` of `SalusChoiceChip`s. Kotlin's `FlowRow`
//                                       wraps and SwiftUI ships no flow stack, so this is the
//                                       layout every other chip row in this tree already uses.
//
// `"mg/dL"` / `"mmol/L"` stay hardcoded, exactly as Kotlin's `GlucoseUnit.unitLabel()` does: they
// are unit symbols, not copy (`VitalsFormatting.kt:15-20`).

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// Owns the ViewModel and wires it to the shell (`GlucoseEditorScreen.kt:37-50`).
///
/// The module comes from the environment, exactly as `koinViewModel(parameters = …)` reaches Koin's
/// graph — see `VitalsModule.swift` for what the composition root injects.
public struct GlucoseEditorRoute: View {
    private let entryId: String?

    @Environment(\.vitalsModule) private var module
    @State private var viewModel: GlucoseEditorViewModel?

    public init(entryId: String?) {
        self.entryId = entryId
    }

    public var body: some View {
        Group {
            if let viewModel {
                GlucoseEditorScreen(state: viewModel.state, onEvent: viewModel.onEvent)
            } else {
                // Only until `.task` has run, or if the shell forgot to inject the module.
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard viewModel == nil, let module else { return }
            viewModel = module.makeGlucoseEditorViewModel(entryId)
        }
    }
}

/// The stateless editor (`GlucoseEditorScreen.kt:52-161`).
struct GlucoseEditorScreen: View {
    let state: GlucoseEditorUiState
    let onEvent: (GlucoseEditorEvent) -> Void

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
                valueStepper
                unitChips
                contextChips

                if state.showInvalidValue {
                    SalusInfoNote(
                        text: VitalsStrings.invalidGlucose,
                        systemImage: "exclamationmark.triangle",
                        tone: .warning
                    )
                }

                EditorDateField(dateEpochDay: state.dateEpochDay) { onEvent(.dateSelected($0)) }

                noteField

                // `GlucoseEditorScreen.kt:142-148`.
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

    /// `GlucoseEditorScreen.kt:65-90`.
    ///
    /// mg/dL is a whole number and mmol/L runs an order of magnitude smaller, so the step, the
    /// range and the printed precision all follow the selected unit. A new reading shows the
    /// suggestion dimmed and opens focused: it is a prompt to type over, not a reading the app is
    /// claiming.
    private var valueStepper: some View {
        let range = VitalsLimits.glucoseRange(state.unit)
        return SalusStepperField(
            label: VitalsStrings.glucoseValueLabel,
            value: formatted(stepperValue(of: state.valueText, fallback: state.suggestedValue)),
            placeholder: !state.hasValue,
            rangeHint: state.unit.vitalsUnitLabel,
            autoFocus: state.isNew,
            keyboard: .decimal,
            parse: { clampedStepperText($0, in: range) != nil },
            onValueChange: { typed in
                // Answered, accepted or clamped, never dropped — the caller contract
                // `SalusStepperField.swift` writes down.
                guard let clamped = clampedStepperText(typed, in: range) else { return }
                onEvent(.valueChanged(canonicalText(clamped)))
            },
            onDecrement: { nudge(by: -step, in: range) },
            onIncrement: { nudge(by: step, in: range) }
        )
    }

    /// `GlucoseEditorScreen.kt:92-100`.
    private var unitChips: some View {
        ChipFlowLayout(spacing: SalusSpacing.sm) {
            ForEach(GlucoseUnit.allCases, id: \.self) { unit in
                SalusChoiceChip(
                    label: unit.vitalsUnitLabel,
                    isSelected: state.unit == unit,
                    action: { onEvent(.unitSelected(unit)) }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `GlucoseEditorScreen.kt:102-114`.
    private var contextChips: some View {
        ChipFlowLayout(spacing: SalusSpacing.sm) {
            ForEach(MeasurementContext.allCases, id: \.self) { context in
                SalusChoiceChip(
                    label: context.vitalsLabel,
                    isSelected: state.measurementContext == context,
                    // Tapping the selected chip clears it: the context is optional
                    // (`GlucoseEditorScreen.kt:108-110`).
                    action: {
                        onEvent(.contextSelected(state.measurementContext == context ? nil : context))
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `GlucoseEditorScreen.kt:128-138`.
    private var noteField: some View {
        SalusTextField(
            text: Binding(get: { state.noteText }, set: { onEvent(.noteChanged($0)) }),
            label: VitalsStrings.noteLabel,
            placeholder: VitalsStrings.notePlaceholder,
            isSingleLine: false,
            capitalization: .sentences
        )
    }

    /// `format = { … }` (`GlucoseEditorScreen.kt:79-84`) — the reader's separator, the unit's
    /// precision.
    private func formatted(_ value: Double) -> String {
        switch state.unit {
        case .mgDl: String(format: "%.0f", locale: locale, value)
        case .mmolL: String(format: "%.1f", locale: locale, value)
        }
    }

    /// What goes back into `valueText`: the canonical dot notation the ViewModel parses
    /// (`GlucoseEditorScreen.kt:71-74`).
    private func canonicalText(_ value: Double) -> String {
        switch state.unit {
        case .mgDl: editorWholeText(value)
        case .mmolL: editorDecimalText(value)
        }
    }

    /// `GlucoseUnit.step()` (`GlucoseEditorScreen.kt:163-166`).
    private var step: Double {
        switch state.unit {
        case .mgDl: 1.0
        case .mmolL: 0.1
        }
    }

    private func nudge(by step: Double, in range: ClosedRange<Double>) {
        let next = nudgedStepperValue(
            from: state.valueText,
            fallback: state.suggestedValue,
            by: step,
            in: range
        )
        onEvent(.valueChanged(canonicalText(next)))
    }
}

#Preview("Glucose editor — new, showing the suggestion") {
    SalusPreviewPalettes {
        GlucoseEditorScreen(
            state: GlucoseEditorUiState(dateEpochDay: 20700),
            onEvent: { _ in }
        )
    }
}

#Preview("Glucose editor — existing entry in mmol/L") {
    SalusPreviewPalettes {
        GlucoseEditorScreen(
            state: GlucoseEditorUiState(
                isNew: false,
                valueText: "5.8",
                suggestedValue: 5.5,
                unit: .mmolL,
                measurementContext: .fasting,
                dateEpochDay: 20700
            ),
            onEvent: { _ in }
        )
    }
}

#Preview("Glucose editor — xxxLarge") {
    GlucoseEditorScreen(
        state: GlucoseEditorUiState(
            isNew: false,
            valueText: "104",
            measurementContext: .postMeal,
            dateEpochDay: 20700
        ),
        onEvent: { _ in }
    )
    .dynamicTypeSize(.xxxLarge)
}
