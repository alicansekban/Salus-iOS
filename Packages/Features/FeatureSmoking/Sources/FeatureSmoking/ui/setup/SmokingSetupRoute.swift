// Ported from `SmokingSetupRoute` in `SmokingSetupScreen.kt:52-74`.

import SalusCommon
import SalusUI
import SwiftUI

/// Owns the ViewModel and wires it to the shell.
///
/// The currency comes from the locale, which only the view layer can read; the ViewModel is created
/// once with it, so a later locale change does not reset a half-filled wizard.
public struct SmokingSetupRoute: View {
    @Environment(\.smokingModule) private var module
    @Environment(\.locale) private var locale

    @State private var viewModel: SmokingSetupViewModel?

    public init() {}

    public var body: some View {
        Group {
            if let viewModel, let module {
                SmokingSetupScreen(state: viewModel.state, onEvent: viewModel.onEvent, clock: module.clock)
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
            viewModel = module.makeSetupViewModel(defaultCurrencyCode(for: locale))
        }
    }

    private func show(_ effect: SmokingSetupEffect, on module: SmokingModule) {
        switch effect {
        case let .showError(error):
            module.snackbar.show(SnackbarRequest(message: error.message))
        }
    }
}

extension SmokingSetupError {
    fileprivate var message: String {
        switch self {
        case .futureDate: SmokingStrings.setupErrorFutureDate
        case .invalid: SmokingStrings.setupErrorInvalid
        case .generic: SmokingStrings.errorGeneric
        }
    }
}
