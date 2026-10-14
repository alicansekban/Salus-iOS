// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/history/
// SmokingHistoryRoute.kt`.
//
// No `onBack` of the shell's: a pushed screen's exit is the system back button, and the empty
// state's "Ana ekrana dön" pops through the module's `Navigator`, as Android's `navigator::pop`.

import SalusCommon
import SalusUI
import SwiftUI

/// The stateful end of the history screen: state in, events out, errors to the snackbar.
public struct SmokingHistoryRoute: View {
    @Environment(\.smokingModule) private var module

    @State private var viewModel: SmokingHistoryViewModel?

    public init() {}

    public var body: some View {
        Group {
            if let viewModel, let module {
                SmokingHistoryScreen(
                    state: viewModel.state,
                    onEvent: viewModel.onEvent,
                    onBack: { module.navigator.pop() },
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
            } else {
                // Only until `.task` has run, or if the shell forgot to inject the module.
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard viewModel == nil, let module else { return }
            viewModel = module.makeHistoryViewModel()
        }
    }

    private func show(_ effect: SmokingHistoryEffect, on module: SmokingModule) {
        switch effect {
        case let .showError(error):
            module.snackbar.show(SnackbarRequest(message: error.message))
        }
    }
}

extension SmokingHistoryError {
    /// The snackbar sentence for each kind.
    var message: String {
        switch self {
        case .future: SmokingStrings.historyErrorFuture
        case .invalid: SmokingStrings.historyErrorInvalid
        case .generic: SmokingStrings.errorGeneric
        }
    }
}
