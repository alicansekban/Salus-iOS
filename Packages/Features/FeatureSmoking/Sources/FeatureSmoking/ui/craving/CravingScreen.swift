// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/craving/
// CravingScreen.kt`.
//
// The craving flow: the headline, the breathing ring with the time left, the three breath chips and
// one rotating line from the person's own figures. Once the five minutes are up, or the craving is
// logged, the ring turns into a check. Presented as a full-screen cover (see
// ``SmokingCravingPresenter``): the shell wraps it in a navigation stack, so the title is the
// system's and the close button is the one toolbar action, the way out that writes nothing.
//
// Compose → SwiftUI, beyond the shared mapping table:
//   `SalusTopBar.Pushed(title, onBack)`     → `.navigationTitle` + inline mode and one
//                           `ToolbarItem(placement: .primaryAction)` close button (no back button
//                           exists on a cover).
//   `displayMedium` countdown                → `displaySmall`, the largest role Salus draws.
//   `Crossfade(tween(Slow))`                 → an `.id`-keyed opacity transition on
//                           `SalusMotion.entranceAnimation`, the same 450 ms.
//   `clearAndSetSemantics`                   → `.accessibilityElement(children: .ignore)`.
//
// `reduceMotion` is the system setting, read at the Route's edge: the ring and the line stop moving
// and the rhythm is in the words alone — the phase label inside the ring and the lit chip below it.

import SalusDesignSystem
import SalusSmoking
import SalusUI
import SwiftUI

/// The stateless screen: `state` + `onEvent` only, so it previews without a ViewModel.
struct CravingScreen: View {
    let state: CravingUiState
    let reduceMotion: Bool
    let onEvent: (CravingEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: SalusSpacing.lg) {
                    if state.completed {
                        CravingCompletedBody(state: state, reduceMotion: reduceMotion)
                    } else {
                        CravingRunningBody(state: state, reduceMotion: reduceMotion)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, SalusSpacing.lg)
                .padding(.vertical, SalusSpacing.md)
            }

            CravingActions(state: state, onEvent: onEvent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colorScheme.background)
        .navigationTitle(Text(verbatim: SmokingStrings.actionCraving))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                SalusIconButton(
                    systemImage: CravingSymbols.close,
                    accessibilityLabel: SalusUIStrings.sheetClose,
                    action: { onEvent(.closeTapped) }
                )
            }
        }
        .cravingSheets(state.sheet, writing: state.writing, onEvent: onEvent)
        // VoiceOver's two-finger Z: the same way out as the close button, through the same guard in
        // the ViewModel (a full-screen cover has no swipe or back of its own).
        .accessibilityAction(.escape) { onEvent(.closeTapped) }
        // LAST in the chain, and `#if os(iOS)` because the modifier is iOS-only API while every
        // feature package also builds for the macOS test host.
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

enum CravingSymbols {
    static let close = "xmark"
    static let passed = "checkmark.circle"
    static let completed = "checkmark"
    static let next = "arrow.right"
}

// MARK: - Running

private struct CravingRunningBody: View {
    let state: CravingUiState
    let reduceMotion: Bool

    @Environment(\.salusTheme) private var theme

    var body: some View {
        let phaseLabel = state.phase.label
        let minutes = Int(state.remainingMs / CravingDefaults.msPerMinute)
        let seconds = Int((state.remainingMs % CravingDefaults.msPerMinute) / CravingDefaults.msPerSecond)
        // The timer is spoken once, whole, and not every second: a screen reader is not handed it as
        // it ticks.
        let spoken = SmokingStrings.cravingTimerSemantics(SmokingStrings.heroMinSec(minutes, seconds), phaseLabel)

        Text(verbatim: SmokingStrings.cravingHeadline)
            .font(SalusTypography.titleLarge.font)
            .tracking(SalusTypography.titleLarge.tracking)
            .foregroundStyle(theme.colorScheme.onSurface)
            .multilineTextAlignment(.center)

        BreathingRing(
            progress: Double(state.remainingMs) / Double(cravingDurationMs),
            phase: state.phase,
            reduceMotion: reduceMotion,
            completed: false
        ) {
            VStack(spacing: 0) {
                Text(verbatim: countdownText(remainingMs: state.remainingMs))
                    .font(SalusTypography.displaySmall.font)
                    .tracking(SalusTypography.displaySmall.tracking)
                    .monospacedDigit()
                    .foregroundStyle(theme.colorScheme.onSurface)
                Text(verbatim: phaseLabel)
                    .font(SalusTypography.titleMedium.font)
                    .tracking(SalusTypography.titleMedium.tracking)
                    .foregroundStyle(theme.extendedColors.smoking.accent)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: spoken))

        // The three steps of the breath, the current one lit; they are labels, not buttons.
        HStack(spacing: SalusSpacing.sm) {
            ForEach(BreathPhase.allCases, id: \.self) { phase in
                SalusStatusChip(label: phase.chipLabel, status: phase == state.phase ? .accent : .neutral)
                    .accessibilityAddTraits(phase == state.phase ? .isSelected : [])
            }
        }

        CravingLineCard(state: state, reduceMotion: reduceMotion)
    }
}

private struct CravingLineCard: View {
    let state: CravingUiState
    let reduceMotion: Bool

    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusCard {
            VStack(alignment: .leading, spacing: SalusSpacing.sm) {
                // A slow cross-fade: the line changes every 8 seconds and should not jump.
                CravingLineText(line: state.line)
                    .id(state.line)
                    .transition(.opacity)
                    .animation(reduceMotion ? nil : SalusMotion.entranceAnimation, value: state.line)
                if let reason = state.reason {
                    Text(verbatim: SmokingStrings.cravingReason(reason))
                        .font(SalusTypography.bodyMedium.font)
                        .tracking(SalusTypography.bodyMedium.tracking)
                        .italic()
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct CravingLineText: View {
    let line: CravingLine

    @Environment(\.salusTheme) private var theme
    @Environment(\.locale) private var locale

    var body: some View {
        Text(verbatim: text)
            .font(SalusTypography.titleMedium.font)
            .tracking(SalusTypography.titleMedium.tracking)
            .foregroundStyle(theme.colorScheme.onSurface)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var text: String {
        switch line {
        case let .smokeFreeDays(days):
            SmokingStrings.cravingLineDays(days)

        case let .saved(minor, currencyCode):
            SmokingStrings.cravingLineSaved(
                formatMoney(minor: minor, currencyCode: currencyCode, locale: locale, showFraction: false)
            )

        case let .nextStage(stageId):
            StageCopy.title(of: stageId).map { SmokingStrings.cravingLineStage($0) } ?? SmokingStrings.cravingLineFocus

        case .focus:
            SmokingStrings.cravingLineFocus
        }
    }
}

extension BreathPhase {
    var label: String {
        switch self {
        case .inhale: SmokingStrings.cravingPhaseIn
        case .hold: SmokingStrings.cravingPhaseHold
        case .exhale: SmokingStrings.cravingPhaseOut
        }
    }

    var chipLabel: String {
        switch self {
        case .inhale: SmokingStrings.cravingChipIn
        case .hold: SmokingStrings.cravingChipHold
        case .exhale: SmokingStrings.cravingChipOut
        }
    }
}

// MARK: - Completed

private struct CravingCompletedBody: View {
    let state: CravingUiState
    let reduceMotion: Bool

    @Environment(\.salusTheme) private var theme

    var body: some View {
        let accent = theme.extendedColors.smoking
        let spoken = state.logged ? SmokingStrings.cravingDoneTitle : SmokingStrings.cravingDoneSemantics

        BreathingRing(progress: 1, phase: state.phase, reduceMotion: reduceMotion, completed: true) {
            Image(systemName: CravingSymbols.completed)
                .font(.system(size: BreathingRingDefaults.checkSize, weight: .semibold))
                .foregroundStyle(accent.accent)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: spoken))

        Text(verbatim: SmokingStrings.cravingDoneTitle)
            .font(SalusTypography.headlineLarge.font)
            .tracking(SalusTypography.headlineLarge.tracking)
            .foregroundStyle(theme.colorScheme.onSurface)
            .multilineTextAlignment(.center)

        if let count = state.loggedCount {
            Text(verbatim: SmokingStrings.cravingDoneCount(count))
                .font(SalusTypography.titleMedium.font)
                .tracking(SalusTypography.titleMedium.tracking)
                .foregroundStyle(accent.accent)
                .multilineTextAlignment(.center)
        } else if !state.logged {
            // The five minutes ran out on their own: nothing is written until the person says so.
            Text(verbatim: SmokingStrings.cravingDoneTimer)
                .font(SalusTypography.bodyLarge.font)
                .tracking(SalusTypography.bodyLarge.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Actions

/// "Geçti" and the quiet "Sigara içtim" while the craving is open; "Devam" once it is logged.
/// Disabled while a write is in flight. "Sigara içtim" waits for the snapshot to say which plan this
/// is, since QUIT and REDUCE answer it differently.
private struct CravingActions: View {
    let state: CravingUiState
    let onEvent: (CravingEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        let accent = theme.extendedColors.smoking
        VStack(spacing: SalusSpacing.xs) {
            if state.logged {
                SalusButton(
                    SmokingStrings.cravingContinue,
                    systemImage: CravingSymbols.next,
                    accent: accent,
                    enabled: !state.writing
                ) { onEvent(.continueTapped) }
            } else {
                SalusButton(
                    SmokingStrings.cravingPassed,
                    systemImage: CravingSymbols.passed,
                    accent: accent,
                    enabled: !state.writing
                ) { onEvent(.passedTapped) }
                Button { onEvent(.smokedTapped) } label: {
                    Text(verbatim: SmokingStrings.actionSmoked)
                        .font(SalusTypography.labelLarge.font)
                        .tracking(SalusTypography.labelLarge.tracking)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                        .frame(minHeight: SalusTouchTarget.min)
                        .padding(.horizontal, SalusSpacing.lg)
                }
                .buttonStyle(.plain)
                .disabled(state.writing || state.mode == nil)
            }
        }
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.vertical, SalusSpacing.sm)
    }
}

enum CravingDefaults {
    /// Where the slip sheet's stepper starts.
    static let slipDefaultUnits = 1
    static let msPerSecond: Int64 = 1000
    static let msPerMinute: Int64 = 60000
}
