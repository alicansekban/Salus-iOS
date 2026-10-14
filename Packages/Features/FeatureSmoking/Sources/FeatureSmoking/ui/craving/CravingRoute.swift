// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/craving/
// CravingRoute.kt`.
//
// The stateful end of the craving flow. The timer's clock runs only while the scene is active; the
// time spent in the background is not lost, because the ViewModel measures from the start instant
// rather than counting, and the first read after the scene comes back catches up.
//
// Compose → SwiftUI:
//   `repeatOnLifecycle(STARTED) { runClock() }`     → `.task(id: scenePhase)`, running the ticker
//                           while the phase is `.active`; SwiftUI cancels it when the phase changes
//                           and starts it again on the way back, whose first read is the catch-up.
//   `isMotionReduced(context)`                      → `@Environment(\.accessibilityReduceMotion)`,
//                           which SwiftUI keeps current (no resume-time re-read needed).
//   `BackHandler`                                   → none: a full-screen cover has no system back
//                           and no swipe to dismiss, so the close button is the only way out.
//   `koinViewModel`                                 → the module's factory, in `.task`.

import SalusCommon
import SalusUI
import SwiftUI

/// The stateful end of the craving flow.
public struct CravingRoute: View {
    @Environment(\.smokingModule) private var module
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel: CravingViewModel?

    public init() {}

    public var body: some View {
        Group {
            if let viewModel, let module {
                CravingScreen(state: viewModel.state, reduceMotion: reduceMotion, onEvent: viewModel.onEvent)
                    // `Channel.receiveAsFlow()` collected in a `LaunchedEffect`, spelled for an
                    // `@Observable` queue: it fires on the drain's own write too, so the empty edge
                    // is dropped.
                    .onChange(of: viewModel.pendingEffects) { _, pending in
                        guard !pending.isEmpty else { return }
                        for effect in viewModel.consumeEffects() {
                            show(effect, on: module)
                        }
                    }
                    .task(id: scenePhase) {
                        if scenePhase == .active {
                            await viewModel.runClock()
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
            viewModel = module.makeCravingViewModel()
        }
    }

    private func show(_ effect: CravingEffect, on module: SmokingModule) {
        switch effect {
        case .showError:
            module.snackbar.show(SnackbarRequest(message: SmokingStrings.errorGeneric))
        }
    }
}
