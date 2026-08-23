// Ported from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// di/VitalsModule.kt`.
//
// Koin's `module { … }` is a description the container resolves at each call site; there is no
// container here (`CLAUDE.md`: "the composition root owns the singletons"), so the module is a
// value the composition root builds once and hands down. The three Koin scopes map exactly:
//
//   `single<VitalsRepository> { … }`  → the `repository` property, built once by `makeVitalsModule`.
//   `factoryOf(::SaveWeightEntryUseCase)` → `makeSaveWeightEntryUseCase`, a closure, so every call
//                                           gets a fresh one exactly as `factory` does.
//   `viewModel { parameters -> … }`   → `makeWeightEditorViewModel(_:)`, whose `String?` argument
//                                       is Koin's `parameters.getOrNull()`.
//
// `bind VitalsQuickEntry::class` (`VitalsModule.kt:26`) has no separate member: the use case
// already conforms to `SalusModel.VitalsQuickEntry`, and the feature that needs a quick entry gets
// it from `makeSaveWeightEntryUseCase()` rather than from a second registration.
//
// TODO(M7): `VitalsPreferences`, the two other use cases and the two other editor ViewModels
// (`VitalsModule.kt:24, 27-28, 43-64`).

import SalusCommon
import SalusDatabase
import SalusNavigation
import SalusUI
import SwiftUI

/// Everything this feature's views need, built by the composition root (`VitalsModule.kt:22-65`).
///
/// `@MainActor` because every ViewModel it makes is: the factories are called from a view's
/// `.task`, which already runs there.
@MainActor
public struct VitalsModule {
    /// Koin's `single<VitalsRepository>` (`VitalsModule.kt:23`). Exposed so a feature that needs a
    /// weight reading — the AI summary, the home sparkline — reads the same instance rather than
    /// opening a second one over the same DAO.
    public let repository: any VitalsRepository

    /// Publishes what the Routes and ViewModels ask for; the shell applies it.
    public let navigator: Navigator

    /// Koin's `factoryOf(::SaveWeightEntryUseCase)` (`VitalsModule.kt:26`), which also satisfies
    /// `VitalsQuickEntry`.
    public let makeSaveWeightEntryUseCase: @MainActor () -> SaveWeightEntryUseCase

    /// Koin's `viewModelOf(::VitalsViewModel)` (`VitalsModule.kt:30`).
    public let makeVitalsViewModel: @MainActor () -> VitalsViewModel

    /// Koin's parameterised `viewModel { … }` (`VitalsModule.kt:32-41`); the argument is the id of
    /// the entry being edited, or nil for a new one.
    public let makeWeightEditorViewModel: @MainActor (String?) -> WeightEditorViewModel
}

/// Builds the feature's graph — the twin of `val vitalsModule = module { … }`.
///
/// Every dependency is passed in and none is reached for, so a second graph (a test, a preview) is
/// a second call rather than a mutated global.
@MainActor
public func makeVitalsModule(
    vitalsDao: VitalsDao,
    clock: any SalusClock,
    idGenerator: any IdGenerator,
    pendingDeletes: PendingDeleteController,
    snackbar: SalusSnackbarController,
    navigator: Navigator
) -> VitalsModule {
    // `VitalsModule.kt:23` — the profile id is `VitalsRepositoryImpl`'s documented default.
    let repository = VitalsRepositoryImpl(vitalsDao: vitalsDao)
    let undoableDelete = UndoableDelete(pendingDeletes: pendingDeletes, snackbar: snackbar)
    let makeSaveWeightEntryUseCase: @MainActor () -> SaveWeightEntryUseCase = {
        SaveWeightEntryUseCase(repository: repository, idGenerator: idGenerator)
    }

    return VitalsModule(
        repository: repository,
        navigator: navigator,
        makeSaveWeightEntryUseCase: makeSaveWeightEntryUseCase,
        makeVitalsViewModel: {
            VitalsViewModel(
                repository: repository,
                pendingDeletes: pendingDeletes,
                undoableDelete: undoableDelete,
                clock: clock
            )
        },
        makeWeightEditorViewModel: { entryId in
            WeightEditorViewModel(
                entryId: entryId,
                repository: repository,
                saveWeightEntry: makeSaveWeightEntryUseCase(),
                clock: clock,
                navigator: navigator,
                undoableDelete: undoableDelete
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
    /// NavigationStack(path: backStacks.binding(for: .vitals)) {
    ///     VitalsRoute(onOpenTrends: { … })
    ///         .vitalsDestinations()
    /// }
    /// .environment(\.vitalsModule, root.vitalsModule)
    /// ```
    ///
    /// Optional because an `@Entry` needs a default and there is no honest one: a module built from
    /// nothing would be a second, silent object graph. A Route that finds nil draws its spinner,
    /// which is what a dropped injection should look like — nothing pretends to work.
    @Entry public var vitalsModule: VitalsModule?
}
