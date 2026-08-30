// Ported from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/editor/GlucoseEditorScreen.kt`.
//
// Material → SwiftUI by the mapping table `WeightEditorScreen.swift` spells out, plus what this
// screen adds over `BloodPressureEditorScreen`:
//   `SingleChoiceSegmentedButtonRow`   → a `.segmented` `Picker`, the same widget the list screen's
//                                        type selector already is.
//   `Row { FilterChip … }`             → `ChipFlowLayout` of `SalusFilterChip`s. Kotlin's plain
//                                        `Row` does not wrap, and the four Turkish context labels
//                                        ("Açlık", "Tokluk", "Yatmadan önce", "Rastgele") do not
//                                        fit one line on any phone — the layout that wraps is what
//                                        every other chip row in this tree already uses.
//   `label` / `suffix` / `isError`     → `VitalsEditorField`, the one view the three vitals editors
//                                        share; the unit symbol is its suffix, so the field is the
//                                        only place `state.unit` is drawn.
//
// `"mg/dL"` / `"mmol/L"` stay hardcoded here, exactly as Kotlin's `private fun GlucoseUnit.label()`
// does: they are unit symbols, not copy.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// Owns the ViewModel and wires it to the shell (`GlucoseEditorScreen.kt:45-58`).
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

/// The stateless editor (`GlucoseEditorScreen.kt:60-172`).
struct GlucoseEditorScreen: View {
    let state: GlucoseEditorUiState
    let onEvent: (GlucoseEditorEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        // No `Scaffold` twin here: the app shell owns the one navigation stack and its insets.
        Form {
            Section {
                valueField
                unitSelector
                contextChips
                SalusDateField(
                    title: VitalsStrings.selectDate,
                    epochDay: state.dateEpochDay,
                    placeholder: VitalsStrings.selectDate,
                    // Where the wheel opens before a day is set — the same fallback
                    // `WeightEditorScreen` documents; the ViewModel fills `dateEpochDay` at init
                    // on a new entry and from the loaded entry otherwise.
                    seedEpochDay: state.dateEpochDay ?? 0
                ) { onEvent(.dateSelected($0)) }
                noteField
            }

            Section {
                Button {
                    onEvent(.saveClicked)
                } label: {
                    Text(VitalsStrings.save)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                // `GlucoseEditorScreen.kt:157-160`.
                .disabled(state.isSaving || Self.isBlank(state.valueText))
            }
            .listRowBackground(Color.clear)
        }
        // The pair `WeightEditorScreen` records: `.decimalPad` draws no return key, so the keyboard
        // needs the two ways down the platform expects — a tap and a drag over the form.
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
        .navigationTitle(state.isNew ? VitalsStrings.glucoseNewTitle : VitalsStrings.glucoseEditTitle)
        .toolbar {
            // `GlucoseEditorScreen.kt:86-95` — the delete action exists only for an existing entry.
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

    /// `GlucoseEditorScreen.kt:105-121` — one decimal field, the unit as its suffix, and the single
    /// rejection message below it.
    private var valueField: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.xs) {
            VitalsEditorField(
                label: VitalsStrings.glucoseValueLabel,
                // `suffix = { Text(state.unit.label()) }` — the symbol Kotlin writes as a literal.
                suffix: state.unit.label,
                text: Binding(get: { state.valueText }, set: { onEvent(.valueChanged($0)) }),
                isError: state.showInvalidValue,
                keyboard: .decimal
            )

            // `GlucoseEditorScreen.kt:111-115` — the supporting text exists only while flagged.
            if state.showInvalidValue {
                Text(VitalsStrings.invalidGlucose)
                    .font(SalusTypography.bodySmall.font)
                    .foregroundStyle(theme.colorScheme.error)
            }
        }
    }

    /// `GlucoseEditorScreen.kt:123-127` and `:176-192` — the `GlucoseUnitSelector` composable.
    ///
    /// The label is empty for the same reason `VitalsScreen.swift`'s type selector's is: Kotlin's
    /// `SingleChoiceSegmentedButtonRow` carries none, and inventing one would mean inventing
    /// user-facing copy the string catalog does not carry. `glucoseValueLabel` belongs to the value
    /// field above, so titling the unit picker with it made VoiceOver announce the unit selector as
    /// "value".
    private var unitSelector: some View {
        Picker(
            selection: Binding(
                get: { state.unit },
                set: { onEvent(.unitSelected($0)) }
            )
        ) {
            ForEach(GlucoseUnit.allCases, id: \.self) { unit in
                Text(verbatim: unit.label).tag(unit)
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    /// `GlucoseEditorScreen.kt:129-140` — tapping the selected chip deselects it, which is what
    /// `context.takeIf { state.measurementContext != context }` means.
    private var contextChips: some View {
        ChipFlowLayout(spacing: SalusSpacing.sm) {
            ForEach(MeasurementContext.allCases, id: \.self) { context in
                SalusFilterChip(
                    label: context.vitalsLabel,
                    isSelected: state.measurementContext == context
                ) {
                    onEvent(.contextSelected(state.measurementContext == context ? nil : context))
                }
            }
        }
    }

    /// `GlucoseEditorScreen.kt:147-155` — `minLines = 2`, sentence capitalisation.
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

    /// `String.isNotBlank()` — whitespace is not a reading.
    private static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

/// `GlucoseEditorScreen.kt:194-197` — the unit symbols, hardcoded on both platforms.
extension GlucoseUnit {
    fileprivate var label: String {
        switch self {
        case .mgDl: "mg/dL"
        case .mmolL: "mmol/L"
        }
    }
}

#Preview("New entry") {
    NavigationStack {
        GlucoseEditorScreen(
            state: GlucoseEditorUiState(dateEpochDay: 20682),
            onEvent: { _ in }
        )
    }
}

#Preview("Existing entry, rejected value") {
    NavigationStack {
        GlucoseEditorScreen(
            state: GlucoseEditorUiState(
                isNew: false,
                valueText: "5.5",
                unit: .mmolL,
                measurementContext: .postMeal,
                noteText: "After lunch",
                dateEpochDay: 20682,
                showInvalidValue: true
            ),
            onEvent: { _ in }
        )
    }
}
