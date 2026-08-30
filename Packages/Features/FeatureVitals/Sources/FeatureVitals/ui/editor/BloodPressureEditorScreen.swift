// Ported from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/editor/BloodPressureEditorScreen.kt`.
//
// Material → SwiftUI by the same mapping table `WeightEditorScreen.swift` spells out. Kotlin's
// private `NumberField` composable (`BloodPressureEditorScreen.kt:174-196`) is `VitalsEditorField`
// here — the same view the weight and glucose editors draw — and two of its parts matter most on
// this screen:
//   `isError = true` on an `OutlinedTextField` → a stroked overlay in the `error` role. SwiftUI's
//   `.roundedBorder` field has no error state, and Kotlin's red outline is the *only* per-field
//   signal here (the message itself is a single `Text` below the three fields), so dropping it
//   would leave `SYSTOLIC_NOT_ABOVE_DIASTOLIC` unable to say *which* two fields it means.
//   `label = { Text(…) }` on an `OutlinedTextField` → a persistent caption above the field, *plus*
//   the same string as the `TextField`'s placeholder. Material floats the label to the border and
//   keeps it once the field is filled; SwiftUI's placeholder disappears at the first character,
//   which would leave systolic and diastolic — two adjacent boxes carrying the identical `"mmHg"`
//   suffix — unlabelled in exactly the edit case where both are filled. The caption takes the
//   `error` role with the field, so `SYSTOLIC_NOT_ABOVE_DIASTOLIC` reddens the names too.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// Owns the ViewModel and wires it to the shell (`BloodPressureEditorScreen.kt:38-51`).
///
/// The module comes from the environment, exactly as `koinViewModel(parameters = …)` reaches Koin's
/// graph — see `VitalsModule.swift` for what the composition root injects.
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
                // Only until `.task` has run, or if the shell forgot to inject the module.
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

/// The stateless editor (`BloodPressureEditorScreen.kt:53-170`).
struct BloodPressureEditorScreen: View {
    let state: BloodPressureEditorUiState
    let onEvent: (BloodPressureEditorEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        // No `Scaffold` twin here: the app shell owns the one navigation stack and its insets.
        Form {
            Section {
                readings
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
                // `BloodPressureEditorScreen.kt:154-157`.
                .disabled(state.isSaving || Self.isBlank(state.systolicText) || Self.isBlank(state.diastolicText))
            }
            .listRowBackground(Color.clear)
        }
        // The pair `WeightEditorScreen` records: `.numberPad` draws no return key, so the keyboard
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
        .navigationTitle(
            state.isNew ? VitalsStrings.bloodPressureNewTitle : VitalsStrings.bloodPressureEditTitle
        )
        .toolbar {
            // `BloodPressureEditorScreen.kt:79-88` — the delete action exists only for an
            // existing entry.
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

    /// `BloodPressureEditorScreen.kt:101-141` — the two-column row, the full-width pulse, and the
    /// one error message the three of them share.
    private var readings: some View {
        // Kotlin's outer `Column` is `Arrangement.spacedBy(16.dp)` — `SalusSpacing.lg` — between the
        // row and the pulse field. The shared error line keeps `.xs` instead, the idiom
        // `WeightEditorScreen` uses: the message hugs the fields it describes rather than floating
        // a full 16 below them.
        VStack(alignment: .leading, spacing: SalusSpacing.lg) {
            HStack(spacing: SalusSpacing.lg) {
                VitalsEditorField(
                    label: VitalsStrings.systolicLabel,
                    suffix: "mmHg",
                    text: Binding(
                        get: { state.systolicText },
                        set: { onEvent(.systolicChanged($0)) }
                    ),
                    // `BloodPressureEditorScreen.kt:106-107` — the difference error reddens both.
                    isError: state.error == .invalidSystolic || state.error == .systolicNotAboveDiastolic,
                    keyboard: .number
                )
                VitalsEditorField(
                    label: VitalsStrings.diastolicLabel,
                    suffix: "mmHg",
                    text: Binding(
                        get: { state.diastolicText },
                        set: { onEvent(.diastolicChanged($0)) }
                    ),
                    isError: state.error == .invalidDiastolic || state.error == .systolicNotAboveDiastolic,
                    keyboard: .number
                )
            }

            VStack(alignment: .leading, spacing: SalusSpacing.xs) {
                VitalsEditorField(
                    label: VitalsStrings.pulseLabel,
                    suffix: "bpm",
                    text: Binding(get: { state.pulseText }, set: { onEvent(.pulseChanged($0)) }),
                    isError: state.error == .invalidPulse,
                    keyboard: .number
                )

                // `BloodPressureEditorScreen.kt:133-139` — one message for four rejections.
                if let error = state.error {
                    Text(Self.message(for: error))
                        .font(SalusTypography.bodySmall.font)
                        .foregroundStyle(theme.colorScheme.error)
                }
            }
        }
    }

    /// `BloodPressureEditorScreen.kt:145-151` — `minLines = 2`, sentence capitalisation.
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

    /// `BloodPressureEditorScreen.kt:198-203` — `BloodPressureError.messageRes()`.
    private static func message(for error: BloodPressureError) -> String {
        switch error {
        case .invalidSystolic: VitalsStrings.invalidSystolic
        case .invalidDiastolic: VitalsStrings.invalidDiastolic
        case .invalidPulse: VitalsStrings.invalidPulse
        case .systolicNotAboveDiastolic: VitalsStrings.invalidBpDifference
        }
    }

    /// `String.isNotBlank()` — whitespace is not a reading.
    private static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

#Preview("New entry") {
    NavigationStack {
        BloodPressureEditorScreen(
            state: BloodPressureEditorUiState(dateEpochDay: 20682),
            onEvent: { _ in }
        )
    }
}

#Preview("Existing entry, rejected difference") {
    NavigationStack {
        BloodPressureEditorScreen(
            state: BloodPressureEditorUiState(
                isNew: false,
                systolicText: "80",
                diastolicText: "90",
                pulseText: "62",
                noteText: "After breakfast",
                dateEpochDay: 20682,
                error: .systolicNotAboveDiastolic
            ),
            onEvent: { _ in }
        )
    }
}
