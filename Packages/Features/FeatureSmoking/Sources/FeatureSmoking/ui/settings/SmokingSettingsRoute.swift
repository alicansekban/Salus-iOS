// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/settings/
// SmokingSettingsRoute.kt`.
//
// No `onBack`: a pushed screen's exit is the system back button; a reset pops through the
// ViewModel's `Navigator`.

import SalusCommon
import SalusUI
import SwiftUI

/// The stateful end of the smoking settings. `onOpenReminderHealth` is the shell's callback: the
/// reminder-readiness screen belongs to another feature, whose key this one cannot see.
public struct SmokingSettingsRoute: View {
    let onOpenReminderHealth: () -> Void

    @Environment(\.smokingModule) private var module

    @State private var viewModel: SmokingSettingsViewModel?

    public init(onOpenReminderHealth: @escaping () -> Void) {
        self.onOpenReminderHealth = onOpenReminderHealth
    }

    public var body: some View {
        Group {
            if let viewModel, let module {
                SmokingSettingsScreen(state: viewModel.state, onEvent: viewModel.onEvent, clock: module.clock)
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
            viewModel = module.makeSettingsViewModel()
        }
    }

    private func show(_ effect: SmokingSettingsEffect, on module: SmokingModule) {
        switch effect {
        case let .showError(error):
            module.snackbar.show(SnackbarRequest(message: error.message))

        case .openReminderHealth:
            onOpenReminderHealth()
        }
    }
}

extension SmokingSettingsError {
    /// The snackbar sentence for each kind.
    var message: String {
        switch self {
        case .futureDate: SmokingStrings.setupErrorFutureDate
        case .invalid: SmokingStrings.setupErrorInvalid
        case .overlap: SmokingStrings.quitErrorOverlap
        case .generic: SmokingStrings.errorGeneric
        }
    }
}
