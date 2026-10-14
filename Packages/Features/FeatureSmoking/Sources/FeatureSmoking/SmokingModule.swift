// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/di/
// SmokingModule.kt`.
//
// Koin's `module { … }` becomes a value the composition root builds once and hands down (no
// container; see `docs/ios-feature-template.md`, "Module factory"). The single Koin `viewModel`
// registrations become `makeSetupViewModel`, `makeMainViewModel` and `makeTimelineViewModel`; each
// later task adds its screen's factory here.
//
// The module carries `clock` and `snackbar` because two things the Android Routes `koinInject` are
// not reachable from a package any other way: the clock the quit-date sheet checks "future"
// against, and the shell's one snackbar controller the setup reports an error through.

import SalusCommon
import SalusNavigation
import SalusReminder
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

    /// `single<ReminderHandler>(named(ReminderType.SMOKING.name))`: the milestone notifications
    /// (plan Task 17), which the composition root appends to the engine's handler registry.
    public let reminderHandler: SmokingReminderHandler

    /// `viewModel { parameters -> SmokingSetupViewModel(defaultCurrencyCode = parameters.get(), …) }`.
    /// The currency comes from the locale, which only the composition can read.
    public let makeSetupViewModel: @MainActor (String) -> SmokingSetupViewModel

    /// `viewModel { SmokingMainViewModel(repository = get(), premiumRepository = get(), …) }`.
    /// The premium repository is not here yet: nothing on the main screen reads it until the goal
    /// and insights cards (plan Task 15) arrive, which add it with the composition-root change it
    /// needs (the premium graph is built after the scheduled modules, smoking among them).
    public let makeMainViewModel: @MainActor () -> SmokingMainViewModel

    /// `viewModel { parameters -> SmokingTimelineViewModel(highlightStageId = parameters.get(), …) }`.
    /// The id is the stage a link named, or `nil`.
    public let makeTimelineViewModel: @MainActor (String?) -> SmokingTimelineViewModel

    /// `viewModel { SmokingHistoryViewModel(repository = get(), editEvent = get(), deleteEvent = get(), …) }`.
    public let makeHistoryViewModel: @MainActor () -> SmokingHistoryViewModel

    /// `viewModel { SmokingSettingsViewModel(repository = get(), updatePrice = get(), …) }`.
    public let makeSettingsViewModel: @MainActor () -> SmokingSettingsViewModel
}

/// Builds the feature's graph — the twin of `val smokingModule = module { … }`. Every dependency is
/// passed in and none is reached for.
@MainActor
public func makeSmokingModule(
    core: SmokingCoreModule,
    clock: any SalusClock,
    snackbar: SalusSnackbarController,
    navigator: Navigator,
    reminderScheduler: any ReminderScheduler,
    reminderEnvironment: any ReminderEnvironment
) -> SmokingModule {
    // Koin's `getAll<SmokingChangeListener>()`: every committed smoking write asks the engine to
    // refill its window, so a slip, a reset or a mode switch moves or cancels the milestones.
    core.changeListeners.add(SmokingReminderResync(scheduler: reminderScheduler))
    return SmokingModule(
        core: core,
        navigator: navigator,
        snackbar: snackbar,
        clock: clock,
        reminderHandler: SmokingReminderHandler(
            repository: core.repository,
            clock: clock,
            strings: SystemSmokingNotificationStrings()
        ),
        makeSetupViewModel: { defaultCurrencyCode in
            SmokingSetupViewModel(
                defaultCurrencyCode: defaultCurrencyCode,
                setUpSmoking: core.setUp,
                clock: clock,
                navigator: navigator
            )
        },
        makeMainViewModel: {
            SmokingMainViewModel(
                repository: core.repository,
                clock: clock,
                resolveSlip: core.resolveSlip,
                editEvent: core.editEvent,
                logSmoked: core.logSmoked,
                deleteEvent: core.deleteEvent,
                logNoneToday: core.logNoneToday,
                switchMode: core.switchMode,
                snackbar: snackbar,
                navigator: navigator
            )
        },
        makeTimelineViewModel: { highlightStageId in
            SmokingTimelineViewModel(
                highlightStageId: highlightStageId,
                repository: core.repository,
                switchMode: core.switchMode,
                clock: clock
            )
        },
        makeHistoryViewModel: {
            SmokingHistoryViewModel(
                repository: core.repository,
                editEvent: core.editEvent,
                deleteEvent: core.deleteEvent,
                clock: clock
            )
        },
        makeSettingsViewModel: settingsFactory(
            core: core,
            clock: clock,
            navigator: navigator,
            environment: reminderEnvironment
        )
    )
}

/// The settings screen's factory, apart from `makeSmokingModule` to keep that function inside
/// SwiftLint's body length: it takes the most collaborators of any screen.
@MainActor
private func settingsFactory(
    core: SmokingCoreModule,
    clock: any SalusClock,
    navigator: Navigator,
    environment: any ReminderEnvironment
) -> @MainActor () -> SmokingSettingsViewModel {
    {
        SmokingSettingsViewModel(
            repository: core.repository,
            updatePrice: core.updatePrice,
            updateCurrency: core.updateCurrency,
            updatePlanFields: core.updatePlanFields,
            editQuitDate: core.editQuitDate,
            switchMode: core.switchMode,
            resetSmoking: core.resetSmoking,
            environment: environment,
            clock: clock,
            navigator: navigator
        )
    }
}

extension EnvironmentValues {
    /// How the module reaches this feature's Routes. Optional because an `@Entry` needs a default
    /// and there is no honest one: a Route that finds `nil` draws its spinner, so a dropped
    /// injection looks like a dropped injection.
    @Entry public var smokingModule: SmokingModule?
}
