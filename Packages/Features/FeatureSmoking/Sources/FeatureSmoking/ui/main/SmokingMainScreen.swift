// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/main/
// SmokingMainScreen.kt`.
//
// The smoking main screen: the mode's content, the pinned actions below it, and the sheets
// that hang off ``SmokingMainUiState/sheet``. A pushed screen, so the shell has already reserved
// the insets and the system bar names it.
//
// Compose → SwiftUI, beyond the shared mapping table:
//   `SalusTopBar.Pushed(title, onBack, actions)` → `.navigationTitle` + inline mode, the back
//                           button the system's, and the history and settings icons as two
//                           `ToolbarItem(placement: .primaryAction)`s (spec §2.2).
//   `Column(weight(1f))` + pinned `Column`       → a `ScrollView` over a pinned `VStack`.
//   `SalusIconButtonTone.Neutral`                 → `SalusIconButton`'s default tone.

import SalusCommon
import SalusDesignSystem
import SalusSmoking
import SalusUI
import SwiftUI

/// The stateless screen: `state` + `onEvent` only, so it previews without a ViewModel.
/// `counterClock` is ``CounterClock/live`` on device and a fixed instant in a preview.
struct SmokingMainScreen: View {
    let state: SmokingMainUiState
    let onEvent: (SmokingMainEvent) -> Void
    var counterClock: CounterClock = .live
    /// "Now" for the quit-date sheet; the app's clock on device, a fixed one in a preview.
    var clock: any SalusClock = SystemSalusClock()

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: SalusSpacing.md) {
                    switch state.snapshot {
                    case let .quit(quit):
                        QuitContent(quit: quit, counterClock: counterClock, onEvent: onEvent)
                    case let .reduce(reduce):
                        ReduceContent(reduce: reduce, writing: state.writing, onEvent: onEvent)
                    case nil, .notSetUp:
                        EmptyView()
                    }
                }
                .padding(.horizontal, SalusSpacing.lg)
                .padding(.vertical, SalusSpacing.md)
            }

            switch state.snapshot {
            case .quit:
                PinnedActions(showSmoked: true, enabled: !state.writing, onEvent: onEvent)
            case .reduce:
                PinnedActions(showSmoked: false, enabled: !state.writing, onEvent: onEvent)
            case nil, .notSetUp:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colorScheme.background)
        .navigationTitle(Text(verbatim: SmokingStrings.title))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                SalusIconButton(
                    systemImage: MainSymbols.history,
                    accessibilityLabel: SmokingStrings.mainHistoryCd,
                    action: { onEvent(.historyTapped) }
                )
            }
            ToolbarItem(placement: .primaryAction) {
                SalusIconButton(
                    systemImage: MainSymbols.settings,
                    accessibilityLabel: SmokingStrings.mainSettingsCd,
                    action: { onEvent(.settingsTapped) }
                )
            }
        }
        .mainSheets(state.sheet, writing: state.writing, clock: clock, onEvent: onEvent)
        // LAST in the chain, and `#if os(iOS)` because the modifier is iOS-only API while every
        // feature package also builds for the macOS test host.
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

private enum MainSymbols {
    static let history = "clock.arrow.circlepath"
    static let settings = "gearshape"
    static let craving = "figure.mind.and.body"
}

/// "Canım çekti" and, in QUIT only, the quiet text button "Sigara içtim" (review R3: nothing else
/// is pinned). Disabled while a write is in flight.
private struct PinnedActions: View {
    let showSmoked: Bool
    let enabled: Bool
    let onEvent: (SmokingMainEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(spacing: SalusSpacing.xs) {
            SalusButton(
                SmokingStrings.actionCraving,
                systemImage: MainSymbols.craving,
                accent: theme.extendedColors.smoking,
                enabled: enabled
            ) { onEvent(.cravingTapped) }
            if showSmoked {
                Button { onEvent(.smokedTapped) } label: {
                    Text(verbatim: SmokingStrings.actionSmoked)
                        .font(SalusTypography.labelLarge.font)
                        .tracking(SalusTypography.labelLarge.tracking)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                        .frame(minHeight: SalusTouchTarget.min)
                        .padding(.horizontal, SalusSpacing.lg)
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
            }
        }
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.vertical, SalusSpacing.sm)
    }
}
