// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/di/
// SmokingModule.kt`.
//
// Koin's `module { … }` becomes a value the composition root builds once and hands down (no
// container; see `docs/ios-feature-template.md`, "Module factory"). The single Koin `viewModel`
// registrations become `makeSetupViewModel`, `makeMainViewModel`, `makeTimelineViewModel` and
// `makeCravingViewModel`; each later task adds its screen's factory here.
//
// The module carries `clock` and `snackbar` because two things the Android Routes `koinInject` are
// not reachable from a package any other way: the clock the quit-date sheet checks "future"
// against, and the shell's one snackbar controller the setup reports an error through.

import SalusCommon
import SalusNavigation
import SalusPremium
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
    /// The domain: the repository and the sixteen use cases, built once by the root.
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
    public let makeMainViewModel: @MainActor () -> SmokingMainViewModel

    /// `viewModel { CravingViewModel(repository = get(), clock = get(), …) }`. A new one per
    /// presentation of the cover: its start instant is the moment it is made, so a closed flow never
    /// leaves a stale timer behind.
    public let makeCravingViewModel: @MainActor () -> CravingViewModel

    /// Which craving key is on screen as a full-screen cover. The shell hands every navigation
    /// command to it before the back stacks, so Main and Home reach the cover along one path.
    public let cravingPresenter: SmokingCravingPresenter

    /// `viewModel { parameters -> SmokingTimelineViewModel(highlightStageId = parameters.get(), …) }`.
    /// The id is the stage a link named, or `nil`.
    public let makeTimelineViewModel: @MainActor (String?) -> SmokingTimelineViewModel

    /// `viewModel { SmokingHistoryViewModel(repository = get(), editEvent = get(), deleteEvent = get(), …) }`.
    public let makeHistoryViewModel: @MainActor () -> SmokingHistoryViewModel

    /// `viewModel { SmokingSettingsViewModel(repository = get(), updatePrice = get(), …) }`.
    public let makeSettingsViewModel: @MainActor () -> SmokingSettingsViewModel
}

/// Builds the feature's graph — the twin of `val smokingModule = module { … }`. Every dependency is
/// passed in and none is reached for. The parameter list is the dependency list — the shape Koin's
/// `module { }` block has — so `function_parameter_count` is answered with a targeted disable, as
/// `makeSettingsModule` does, and not by a struct that would exist only to satisfy a count.
@MainActor
// swiftlint:disable:next function_parameter_count
public func makeSmokingModule(
    core: SmokingCoreModule,
    clock: any SalusClock,
    snackbar: SalusSnackbarController,
    navigator: Navigator,
    reminderScheduler: any ReminderScheduler,
    reminderEnvironment: any ReminderEnvironment,
    premiumRepository: any PremiumRepository,
    paywallController: PaywallController
) -> SmokingModule {
    // Koin's `getAll<SmokingChangeListener>()`: every committed smoking write asks the engine to
    // refill its window, so a slip, a reset or a mode switch moves or cancels the milestones.
    core.changeListeners.add(SmokingReminderResync(scheduler: reminderScheduler))
    // One presenter, shared by the module's `cravingPresenter` and the craving ViewModel's close.
    let cravingPresenter = SmokingCravingPresenter()
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
        makeMainViewModel: mainFactory(
            core: core,
            clock: clock,
            snackbar: snackbar,
            navigator: navigator,
            premiumRepository: premiumRepository,
            paywallController: paywallController
        ),
        makeCravingViewModel: cravingFactory(core: core, clock: clock, presenter: cravingPresenter),
        cravingPresenter: cravingPresenter,
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

/// The main screen's factory, apart from `makeSmokingModule` for the same reason as the settings
/// screen's below: with the goal use cases and the premium collaborators it takes the most arguments
/// of any ViewModel but the settings one, and the function is at SwiftLint's body length.
@MainActor
private func mainFactory(
    core: SmokingCoreModule,
    clock: any SalusClock,
    snackbar: SalusSnackbarController,
    navigator: Navigator,
    premiumRepository: any PremiumRepository,
    paywallController: PaywallController
) -> @MainActor () -> SmokingMainViewModel {
    {
        SmokingMainViewModel(
            repository: core.repository,
            clock: clock,
            resolveSlip: core.resolveSlip,
            editEvent: core.editEvent,
            logSmoked: core.logSmoked,
            deleteEvent: core.deleteEvent,
            logNoneToday: core.logNoneToday,
            switchMode: core.switchMode,
            saveSavingsGoal: core.saveSavingsGoal,
            markGoalAchieved: core.markGoalAchieved,
            updateSavingsGoal: core.updateSavingsGoal,
            premiumRepository: premiumRepository,
            paywallController: paywallController,
            snackbar: snackbar,
            navigator: navigator
        )
    }
}

/// The craving flow's factory, apart from `makeSmokingModule` for the same reason as the settings
/// screen's below: the function is at SwiftLint's body length.
@MainActor
private func cravingFactory(
    core: SmokingCoreModule,
    clock: any SalusClock,
    presenter: SmokingCravingPresenter
) -> @MainActor () -> CravingViewModel {
    {
        CravingViewModel(
            repository: core.repository,
            clock: clock,
            logCravingResisted: core.logCravingResisted,
            logSmoked: core.logSmoked,
            resolveSlip: core.resolveSlip,
            editEvent: core.editEvent,
            closeCover: { presenter.dismiss() }
        )
    }
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
