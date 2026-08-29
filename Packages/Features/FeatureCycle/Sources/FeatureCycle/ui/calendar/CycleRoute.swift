// Ported from `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/
// ui/calendar/CycleScreen.kt:79-90`.
//
// The Route is the template's (`docs/ios-feature-template.md`): the module comes from the
// environment, the ViewModel is built once in `.task` and owned for the route's lifetime, and the
// stateless `CycleScreen` gets `state`, `onEvent` and the one navigation callback. Koin's
// `koinViewModel()` / `koinInject<Navigator>()` are the two lines this replaces —
// `MedicationsRoute.swift:22-56` is the shape, feature for feature.

import SwiftUI

/// The cycle calendar (`CycleScreen.kt:79-90`).
public struct CycleRoute: View {
    @Environment(\.cycleModule) private var module
    @State private var viewModel: CycleViewModel?

    public init() {}

    public var body: some View {
        Group {
            if let viewModel {
                CycleScreen(
                    state: viewModel.state,
                    onEvent: viewModel.onEvent,
                    // `navigator.navigate(CycleDayKey(epochDay))` (`CycleScreen.kt:88`).
                    onOpenDay: { epochDay in module?.navigator.navigate(CycleDayKey(epochDay: epochDay)) }
                )
            } else {
                // A dropped injection draws the spinner rather than a half-built graph — the
                // reason `cycleModule` is optional (`CycleModule.swift`'s `@Entry` note).
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            // Built once: the ViewModel opens its own observation of the periods and the reminder
            // settings, and a second one would be a second stream over the same tables.
            guard viewModel == nil, let module else { return }
            viewModel = module.makeCycleViewModel()
        }
    }
}
