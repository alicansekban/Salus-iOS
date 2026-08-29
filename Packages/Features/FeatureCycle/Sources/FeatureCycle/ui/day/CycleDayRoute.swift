// The day-log screen's Route — the twin of `@Composable fun CycleDayRoute`
// (`feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/ui/day/
// CycleDayScreen.kt:46-59`).
//
// Kotlin's `koinViewModel(parameters = { parametersOf(epochDay) })` is a container lookup with a
// runtime argument; there is no container here, so the parameterised factory the composition root
// built is read from the environment and called with the same argument
// (`CycleModule.makeCycleDayViewModel`). `MedicationEditorRoute` set that shape and this follows it.
//
// Kotlin's second `koinInject<Navigator>()` has no twin: `onBack` is the system back arrow on the
// shell's own stack, which pops the very path `Navigator.pop()` mutates — see the mapping note at
// the top of `CycleDayScreen.swift`.

import SwiftUI

/// One day's log (`CycleDayScreen.kt:46-59`).
///
/// No callback parameters: the only way out of this screen is a pop, and `Navigator` already
/// carries that.
public struct CycleDayRoute: View {
    /// The day being logged, as the epoch day the key carries.
    private let epochDay: Int

    @Environment(\.cycleModule) private var module
    @State private var viewModel: CycleDayViewModel?

    public init(epochDay: Int) {
        self.epochDay = epochDay
    }

    public var body: some View {
        Group {
            if let viewModel {
                CycleDayScreen(state: viewModel.state, onEvent: viewModel.onEvent)
            } else {
                // Only until `.task` has run, or if the shell forgot to inject the module.
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard viewModel == nil, let module else { return }
            viewModel = module.makeCycleDayViewModel(epochDay)
        }
    }
}
