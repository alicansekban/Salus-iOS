// Ported 1:1 from `HealthAndPermissionsPage` in
// `feature/onboarding/src/main/kotlin/com/alicansekban/salus/feature/onboarding/ui/
// OnboardingPages.kt:233-304`, with `Caption` (`:337-350`).
//
// Android keeps all three pages in one Kotlin file; iOS splits them into one file each, because
// SwiftLint caps a file at 500 lines. This file carries the last page: the notes nobody else will
// read, and the one permission the app ever asks for (`OnboardingPages.kt:232`).
//
// Material → SwiftUI:
//   `SalusTextField(singleLine =      → `isSingleLine: false`, which puts the field on the vertical
//     false, minLines = 4)`             axis so it grows with the text. `minLines` has no
//                                       `TextField` twin; the field starts at one line and grows,
//                                       which is the iOS shape for a note (and the reason the page
//                                       does not reserve 240 pt of empty box before anything is
//                                       typed).
//   `KeyboardCapitalization.          → `capitalization: .sentences`. Kotlin sets *only* that, with
//     Sentences`, no IME action         no IME action, "or it would steal the newline key the field
//                                       exists for" — on iOS the return key inserts a newline in a
//                                       multi-line field by default, so there is nothing to defend.
//   `SalusCard(contentPadding =       → `SalusCard(contentPadding: EdgeInsets())`. `SalusListItem`
//     PaddingValues())`                 brings its own insets, so the card must not add a second set.
//   `Switch(checked, onCheckedChange) → a `Toggle` in the row's trailing slot, tinted `primary`.
//     + SalusListItem(onClick)`         Kotlin ALSO makes the whole row clickable, because a
//                                       Material `Switch` is a small target beside a wide row; on
//                                       iOS a nested `Button` around a `Toggle` swallows the
//                                       toggle's own gesture, so the row is combined into one
//                                       accessibility element instead — VoiceOver then reads the
//                                       title, the subtitle and the switch state as one control and
//                                       double-tap flips it, which is the behaviour the Kotlin
//                                       `onClick` is there to buy.
//   `PageTextButton(later)`           → `SalusButton(.outlined)`, spec §5.2 on this side: a
//                                       full-width outlined control is the iOS shape for "the other
//                                       way out of this page", and it keeps the 56 pt target.
//   `Caption(later_caption,           → `SalusDisclaimer`, which is exactly a centred `bodySmall`
//     fillMaxWidth, Center)`            on `onSurfaceVariant` (`SalusDisclaimer.swift:19-29`).
//
// Glyphs: `Description` → `doc.text`, `Lock` → `lock`, `NotificationsActive` → `bell.badge`.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// Page 3 of 3 — the notes and the one permission (`OnboardingPages.kt:234-304`).
struct OnboardingHealthPage: View {
    let state: OnboardingUiState
    let onEvent: (OnboardingEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        // `PageColumn` (`OnboardingPages.kt:307-319`).
        VStack(spacing: SalusSpacing.lg) {
            OnboardingHero(
                systemImage: "doc.text",
                title: OnboardingStrings.onboardingHealthTitle,
                message: OnboardingStrings.onboardingHealthBody
            )
            notesGroup
            SalusInfoNote(
                text: OnboardingStrings.onboardingNotesPrivacyBody,
                systemImage: "info.circle",
                tone: .info
            )
            if state.remindersAvailable {
                remindersRow
            }
            SalusButton(
                OnboardingStrings.onboardingFinish,
                variant: .primary,
                size: .large,
                enabled: state.canContinue
            ) {
                onEvent(.nextClicked)
            }
            SalusButton(
                OnboardingStrings.onboardingLater,
                variant: .outlined,
                size: .large,
                enabled: state.canSkip
            ) {
                onEvent(.skipClicked)
            }
            SalusDisclaimer(OnboardingStrings.onboardingLaterCaption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SalusSpacing.xl)
    }

    /// `FieldGroup(notes_label) { SalusTextField; SalusStatusChip }` (`OnboardingPages.kt:246-262`).
    /// The overline is the field's own `label:` here; the chip states where the text ends up, which
    /// is the question a free-text health field raises.
    private var notesGroup: some View {
        VStack(alignment: .trailing, spacing: SalusSpacing.sm) {
            SalusTextField(
                text: Binding(get: { state.healthNotes }, set: { onEvent(.healthNotesChanged($0)) }),
                label: OnboardingStrings.onboardingNotesLabel,
                placeholder: OnboardingStrings.onboardingNotesPlaceholder,
                isSingleLine: false,
                capitalization: .sentences
            )
            SalusStatusChip(
                label: OnboardingStrings.onboardingOnlyDevice,
                status: .neutral,
                systemImage: "lock"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `SalusCard(contentPadding = PaddingValues()) { SalusListItem(… Switch …) }`
    /// (`OnboardingPages.kt:266-286`).
    private var remindersRow: some View {
        SalusCard(contentPadding: EdgeInsets()) {
            SalusListItem(
                title: OnboardingStrings.onboardingRemindersTitle,
                subtitle: OnboardingStrings.onboardingRemindersSubtitle,
                systemImage: "bell.badge"
            ) {
                Toggle(
                    isOn: Binding(
                        get: { state.remindersEnabled },
                        set: { onEvent(.remindersToggled($0)) }
                    )
                ) {
                    EmptyView()
                }
                .labelsHidden()
                .tint(theme.colorScheme.primary)
            }
            // The whole row is the control, the way Kotlin's `onClick` makes it: combined, the
            // title and subtitle become the switch's spoken name and the double-tap flips it.
            .accessibilityElement(children: .combine)
        }
    }
}

/// `HealthAndPermissionsPagePreview` (`OnboardingPages.kt:415-423`) — light and dark, and the
/// hidden switch row the Android preview cannot show because its default state has it on.
private func healthPreviewState(remindersAvailable: Bool = true) -> OnboardingUiState {
    OnboardingUiState(
        steps: OnboardingStep.allCases,
        stepIndex: 2,
        sex: .male,
        remindersAvailable: remindersAvailable
    )
}

@MainActor
private func healthPreview(isDark: Bool, remindersAvailable: Bool = true) -> some View {
    let theme = SalusTheme.resolve(systemIsDark: isDark)
    return ScrollView {
        OnboardingHealthPage(state: healthPreviewState(remindersAvailable: remindersAvailable)) { _ in }
            .padding(.horizontal, SalusSpacing.lg)
    }
    .background(theme.colorScheme.background)
    .salusTheme(theme)
}

#Preview("Health page · light") { healthPreview(isDark: false) }
#Preview("Health page · dark") { healthPreview(isDark: true) }
#Preview("Health page · no reminder row") { healthPreview(isDark: false, remindersAvailable: false) }
