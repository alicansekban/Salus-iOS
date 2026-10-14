// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/timeline/
// SmokingTimelineRoute.kt`.
//
// Koin's `parametersOf(highlightStageId.orEmpty())` is gone: the module's factory takes the
// optional id as it is. No `onBack`: a pushed screen's exit is the system back button.

import SalusCommon
import SalusUI
import SwiftUI

/// The stateful end of the health timeline. `highlightStageId` is the stage a link named, or `nil`;
/// an id the catalog does not know highlights nothing.
public struct SmokingTimelineRoute: View {
    let highlightStageId: String?

    @Environment(\.smokingModule) private var module

    @State private var viewModel: SmokingTimelineViewModel?

    public init(highlightStageId: String?) {
        self.highlightStageId = highlightStageId
    }

    public var body: some View {
        Group {
            if let viewModel, let module {
                SmokingTimelineScreen(state: viewModel.state, onEvent: viewModel.onEvent, clock: module.clock)
                    // `Channel.receiveAsFlow()` collected in a `LaunchedEffect`, spelled for an
                    // `@Observable` queue: it fires on the drain's own write too, so the empty edge
                    // is dropped.
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
            viewModel = module.makeTimelineViewModel(highlightStageId)
        }
    }

    private func show(_ effect: SmokingTimelineEffect, on module: SmokingModule) {
        switch effect {
        case let .showError(error):
            module.snackbar.show(SnackbarRequest(message: error.message))
        }
    }
}
