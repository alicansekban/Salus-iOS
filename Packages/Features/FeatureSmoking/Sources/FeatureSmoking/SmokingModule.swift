// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/di/
// SmokingModule.kt`.
//
// Koin's `module { … }` becomes a value the composition root builds once and hands down (no
// container; see `docs/ios-feature-template.md`, "Module factory"). The single Koin `viewModel`
// registration becomes `makeSetupViewModel`; each later task adds its screen's factory here.
//
// The module carries `clock` and `snackbar` because two things the Android Routes `koinInject` are
// not reachable from a package any other way: the clock the quit-date sheet checks "future"
// against, and the shell's one snackbar controller the setup reports an error through.

import SalusCommon
import SalusNavigation
import SalusSmoking
import SalusUI
import SwiftUI

/// Everything this feature's views need, built by the composition root.
///
/// `@MainActor` because every ViewModel it makes is: the factories are called from a view's
/// `.task`, which already runs there.
@MainActor
public struct SmokingModule {
    /// The domain: the repository and the fifteen use cases, built once by the root.
    public let core: SmokingCoreModule

    /// Publishes what the Routes and ViewModels ask for; the shell applies it.
    public let navigator: Navigator

    /// The app's one snackbar controller, for the errors a ViewModel cannot show itself.
    public let snackbar: SalusSnackbarController

    /// The app's clock, so the quit-date sheet and the ViewModels agree on "now".
    public let clock: any SalusClock

    /// `viewModel { parameters -> SmokingSetupViewModel(defaultCurrencyCode = parameters.get(), …) }`.
    /// The currency comes from the locale, which only the composition can read.
    public let makeSetupViewModel: @MainActor (String) -> SmokingSetupViewModel
}

/// Builds the feature's graph — the twin of `val smokingModule = module { … }`. Every dependency is
/// passed in and none is reached for.
@MainActor
public func makeSmokingModule(
    core: SmokingCoreModule,
    clock: any SalusClock,
    snackbar: SalusSnackbarController,
    navigator: Navigator
) -> SmokingModule {
    SmokingModule(
        core: core,
        navigator: navigator,
        snackbar: snackbar,
        clock: clock,
        makeSetupViewModel: { defaultCurrencyCode in
            SmokingSetupViewModel(
                defaultCurrencyCode: defaultCurrencyCode,
                setUpSmoking: core.setUp,
                clock: clock,
                navigator: navigator
            )
        }
    )
}

extension EnvironmentValues {
    /// How the module reaches this feature's Routes. Optional because an `@Entry` needs a default
    /// and there is no honest one: a Route that finds `nil` draws its spinner, so a dropped
    /// injection looks like a dropped injection.
    @Entry public var smokingModule: SmokingModule?
}
