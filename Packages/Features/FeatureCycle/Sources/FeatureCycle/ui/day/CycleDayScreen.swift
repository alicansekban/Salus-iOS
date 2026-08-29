// Ported from `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/
// ui/day/CycleDayScreen.kt`.
//
// Material → SwiftUI, per the mapping table in `docs/ios-feature-template.md`:
//   `TopAppBar`                  → `.navigationTitle(_:)` on the shell's stack. Kotlin draws the
//                                  bar itself because Android's shell does not; here the shell owns
//                                  the one `NavigationStack`, and its own back arrow pops exactly
//                                  the path `Navigator.pop()` mutates. That is why `cycle_back` has
//                                  no reader — the same divergence `MedicationEditorScreen.swift`
//                                  (h) and `AppointmentEditorScreen.swift` record. Hiding the
//                                  system button to relabel it would also disable the interactive
//                                  swipe-back gesture, which is a worse trade than an unread
//                                  string; the string stays in the catalog because the catalog is
//                                  Android-verbatim.
//   `FilterChip` in a `FlowRow`  → `ChipFlowLayout` of `SalusFilterChip`s, which wraps on measured
//                                  width exactly as `FlowRow` does.
//   `OutlinedTextField`          → `TextField(…, axis: .vertical).textFieldStyle(.roundedBorder)`.
//   `CircularProgressIndicator`  → `ProgressView()`.
//
// The five items of the content are Kotlin's, in Kotlin's order: symptoms, flow, mood, note, save.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// The stateless day log (`CycleDayScreen.kt:61-177`).
struct CycleDayScreen: View {
    let state: CycleDayUiState
    let onEvent: (CycleDayEvent) -> Void

    @Environment(\.salusTheme) private var theme
    @Environment(\.locale) private var locale

    var body: some View {
        // No `Scaffold` twin here: the app shell owns the one navigation stack and its insets.
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.colorScheme.background)
            // `CycleDayScreen.kt:70-74` — the pattern is fixed rather than templated, exactly as
            // Android's is, so both platforms order the components the same way.
            .navigationTitle(LocalDate(epochDay: state.epochDay).formatted(pattern: "d MMMM yyyy", locale: locale))
    }

    /// `CycleDayScreen.kt:86-92`.
    @ViewBuilder
    private var content: some View {
        if state.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            form
        }
    }

    /// `CycleDayScreen.kt:102-176`.
    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SalusSpacing.lg) {
                sectionTitle(CycleStrings.symptomsTitle)
                symptomChips
                sectionTitle(CycleStrings.flowTitle)
                flowChips
                sectionTitle(CycleStrings.moodTitle)
                moodChips
                noteField
                saveButton
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(SalusSpacing.lg)
        }
        // iOS-only, with no line in `CycleDayScreen.kt` behind it: the note field's keyboard is
        // `axis: .vertical`, so its return key inserts a newline rather than closing the keyboard.
        // These two give it the two ways down the platform expects — a tap, and a drag over the
        // form — and both belong on the `ScrollView` itself.
        .salusDismissesKeyboardOnTap()
        .scrollDismissesKeyboard(.interactively)
    }

    /// The `titleMedium` header Kotlin writes above each chip group (`CycleDayScreen.kt:109-112`).
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(SalusTypography.titleMedium.font)
            .foregroundStyle(theme.colorScheme.onSurface)
    }

    /// `CycleDayScreen.kt:113-124`.
    private var symptomChips: some View {
        ChipFlowLayout(spacing: SalusSpacing.sm) {
            ForEach(state.symptoms) { symptom in
                SalusFilterChip(
                    label: CycleStrings.symptomLabel(nameKey: symptom.nameKey),
                    isSelected: symptom.isSelected
                ) { onEvent(.symptomToggled(symptom.id)) }
            }
        }
    }

    /// `CycleDayScreen.kt:130-141`.
    private var flowChips: some View {
        ChipFlowLayout(spacing: SalusSpacing.sm) {
            ForEach(FlowLevel.allCases, id: \.self) { level in
                SalusFilterChip(
                    label: CycleStrings.flowLabel(level),
                    isSelected: state.flow == level
                ) { onEvent(.flowSelected(level)) }
            }
        }
    }

    /// `CycleDayScreen.kt:147-158`.
    private var moodChips: some View {
        ChipFlowLayout(spacing: SalusSpacing.sm) {
            ForEach(Mood.allCases, id: \.self) { mood in
                SalusFilterChip(
                    label: CycleStrings.moodLabel(mood),
                    isSelected: state.mood == mood
                ) { onEvent(.moodSelected(mood)) }
            }
        }
    }

    /// `CycleDayScreen.kt:160-167`.
    private var noteField: some View {
        TextField(
            CycleStrings.noteLabel,
            text: Binding(get: { state.noteText }, set: { onEvent(.noteChanged($0)) }),
            axis: .vertical
        )
        .textFieldStyle(.roundedBorder)
        // `minLines = 2` (`CycleDayScreen.kt:165`), with no upper bound: a day's note is free text
        // and the field grows with it.
        .lineLimit(2...)
        #if os(iOS)
            // `KeyboardCapitalization.Sentences` (`CycleDayScreen.kt:164`).
            .textInputAutocapitalization(.sentences)
        #endif
    }

    /// `CycleDayScreen.kt:169-175`.
    ///
    /// `fillsWidth: true` is the `Modifier.fillMaxWidth()` at `CycleDayScreen.kt:174`, and it is
    /// the whole width story: an outer `.frame(maxWidth: .infinity)` would only centre a
    /// content-width capsule, since the drawn pill has to be widened from inside the component.
    private var saveButton: some View {
        SalusPillButton(
            text: CycleStrings.save,
            enabled: !state.isSaving,
            accent: theme.extendedColors.cycle,
            fillsWidth: true
        ) { onEvent(.saveClicked) }
    }
}

// MARK: - Previews

/// A catalog entry whose `nameKey` has a translation, so the preview shows what the screen shows.
///
/// The labels themselves resolve through `Bundle.module`, which only Xcode's build compiles — a
/// preview run from Xcode does, which is the only place a `#Preview` is ever drawn.
private func previewSymptom(_ id: String, _ nameKey: String, selected: Bool = false) -> CycleSymptomUi {
    CycleSymptomUi(id: id, nameKey: nameKey, isSelected: selected)
}

#Preview("Cycle day — empty") {
    NavigationStack {
        CycleDayScreen(
            state: CycleDayUiState(
                isLoading: false,
                epochDay: 20680,
                symptoms: [
                    previewSymptom("symptom-cramps", "cramps"),
                    previewSymptom("symptom-headache", "headache"),
                    previewSymptom("symptom-fatigue", "fatigue")
                ]
            ),
            onEvent: { _ in }
        )
    }
}

#Preview("Cycle day — logged") {
    NavigationStack {
        CycleDayScreen(
            state: CycleDayUiState(
                isLoading: false,
                epochDay: 20680,
                symptoms: [
                    previewSymptom("symptom-cramps", "cramps", selected: true),
                    previewSymptom("symptom-headache", "headache"),
                    previewSymptom("symptom-fatigue", "fatigue", selected: true)
                ],
                flow: .medium,
                mood: .low,
                noteText: "Sabah yürüyüşü iyi geldi."
            ),
            onEvent: { _ in }
        )
    }
}
