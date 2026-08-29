// Ported from `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/
// di/CycleModule.kt`.
//
// Koin's `module { … }` is a description the container resolves at each call site; there is no
// container here (`CLAUDE.md`: "the composition root owns the singletons"), so the module is a
// value the composition root builds once and hands down. The Koin scopes map exactly:
//
//   `single<CycleRepository> { … }`           → the `repository` property, built once by
//                                               `makeCycleModule`.
//   `factoryOf(::CyclePredictor)` and the     → values with no identity, built inline below; both
//     three use-case factories                  the handler and the ViewModel get their own, which
//                                               is what Koin's `factory` amounts to here.
//   `single<CycleReminderSettings> { … }`     → one instance, shared by the handler and the
//                                               ViewModel, so the toggle the screen writes is the
//                                               one the engine reads back.
//   `factory<CycleNotificationTexts> { … }`   → `LocalizedCycleNotificationTexts()`, which reads
//                                               the feature catalog through `Bundle.module` — the
//                                               twin of Android handing the handler an
//                                               `androidContext()` it resolves its strings from.
//   `single { CycleReminderHandler(…) }`      → built inline and handed straight out; the engine's
//     `bind ReminderHandler::class`             registry is its only consumer.
//   `viewModelOf(::CycleViewModel)`           → `makeCycleViewModel`.
//
// **`viewModel { CycleDayViewModel(…) }` (`CycleModule.kt:49-56`) has no twin yet**, because
// `CycleDayViewModel` does not exist yet — iOS-M6 Task 11 builds it, together with the real
// `CycleDayRoute`. Its factory is added here in the same slice; until then this module exposes one
// ViewModel factory rather than two, and `SaveCycleDayUseCase` stays unwired. Recorded so the gap
// reads as scheduled rather than dropped.

import SalusCommon
import SalusDatabase
import SalusNavigation
import SalusReminder
import SalusSettings
import SwiftUI

/// Everything this feature's views need, built by the composition root (`CycleModule.kt:25-57`).
///
/// `@MainActor` because every ViewModel it makes is: the factories are called from a view's
/// `.task`, which already runs there.
@MainActor
public struct CycleModule {
    /// Koin's `single<CycleRepository>` (`CycleModule.kt:26`). Exposed so a feature that needs a
    /// period — the AI summary, a future home card — reads the same instance rather than opening a
    /// second one over the same DAO.
    public let repository: any CycleRepository

    /// Publishes what the Routes and ViewModels ask for; the shell applies it.
    public let navigator: Navigator

    /// Koin's `single { CycleReminderHandler(…) } bind ReminderHandler::class`
    /// (`CycleModule.kt:37-45`). Exposed as the protocol because its one consumer is the
    /// composition root's `ReminderHandlerRegistry`, which names no feature type.
    ///
    /// It is built here rather than by the app so the handler, the repository it reads and the
    /// settings it honours are the same object graph: a handler over a second repository would
    /// answer the engine from a different in-memory view of the same tables.
    public let reminderHandler: any ReminderHandler

    /// Koin's `viewModelOf(::CycleViewModel)` (`CycleModule.kt:47`).
    public let makeCycleViewModel: @MainActor () -> CycleViewModel
}

/// Builds the feature's graph — the twin of `val cycleModule = module { … }`.
///
/// Every dependency is passed in and none is reached for, so a second graph (a test, a preview) is
/// a second call rather than a mutated global. The six parameters are the six things Koin resolves
/// inside `cycleModule` — `get()` and `androidContext()` read exactly this list.
@MainActor
public func makeCycleModule(
    cycleDao: CycleDao,
    preferences: SalusPreferencesDataSource,
    reminderScheduler: any ReminderScheduler,
    clock: any SalusClock,
    idGenerator: any IdGenerator,
    navigator: Navigator
) -> CycleModule {
    // `CycleModule.kt:26` — the profile id Koin passes, spelled out rather than left to the
    // repository's default so the one construction site says which profile it opened.
    let repository = CycleRepositoryImpl(cycleDao: cycleDao, profileId: SalusDatabase.defaultProfileId)
    // `CycleModule.kt:33` — one instance for the whole feature, for the reason on `reminderHandler`.
    let reminderSettings = CycleReminderSettingsImpl(dataSource: preferences)
    let predictor = CyclePredictor()

    return CycleModule(
        repository: repository,
        navigator: navigator,
        // `CycleModule.kt:37-45`.
        reminderHandler: CycleReminderHandler(
            repository: repository,
            predictor: predictor,
            settings: reminderSettings,
            clock: clock,
            texts: LocalizedCycleNotificationTexts()
        ),
        makeCycleViewModel: {
            CycleViewModel(
                repository: repository,
                predictor: predictor,
                // `factoryOf(::StartPeriodUseCase)` / `factoryOf(::EndPeriodUseCase)`
                // (`CycleModule.kt:29-30`): a fresh one per ViewModel, exactly as `factory` does.
                startPeriod: StartPeriodUseCase(repository: repository, idGenerator: idGenerator),
                endPeriod: EndPeriodUseCase(repository: repository),
                clock: clock,
                reminderSettings: reminderSettings,
                reminderScheduler: reminderScheduler
            )
        }
    )
}

extension EnvironmentValues {
    /// How the module reaches this feature's Routes.
    ///
    /// The Route cannot read `AppCompositionRoot` itself — that type lives in the app target, which
    /// a package cannot import — so the shell injects the finished module instead:
    ///
    /// ```swift
    /// NavigationStack(path: backStacks.binding(for: .more)) {
    ///     PlaceholderScreen(...)
    ///         .cycleDestinations()
    /// }
    /// .environment(\.cycleModule, root.cycleModule)
    /// ```
    ///
    /// Optional because an `@Entry` needs a default and there is no honest one: a module built from
    /// nothing would be a second, silent object graph. A Route that finds nil draws its spinner,
    /// which is what a dropped injection should look like — nothing pretends to work.
    @Entry public var cycleModule: CycleModule?
}
