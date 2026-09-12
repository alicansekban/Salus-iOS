// Ported 1:1 from `PersonalDetailsPage`, `FieldGroup`, `Caption` and the three `Sex` helpers in
// `feature/onboarding/src/main/kotlin/com/alicansekban/salus/feature/onboarding/ui/
// OnboardingPages.kt:125-230`, `:321-350` and `:373-392`.
//
// Android keeps all three pages in one Kotlin file; iOS splits them into one file each, because
// SwiftLint caps a file at 500 lines. This file carries the middle page: everything the profile is
// made of, on one page, of which only the sex is mandatory (`OnboardingPages.kt:124`).
//
// Material → SwiftUI:
//   `SalusTextField(label = …)`       → the same, with `label:` drawing the M15 overline above the
//                                       box. The three `FieldGroup(label)` wrappers Kotlin needs
//                                       around the *non*-field controls (sex, birth date) are the
//                                       one place the overline is still drawn by hand.
//   `Modifier.selectableGroup()`      → `.accessibilityElement(children: .contain)` on the row of
//                                       tiles; each `SalusChoiceTile` already carries the
//                                       `isSelected` trait (`SalusChoiceTile.swift:62-64`).
//   `Modifier.weight(1f)` ×3          → `.frame(maxWidth: .infinity)` on each tile, which is how
//                                       three equal columns are spelled in an `HStack`.
//   `accent = option.accent()`        → DROPPED, and it is the component's gap rather than this
//                                       page's: `SalusChoiceTile` takes no `accent` on this side
//                                       (`SalusChoiceTile.swift:24-34`), so the female/cycle and
//                                       male/vitals tinting has no call site to arrive through.
//                                       Adding the parameter is `SalusUI`'s change, not a feature's.
//   `ContentType.PersonFullName`      → `.textContentType(.name)` behind `#if os(iOS)`, the
//                                       precedent `ProfileScreen.swift:129` sets.
//   `imeAction = Next / Done`         → DROPPED, the recorded `SalusTextField` divergence: Compose's
//                                       IME action relabels the return key *and* drives focus,
//                                       SwiftUI splits those, and half of it is worse than none.
//   `Row(spacedBy(md)) { height,      → an `HStack(spacing: SalusSpacing.md)` of two fields that
//     weight }`                         each take `.frame(maxWidth: .infinity)`.
//   `SalusButton` / `PageTextButton`  → `SalusButton(.primary)` and `SalusButton(.outlined)`. The
//                                       secondary action is an outlined button rather than a bare
//                                       text button (spec §5.2 on this side): a full-width outlined
//                                       control is the iOS shape for "the other way out of this
//                                       page", and it keeps the 56 pt `.large` target the primary
//                                       has.
//
// The three sex glyphs are `ProfileScreen.swift:221-227`'s mapping, reused rather than re-chosen:
// the sex tiles and the profile editor must not disagree about which glyph means which option.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// Page 2 of 3 — the profile (`OnboardingPages.kt:126-230`).
struct OnboardingPersonalPage: View {
    let state: OnboardingUiState
    let onEvent: (OnboardingEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        // `PageColumn` (`OnboardingPages.kt:307-319`).
        VStack(spacing: SalusSpacing.lg) {
            OnboardingHero(
                systemImage: "person",
                title: OnboardingStrings.onboardingPersonalTitle,
                message: OnboardingStrings.onboardingPersonalBody
            )
            nameField
            sexGroup
            birthDateGroup
            measurements
            SalusButton(
                OnboardingStrings.onboardingNext,
                variant: .primary,
                size: .large,
                enabled: state.canContinue
            ) {
                onEvent(.nextClicked)
            }
            SalusButton(
                OnboardingStrings.onboardingSkip,
                variant: .outlined,
                size: .large,
                enabled: state.canSkip
            ) {
                onEvent(.skipClicked)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SalusSpacing.xl)
    }

    /// `OnboardingPages.kt:138-153`.
    private var nameField: some View {
        SalusTextField(
            text: Binding(get: { state.name }, set: { onEvent(.nameChanged($0)) }),
            label: OnboardingStrings.onboardingNameLabel,
            placeholder: OnboardingStrings.onboardingNamePlaceholder,
            capitalization: .words,
            // `autoCorrectEnabled = false` (`:147`) — names are not dictionary words; the
            // suggestion strip only gets in the way.
            autocorrects: false
        )
        #if os(iOS)
        // `ContentType.PersonFullName` (`:152`) — one of only two fields in the app with a real
        // autofill category, so the suggestion bar can offer the device owner's own name here.
        .textContentType(.name)
        #endif
    }

    /// `FieldGroup(sex_label) { Row { tiles }; cycle note }` (`OnboardingPages.kt:155-174`).
    private var sexGroup: some View {
        fieldGroup(label: OnboardingStrings.onboardingSexLabel) {
            HStack(spacing: SalusSpacing.sm) {
                ForEach(Sex.allCases, id: \.self) { option in
                    SalusChoiceTile(
                        label: option.onboardingLabel,
                        systemImage: option.onboardingSystemImage,
                        isSelected: state.sex == option
                    ) {
                        onEvent(.sexSelected(option))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .accessibilityElement(children: .contain)
            if state.showCycleNote {
                SalusInfoNote(
                    text: OnboardingStrings.onboardingCycleNote,
                    systemImage: "info.circle",
                    tone: .info
                )
            }
        }
    }

    /// `FieldGroup(birth_label) { SalusDateField; Caption }` (`OnboardingPages.kt:176-183`).
    ///
    /// `SalusDateField` on iOS takes a `title` (its accessibility name, which Compose gets from the
    /// surrounding label) and a `seedEpochDay` — the day the wheel opens on before one is picked.
    /// The profile editor seeds the same way (`ProfileScreen.swift:143-145`): the epoch, because a
    /// birth date is scrolled to anyway.
    private var birthDateGroup: some View {
        fieldGroup(label: OnboardingStrings.onboardingBirthLabel) {
            SalusDateField(
                title: OnboardingStrings.onboardingBirthLabel,
                epochDay: state.birthDateEpochDay,
                placeholder: OnboardingStrings.onboardingBirthSelect,
                seedEpochDay: state.birthDateEpochDay ?? 0
            ) {
                onEvent(.birthDateSelected($0))
            }
            // `Caption` (`OnboardingPages.kt:337-350`).
            Text(verbatim: OnboardingStrings.onboardingAgeCaption)
                .font(SalusTypography.bodySmall.font)
                .tracking(SalusTypography.bodySmall.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                .lineLimit(nil)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// `Row(spacedBy(md)) { height, weight }` (`OnboardingPages.kt:185-217`). The unit symbol is a
    /// literal on both platforms, never a string resource, and `MeasurementInput`'s comma→dot
    /// normalisation is what makes the Turkish keyboard's decimal separator readable here.
    private var measurements: some View {
        HStack(alignment: .top, spacing: SalusSpacing.md) {
            SalusTextField(
                text: Binding(get: { state.heightText }, set: { onEvent(.heightChanged($0)) }),
                label: OnboardingStrings.onboardingHeightLabel,
                placeholder: OnboardingStrings.onboardingHeightPlaceholder,
                suffix: "cm",
                isError: state.showInvalidHeight,
                supportingText: state.showInvalidHeight ? OnboardingStrings.onboardingHeightInvalid : nil,
                keyboard: .decimal,
                autocorrects: false
            )
            .frame(maxWidth: .infinity)
            SalusTextField(
                text: Binding(get: { state.weightText }, set: { onEvent(.weightChanged($0)) }),
                label: OnboardingStrings.onboardingWeightLabel,
                placeholder: OnboardingStrings.onboardingWeightPlaceholder,
                suffix: "kg",
                isError: state.showInvalidWeight,
                supportingText: state.showInvalidWeight ? OnboardingStrings.onboardingWeightInvalid : nil,
                keyboard: .decimal,
                autocorrects: false
            )
            .frame(maxWidth: .infinity)
        }
    }

    /// An overline over whatever collects the answer — the form's own section heading
    /// (`OnboardingPages.kt:321-335`). A function rather than a shared view: it is two call sites
    /// in this one file, and the third (`onboarding_notes_label`) is `SalusTextField`'s own `label`.
    private func fieldGroup(label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: SalusSpacing.sm) {
            Text(verbatim: label)
                .font(SalusTypography.labelSmall.font)
                .tracking(SalusTypography.labelSmall.tracking)
                .foregroundStyle(theme.extendedColors.overline)
                .lineLimit(nil)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension Sex {
    /// `Sex.labelRes()` (`OnboardingPages.kt:373-377`).
    var onboardingLabel: String {
        switch self {
        case .female: OnboardingStrings.onboardingSexFemale
        case .male: OnboardingStrings.onboardingSexMale
        case .other: OnboardingStrings.onboardingSexOther
        }
    }

    /// `Sex.icon()` (`OnboardingPages.kt:379-383`), mapped exactly as `ProfileScreen.swift:221-227`
    /// maps it — the sex tiles and the profile editor must not disagree about the glyphs.
    var onboardingSystemImage: String {
        switch self {
        case .female: "figure.stand.dress"
        case .male: "figure.stand"
        case .other: "person.2"
        }
    }
}

/// `PersonalDetailsPagePreview` (`OnboardingPages.kt:402-413`) — light and dark, plus the type size
/// the two side-by-side measurement fields are most likely to break at.
private func personalPreviewState(sex: Sex? = .female) -> OnboardingUiState {
    OnboardingUiState(
        steps: OnboardingStep.allCases,
        stepIndex: 1,
        name: "Ada",
        sex: sex,
        heightText: "170",
        weightText: "68"
    )
}

@MainActor
private func personalPreview(isDark: Bool) -> some View {
    let theme = SalusTheme.resolve(systemIsDark: isDark)
    return ScrollView {
        OnboardingPersonalPage(state: personalPreviewState()) { _ in }
            .padding(.horizontal, SalusSpacing.lg)
    }
    .background(theme.colorScheme.background)
    .salusTheme(theme)
}

#Preview("Personal page · light") { personalPreview(isDark: false) }
#Preview("Personal page · dark") { personalPreview(isDark: true) }
#Preview("Personal page · xxxLarge") {
    personalPreview(isDark: false).dynamicTypeSize(.xxxLarge)
}
