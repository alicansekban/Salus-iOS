// Ported from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/editor/WeightEditorScreen.kt`.
//
// Material → SwiftUI, per the mapping table iOS-M2 Task 3 recorded:
//   `TopAppBar`               → `.navigationTitle(_:)` + `.toolbar { }` on the shell's stack.
//   `navigationIcon` (back)   → the stack's own back button. Compose has no chrome and must draw
//                               one; SwiftUI's `NavigationStack` already provides it, and it pops
//                               the very `NavigationPath` the Navigator's `pop()` mutates, so the
//                               two ways back stay one behaviour. `onBack` therefore has no
//                               parameter here, and `vitals_back` stays in the catalog for the
//                               editors M7 brings under the same shell.
//   `OutlinedTextField` with `label` / `suffix` / `isError` (`WeightEditorScreen.kt:96-113`)
//                             → `VitalsEditorField`, the one view the three vitals editors share:
//                               a persistent caption above the field (Material floats `label` to
//                               the border and keeps it once the field is filled, where SwiftUI's
//                               placeholder disappears at the first character), a trailing `Text`
//                               for the suffix SwiftUI has no slot for, and a stroked overlay in
//                               the `error` role for `isError`.
//   `supportingText`          → the error line under the field, in the `error` role. It stays on
//                               this screen rather than in `VitalsEditorField`, because the
//                               blood-pressure editor draws one message for three fields.
//   `Button`                  → `Button(…).buttonStyle(.borderedProminent)`.
//   `AlertDialog`             → `.salusConfirmDialog(isPresented:…)`.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// Owns the ViewModel and wires it to the shell (`WeightEditorScreen.kt:37-50`).
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

/// The stateless editor (`WeightEditorScreen.kt:52-149`).
struct WeightEditorScreen: View {
    let state: WeightEditorUiState
    let onEvent: (WeightEditorEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        // No `Scaffold` twin here: the app shell owns the one navigation stack and its insets.
        Form {
            Section {
                weightField
                SalusDateField(
                    title: VitalsStrings.selectDate,
                    epochDay: state.dateEpochDay,
                    placeholder: VitalsStrings.selectDate,
                    // Where the wheel opens before a day is set, Kotlin's
                    // `initialSelectedDateMillis` slot (`EditorDateField.kt:48`). The ViewModel
                    // fills `dateEpochDay` at init on a new entry and from the loaded entry
                    // otherwise (`WeightEditorViewModel.kt:35-54`), so the fallback only stands in
                    // for the window before a loaded entry arrives — and seeding the wheel records
                    // nothing until it is turned.
                    seedEpochDay: state.dateEpochDay ?? 0
                ) { onEvent(.dateSelected($0)) }
                noteField
            }

            Section {
                Button {
                    onEvent(.saveClicked)
                } label: {
                    Text(verbatim: VitalsStrings.save)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                // `WeightEditorScreen.kt:131` — `!state.isSaving && state.valueText.isNotBlank()`.
                .disabled(state.isSaving || state.valueText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .listRowBackground(Color.clear)
        }
        // Divergence: iOS-only, with no line in `WeightEditorScreen.kt` behind it. The weight field
        // is `.decimalPad`, which draws no return key, so the keyboard has no "Done" to press —
        // where Compose's number IME still carries the `ImeAction` the Kotlin field declares. The
        // two lines below give the keyboard the two ways down the platform expects: a tap, and a
        // drag over the form. Both belong on the scrolling container itself; the file comment on
        // `salusDismissesKeyboardOnTap()` records the layouts that were measured and do nothing.
        // `MedicationEditorScreen` applies the same pair in the same place.
        //
        // **This container is a `Form`, and the modifier was measured on a `ScrollView`.** A
        // `Form` is a `List` underneath and routes its touches differently, so the simultaneous
        // tap gesture is not proven here by the measurement that keeps the modifier honest
        // elsewhere — it is covered on a simulator by `scripts/m6-manual-qa.md` §3.9, which
        // exercises this screen and a `ScrollView` editor side by side.
        .salusDismissesKeyboardOnTap()
        .scrollDismissesKeyboard(.interactively)
        // The token background the two shipped editors paint (`AppointmentEditorScreen`,
        // `MedicationEditorScreen`), in the same place on the outer container. Those two wrap a
        // `ScrollView`, which is transparent; a `Form` is a `List` and paints
        // `systemGroupedBackground` of its own over anything behind it, so hiding that is what
        // makes the token visible here — the `.background` alone would never be seen.
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colorScheme.background)
        .navigationTitle(state.isNew ? VitalsStrings.newTitle : VitalsStrings.editTitle)
        .toolbar {
            // `WeightEditorScreen.kt:77-86` — the delete action exists only for an existing entry.
            if !state.isNew {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onEvent(.deleteClicked)
                    } label: {
                        Label(VitalsStrings.delete, systemImage: "trash")
                    }
                }
            }
        }
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

    /// `WeightEditorScreen.kt:96-113`.
    private var weightField: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.xs) {
            VitalsEditorField(
                label: VitalsStrings.weightLabel,
                // The literal Kotlin draws (`WeightEditorScreen.kt:100`), not `weightUnit` from the
                // mapper: that constant is the *persisted* unit string, and a label that borrowed
                // it would make a storage change a silent UI change.
                suffix: "kg",
                text: Binding(get: { state.valueText }, set: { onEvent(.valueChanged($0)) }),
                // `WeightEditorScreen.kt:101` — the same `isError` the other two editors pass.
                isError: state.showInvalidWeight,
                keyboard: .decimal
            )

            if state.showInvalidWeight {
                Text(verbatim: VitalsStrings.invalidWeight)
                    .font(SalusTypography.bodySmall.font)
                    .foregroundStyle(theme.colorScheme.error)
            }
        }
    }

    /// `WeightEditorScreen.kt:120-127` — `minLines = 2`, sentence capitalisation.
    private var noteField: some View {
        TextField(
            VitalsStrings.noteLabel,
            text: Binding(get: { state.noteText }, set: { onEvent(.noteChanged($0)) }),
            axis: .vertical
        )
        .lineLimit(2 ... 6)
        #if os(iOS)
            .textInputAutocapitalization(.sentences)
        #endif
    }
}

#Preview("New entry") {
    NavigationStack {
        WeightEditorScreen(
            state: WeightEditorUiState(dateEpochDay: 20682),
            onEvent: { _ in }
        )
    }
}

#Preview("Existing entry, rejected value") {
    NavigationStack {
        WeightEditorScreen(
            state: WeightEditorUiState(
                isNew: false,
                valueText: "5",
                noteText: "After breakfast",
                dateEpochDay: 20682,
                showInvalidWeight: true
            ),
            onEvent: { _ in }
        )
    }
}
