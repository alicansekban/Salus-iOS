// Ported from `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/
// ui/day/CycleDayScreen.kt`.
//
// Material → SwiftUI, per the mapping table in `docs/ios-feature-template.md`:
//   `TopAppBar`                  → `.navigationTitle(_:)` on the shell's stack. Kotlin draws the
//                                  bar itself because Android's shell does not; here the shell owns
//                                  the one `NavigationStack`, and its own back arrow pops exactly
//                                  the path `Navigator.pop()` mutates. The twin's `SalusTopBar.Pushed`
//                                  carries no trailing action (`CycleDayScreen.kt:73-78`), so the
//                                  iOS nav bar shows only the back arrow and the inline date title;
//                                  "Kaydet" is the `SalusButton` at the foot of the form, exactly
//                                  where Kotlin puts it.
//   `FilterChip` in a `FlowRow`  → `ChipFlowLayout` of `SalusChoiceChip`s, which wraps on measured
//                                  width exactly as `FlowRow` does.
//   `SalusTextField(…)`          → `SalusUI.SalusTextField`, the M15 bordered box with the label as
//                                  an overline and a vertical axis for the multi-line note
//                                  (`minLines = 2`, `CycleDayScreen.kt:136-145`).
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
        // LAST in the chain, and `#if os(iOS)` because the modifier is iOS-only API while every
        // feature package also builds for the macOS test host (CLAUDE.md's `.macOS(.v14)`
        // concession).
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
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
        // iOS-only, with no line in `CycleDayScreen.kt` behind it: the note field is multi-line
        // (`SalusTextField` with `isSingleLine: false`, which drives `axis: .vertical`), so its
        // return key inserts a newline rather than closing the keyboard. These two give it the two
        // ways down the platform expects — a tap, and a drag over the form — and both belong on the
        // `ScrollView` itself.
        .salusDismissesKeyboardOnTap()
        .scrollDismissesKeyboard(.interactively)
    }

    /// `CycleDayScreen.kt:103-108` — the symptom group's `SalusSectionHeader`.
    private func sectionTitle(_ text: String) -> some View {
        SalusSectionHeader(
            title: text,
            contentPadding: .init(top: SalusSpacing.xs, leading: 0, bottom: SalusSpacing.xs, trailing: 0)
        )
    }

    /// `CycleDayScreen.kt:113-124`.
    private var symptomChips: some View {
        ChipFlowLayout(spacing: SalusSpacing.sm) {
            ForEach(state.symptoms) { symptom in
                SalusChoiceChip(
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
                SalusChoiceChip(
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
                SalusChoiceChip(
                    label: CycleStrings.moodLabel(mood),
                    isSelected: state.mood == mood
                ) { onEvent(.moodSelected(mood)) }
            }
        }
    }

    /// `CycleDayScreen.kt:136-145`.
    private var noteField: some View {
        SalusTextField(
            text: Binding(get: { state.noteText }, set: { onEvent(.noteChanged($0)) }),
            label: CycleStrings.noteLabel,
            placeholder: CycleStrings.notePlaceholder,
            // `singleLine = false`, `minLines = 2` (`CycleDayScreen.kt:141-142`) with no upper
            // bound: a day's note is free text and the field grows with it.
            isSingleLine: false,
            // `KeyboardCapitalization.Sentences` (`CycleDayScreen.kt:144`).
            capitalization: .sentences
        )
    }

    /// `CycleDayScreen.kt:169-175`.
    ///
    /// `fillsWidth: true` is the `Modifier.fillMaxWidth()` at `CycleDayScreen.kt:174`, and it is
    /// the whole width story: an outer `.frame(maxWidth: .infinity)` would only centre a
    /// content-width capsule, since the drawn pill has to be widened from inside the component.
    private var saveButton: some View {
        SalusButton(
            CycleStrings.save,
            size: .large,
            accent: theme.extendedColors.cycle,
            enabled: !state.isSaving
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
