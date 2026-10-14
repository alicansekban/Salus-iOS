// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/main/
// SmokingMainRoute.kt`.
//
// Not ported: the `LaunchedEffect` + `repeatOnLifecycle(STARTED)` that runs the ViewModel's ticker.
// The counters tick inside the screen's `TimelineView`, which SwiftUI already stops while the view
// is off screen or the app is in the background.

import SalusCommon
import SalusSmoking
import SalusUI
import SwiftUI

/// The stateful end of the main screen. `onOpenTrends` is the shell's callback: Trends belongs to
/// another feature, whose key this one cannot see, so the insights teaser asks the shell to open it
/// once the ViewModel has decided a tap is not for the paywall (``SmokingMainEffect/openTrends``).
public struct SmokingMainRoute: View {
    let onOpenTrends: () -> Void

    @Environment(\.smokingModule) private var module

    @State private var viewModel: SmokingMainViewModel?

    /// Whether Main is the top screen of its stack. SwiftUI keeps a covered view alive, so the
    /// ViewModel of a Main under Settings or the timeline is still observing snapshots; Android only
    /// composes the top entry.
    @State private var isOnScreen = false

    public init(onOpenTrends: @escaping () -> Void) {
        self.onOpenTrends = onOpenTrends
    }

    public var body: some View {
        Group {
            if let viewModel, let module {
                SmokingMainScreen(
                    state: viewModel.state,
                    onEvent: viewModel.onEvent,
                    clock: module.clock
                )
                // `Channel.receiveAsFlow()` collected in a `LaunchedEffect`, spelled for an
                // `@Observable` queue: it fires on the drain's own write too, so the empty edge is
                // dropped.
                .onChange(of: viewModel.pendingEffects) { _, pending in
                    guard !pending.isEmpty else { return }
                    for effect in viewModel.consumeEffects() {
                        show(effect, on: module)
                    }
                }
                .onAppear { isOnScreen = true }
                .onDisappear { isOnScreen = false }
                // A plan that is gone while this screen is on top (a stale notification after a
                // reset) has nothing to draw, so the ViewModel swaps it for the setup. Keyed on the
                // fact "on top and no plan", not on the snapshot, so the minute-by-minute
                // re-emissions do not repeat it, and a covered Main (Settings, the timeline over it)
                // stays silent until it is uncovered.
                .task(id: planMissingSignal(isOnScreen: isOnScreen, snapshot: viewModel.state.snapshot)) {
                    if planMissingSignal(isOnScreen: isOnScreen, snapshot: viewModel.state.snapshot) {
                        viewModel.onEvent(.planMissing)
                    }
                }
            } else {
                // Only until `.task` has run, or if the shell forgot to inject the module.
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard viewModel == nil, let module else { return }
            viewModel = module.makeMainViewModel()
        }
    }

    private func show(_ effect: SmokingMainEffect, on module: SmokingModule) {
        switch effect {
        case let .showError(error):
            module.snackbar.show(SnackbarRequest(message: message(for: error)))
        case .openTrends:
            onOpenTrends()
        }
    }

    private func message(for error: SmokingMainError) -> String {
        switch error {
        case .generic: SmokingStrings.errorGeneric
        case .quitOverlap: SmokingStrings.quitErrorOverlap
        case .quitFuture: SmokingStrings.quitSheetFuture
        }
    }
}

/// Whether the Route should tell the ViewModel the plan is missing: Main is the top screen and its
/// snapshot says there is no plan. Nothing before the first snapshot, and nothing while covered.
func planMissingSignal(isOnScreen: Bool, snapshot: SmokingSnapshot?) -> Bool {
    isOnScreen && snapshot == .notSetUp
}
