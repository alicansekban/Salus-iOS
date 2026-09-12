// Ported from `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/
// ui/profile/ProfileScreen.kt`.
//
// Material → SwiftUI, per the mapping table `docs/ios-feature-template.md` records:
//   `TopAppBar` + `navigationIcon`   → `.navigationTitle(_:)`; the shell's one `NavigationStack`
//                                      draws the back button, which is why `profile_back` is a
//                                      dropped key and `onBack` is not a parameter here
//                                      (recorded divergence (d)).
//   `actions = { TextButton }`       → a `.confirmationAction` toolbar item.
//   `Column` + `verticalScroll`      → `ScrollView` + `VStack(spacing:)`.
//   `SalusSectionHeader(             → `SalusSectionHeader(title:)`. Kotlin drops the header's own
//    contentPadding = top(sm))`        horizontal padding because its scroll column already applies
//                                      it; the iOS header applies `SalusSpacing.lg` itself and has
//                                      no `contentPadding` knob, so the column applies none and
//                                      each field carries the same inset instead. The header's own
//                                      `SalusSpacing.sm` vertical padding stands in for Kotlin's
//                                      `top = sm`, so a label sits `md` below the field above it
//                                      rather than `md + sm` — a 8 pt cosmetic difference, listed
//                                      rather than chased.
//   `SalusConfirmDialog`             → `.salusConfirmDialog(isPresented:…)`, the modifier the
//                                      component became on iOS.
//   `SingleChoiceSegmentedButtonRow` → `Picker(…).pickerStyle(.segmented)`, the house mapping
//                                      (`VitalsScreen.swift`). Divergence (b): the segments carry
//                                      text labels only — Kotlin's `SegmentedButton` also draws an
//                                      `icon = { Icon(…, size = 18.dp) }` (`ProfileScreen.kt:167-173`),
//                                      and the iOS segmented control has no per-segment icon slot.
//   `ContentType.PersonFullName`     → `.textContentType(.name)`, AutoFill's twin of Compose's
//                                      autofill content type.
//   `imeAction = ImeAction.Next`     → DROPPED, a recorded divergence. `SalusTextField.swift`'s
//    (`:114`, `:159`)                  header carries the reasoning: Compose's `Next` relabels the
//                                      return key *and* advances focus, SwiftUI splits those, and
//                                      half of it is worse than none. The multi-line field's
//                                      deliberate omission (`:169-172`) is preserved by
//                                      construction — nothing was added to take its newline key.
//
// The field order is onboarding's, exactly as Kotlin has it (`ProfileScreen.kt:97`).

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// Owns the ViewModel and wires it to the shell (`ProfileScreen.kt:53-64`).
public struct ProfileRoute: View {
    @Environment(\.settingsModule) private var module
    @State private var viewModel: ProfileViewModel?

    public init() {}

    public var body: some View {
        Group {
            if let viewModel {
                ProfileScreen(state: viewModel.state, onEvent: viewModel.onEvent)
            } else {
                // Only until `.task` has run, or if the shell forgot to inject the module.
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard viewModel == nil, let module else { return }
            viewModel = module.makeProfileViewModel()
        }
    }
}

/// The stateless editor (`ProfileScreen.kt:66-187`).
struct ProfileScreen: View {
    let state: ProfileUiState
    let onEvent: (ProfileEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        // No `Scaffold` twin: the app shell owns the one navigation stack and its insets.
        VStack(spacing: 0) {
            // `if (state.isLoading) return` (`ProfileScreen.kt:95`) — the band is drawn, the form
            // is not.
            if !state.isLoading {
                identityBand
            }
            ScrollView {
                if !state.isLoading {
                    form
                }
            }
            .salusDismissesKeyboardOnTap()
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colorScheme.background)
        .navigationTitle(SettingsStrings.profileTitle)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { onEvent(.saveClicked) } label: {
                    Text(verbatim: SettingsStrings.profileSave)
                }
                // `ProfileScreen.kt:88`.
                .disabled(state.isLoading || state.isSaving || state.showInvalidHeight)
            }
        }
        .salusConfirmDialog(
            // The setter is deliberately empty, and this is the one dialog in the tree where that
            // matters. `.alert(_:isPresented:actions:)` writes `false` for **either** button — the
            // component says so itself (`SalusConfirmDialog.swift:34`) — so the usual
            // "route the false edge to the dismiss event" shape (`VitalsScreen.swift`, the three
            // vitals editors) would fire `.sexChangeDismissed` *after* `.sexChangeConfirmed`.
            // There that is harmless: a stray dismiss only re-clears a flag. Here dismiss **undoes
            // state** (`sex = storedSex`, `ProfileViewModel.kt:70-71`), so it would revert the pick
            // the user just confirmed and the row would be written with the old sex (review C1).
            // Both buttons already send their own event, and an alert has no other way out, so
            // nothing is lost by ignoring the system's write.
            isPresented: Binding(get: { state.showSexChangeConfirm }, set: { _ in }),
            title: SettingsStrings.profileSexConfirmTitle,
            message: SettingsStrings.profileSexConfirmBody,
            confirm: SalusDialogAction(label: SettingsStrings.profileSexConfirmOk) {
                onEvent(.sexChangeConfirmed)
            },
            dismiss: SalusDialogAction(label: SettingsStrings.profileSexConfirmCancel) {
                onEvent(.sexChangeDismissed)
            }
        )
    }

    /// `ProfileScreen.kt:109-136` — the identity band: fixed below the app bar, outside the scroll
    /// chain so it stays put. The avatar and the name live-update as the user types.
    private var identityBand: some View {
        let resolvedName = state.name.isBlank ? nil : state.name
        return HStack(spacing: SalusSpacing.lg) {
            SalusAvatar(name: resolvedName)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: resolvedName ?? SettingsStrings.profileNamePlaceholder)
                    .font(SalusTypography.titleLarge.font)
                    .foregroundStyle(.white)
                if let sex = state.sex {
                    Text(verbatim: sex.profileLabel)
                        .font(SalusTypography.bodyMedium.font)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.vertical, SalusSpacing.md)
        .background(theme.extendedColors.hero.vertical)
    }

    /// `ProfileScreen.kt:98-174` — the five fields, in onboarding's order.
    private var form: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.md) {
            SalusSectionHeader(title: SettingsStrings.profileName)
            SalusTextField(
                text: Binding(get: { state.name }, set: { onEvent(.nameChanged($0)) }),
                placeholder: SettingsStrings.profileNamePlaceholder,
                capitalization: .words,
                // `autoCorrectEnabled = false` (`ProfileScreen.kt:113`) — a name is not a word the
                // dictionary should second-guess.
                autocorrects: false
            )
            #if os(iOS)
            // `ContentType.PersonFullName` (`ProfileScreen.kt:116`).
            .textContentType(.name)
            #endif
            .padding(.horizontal, SalusSpacing.lg)

            SalusSectionHeader(title: SettingsStrings.profileSex)
            sexOptions

            SalusSectionHeader(title: SettingsStrings.profileBirthDate)
            SalusDateField(
                title: SettingsStrings.profileBirthDate,
                epochDay: state.birthDateEpochDay,
                placeholder: SettingsStrings.profileBirthDateSelect,
                // Where the wheel opens before a day is set. The epoch is the same neutral seed
                // the vitals editors use; a birth date is picked by scrolling anyway.
                seedEpochDay: state.birthDateEpochDay ?? 0
            ) { onEvent(.birthDateSelected($0)) }
                .padding(.horizontal, SalusSpacing.lg)

            SalusSectionHeader(title: SettingsStrings.profileHeight)
            SalusTextField(
                text: Binding(get: { state.heightText }, set: { onEvent(.heightChanged($0)) }),
                placeholder: SettingsStrings.profileHeightPlaceholder,
                // The unit symbol is a literal on both platforms (`ProfileScreen.kt:150`).
                suffix: "cm",
                isError: state.showInvalidHeight,
                supportingText: state.showInvalidHeight ? SettingsStrings.profileHeightInvalid : nil,
                keyboard: .decimal,
                autocorrects: false
            )
            .padding(.horizontal, SalusSpacing.lg)

            SalusSectionHeader(title: SettingsStrings.profileHealthNotes)
            SalusTextField(
                text: Binding(get: { state.healthNotes }, set: { onEvent(.healthNotesChanged($0)) }),
                placeholder: SettingsStrings.profileHealthNotesPlaceholder,
                isSingleLine: false,
                capitalization: .sentences
            )
            .padding(.horizontal, SalusSpacing.lg)
        }
        .padding(.bottom, SalusSpacing.xl)
    }

    /// `ProfileScreen.kt:160-185` — the three options as a segmented control, then the inline
    /// warning that says what the pending pick does to the Cycle row.
    private var sexOptions: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.md) {
            Picker(
                selection: Binding(
                    get: { state.sex },
                    set: { newValue in
                        if let sex = newValue {
                            onEvent(.sexSelected(sex))
                        }
                    }
                )
            ) {
                ForEach(Sex.allCases, id: \.self) { option in
                    Text(verbatim: option.profileLabel).tag(option as Sex?)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            if let change = state.cycleVisibilityChange {
                Text(verbatim: change.inlineMessage)
                    .font(SalusTypography.bodySmall.font)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, SalusSpacing.lg)
    }
}

/// `ProfileScreen.kt:198-202`.
extension CycleVisibilityChange {
    fileprivate var inlineMessage: String {
        switch self {
        case .appears: SettingsStrings.profileSexCycleAppears
        case .disappears: SettingsStrings.profileSexCycleDisappears
        }
    }
}

extension Sex {
    /// `ProfileScreen.kt:204-209`.
    fileprivate var profileLabel: String {
        switch self {
        case .female: SettingsStrings.profileSexFemale
        case .male: SettingsStrings.profileSexMale
        case .other: SettingsStrings.profileSexOther
        }
    }
}

extension String {
    /// Kotlin's `String.isNotBlank()`, negated — whitespace-only counts as absent
    /// (`ProfileScreen.kt:118`).
    fileprivate var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#Preview("Profile editor") {
    NavigationStack {
        ProfileScreen(
            // `ProfileScreenPreview` (`ProfileScreen.kt:225-243`).
            state: ProfileUiState(
                isLoading: false,
                name: "Ayşe",
                sex: .male,
                birthDateEpochDay: 7441,
                heightText: "165",
                healthNotes: "Penicillin allergy",
                storedSex: .female
            ),
            onEvent: { _ in }
        )
    }
}
