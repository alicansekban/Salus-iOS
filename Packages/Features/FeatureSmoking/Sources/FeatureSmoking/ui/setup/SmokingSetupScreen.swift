// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/setup/
// SmokingSetupScreen.kt`.
//
// The four-page wizard on the onboarding layout: the position as an overline, one segment per page,
// the page, and the page's one action pinned below it. A pushed screen, so the shell has already
// reserved the insets and the system title bar names it.
//
// Compose → SwiftUI, beyond the shared mapping table:
//   `SalusTopBar.Pushed(title, overline, onBack)` → `.navigationTitle` + inline mode, with the
//                           "ADIM n / 4" overline as the content's first row (spec §2.2: a pushed
//                           screen's subtitle moves into the content). The system back button
//                           stays and leaves the wizard from any page, writing nothing.
//   `BackHandler { BackClicked }` → **no twin**: SwiftUI cannot intercept the system back button
//                           without hiding it, and a pushed screen never hides it. So stepping back
//                           is the step bar instead: a finished segment is a button that reopens
//                           its page (`stepSelected`), with the same "ADIM n / 4" for VoiceOver.
//   `AnimatedContent` slide + fade → a cross-fade; `accessibilityReduceMotion` removes it.

import SalusCommon
import SalusDesignSystem
import SalusModel
import SalusSmoking
import SalusUI
import SwiftUI

/// The stateless wizard: `state` + `onEvent` only, so it previews without a ViewModel. `clock` is
/// what the quit-date sheet checks "future" against.
struct SmokingSetupScreen: View {
    let state: SmokingSetupUiState
    let onEvent: (SmokingSetupEvent) -> Void
    let clock: any SalusClock

    @Environment(\.salusTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: SalusSpacing.md) {
                    Text(verbatim: SmokingStrings.setupStepOf(state.stepNumber, state.stepCount))
                        .font(SalusTypography.labelSmall.font)
                        .tracking(SalusTypography.labelSmall.tracking)
                        .foregroundStyle(theme.extendedColors.overline)
                    SetupStepBar(state: state, onEvent: onEvent)
                    page
                        .id(state.step)
                        .transition(.opacity)
                }
                .padding(.horizontal, SalusSpacing.lg)
                .padding(.vertical, SalusSpacing.md)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: SalusMotion.stateChangeDurationSeconds),
                    value: state.step
                )
            }
            .scrollDismissesKeyboard(.interactively)

            SalusButton(
                state.step == .details ? SmokingStrings.setupStart : SmokingStrings.setupContinue,
                accent: theme.extendedColors.smoking,
                enabled: state.canContinue
            ) { onEvent(.continueClicked) }
                .padding(.horizontal, SalusSpacing.lg)
                .padding(.vertical, SalusSpacing.md)
        }
        .salusDismissesKeyboardOnTap()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colorScheme.background)
        .navigationTitle(Text(verbatim: SmokingStrings.setupTitle))
        // LAST in the chain, and `#if os(iOS)` because the modifier is iOS-only API while every
        // feature package also builds for the macOS test host.
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder private var page: some View {
        switch state.step {
        case .mode: ModeStep(state: state, onEvent: onEvent)
        case .product: ProductStep(state: state, onEvent: onEvent)
        case .amount: AmountStep(state: state, onEvent: onEvent)
        case .details: DetailsStep(state: state, onEvent: onEvent, clock: clock)
        }
    }
}

/// One segment per page, the finished ones filled. A finished segment (never the current one) is a
/// button that reopens its page.
private struct SetupStepBar: View {
    let state: SmokingSetupUiState
    let onEvent: (SmokingSetupEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        HStack(spacing: SalusSpacing.xs) {
            ForEach(SetupStep.allCases, id: \.rawValue) { step in
                segment(for: step)
            }
        }
    }

    @ViewBuilder
    private func segment(for step: SetupStep) -> some View {
        let bar = SalusProgressBar(
            progress: step.rawValue < state.stepNumber ? 1 : 0,
            accent: theme.extendedColors.smoking.accent
        )
        if step.rawValue < state.step.rawValue {
            Button { onEvent(.stepSelected(step)) } label: {
                bar
                    .padding(.vertical, SalusSpacing.sm)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(state.isSaving)
            .accessibilityLabel(SmokingStrings.setupStepOf(step.rawValue + 1, state.stepCount))
        } else {
            // The overline above already says "step n / 4" in words.
            bar
                .padding(.vertical, SalusSpacing.sm)
                .accessibilityHidden(true)
        }
    }
}
