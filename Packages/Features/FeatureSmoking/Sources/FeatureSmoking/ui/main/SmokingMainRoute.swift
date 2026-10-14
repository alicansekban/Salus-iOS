// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/main/
// SmokingMainRoute.kt`.
//
// Not ported: the `LaunchedEffect` + `repeatOnLifecycle(STARTED)` that runs the ViewModel's ticker.
// The counters tick inside the screen's `TimelineView`, which SwiftUI already stops while the view
// is off screen or the app is in the background.

import SalusCommon
import SalusUI
import SwiftUI

/// The stateful end of the main screen. `onOpenTrends` is the shell's callback: Trends belongs to
/// another feature, whose key this one cannot see, so the insights card asks the shell to open it.
public struct SmokingMainRoute: View {
    let onOpenTrends: () -> Void

    @Environment(\.smokingModule) private var module

    @State private var viewModel: SmokingMainViewModel?

    public init(onOpenTrends: @escaping () -> Void) {
        self.onOpenTrends = onOpenTrends
    }

    public var body: some View {
        Group {
            if let viewModel, let module {
                SmokingMainScreen(
                    state: viewModel.state,
                    onEvent: { event in
                        switch event {
                        case .insightsTapped: onOpenTrends()
                        default: viewModel.onEvent(event)
                        }
                    }
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
        case .showError:
            module.snackbar.show(SnackbarRequest(message: SmokingStrings.errorGeneric))
        }
    }
}
