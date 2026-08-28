// Ported from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// di/MedicationsModule.kt`.
//
// Koin's `module { … }` is a description the container resolves at each call site; there is no
// container here (`CLAUDE.md`: "the composition root owns the singletons"), so the module is a
// value the composition root builds once and hands down. The Koin scopes map exactly:
//
//   `single<MedicationRepository> { … }`      → the `repository` property, built once by
//                                               `makeMedicationsModule`.
//   `factoryOf(::MarkDoseTakenUseCase)`       → `makeMarkDoseTakenUseCase`, a closure, so every
//     `bind DoseActions::class`                 call gets a fresh one exactly as `factory` does.
//                                               The `bind` needs no twin: the type already
//                                               conforms to `SalusModel.DoseActions`, so the
//                                               composition root exposes it as that protocol over
//                                               the same factory.
//   `viewModelOf(::MedicationsViewModel)`     → `makeMedicationsViewModel`.
//   `viewModel { params -> MedicationDetail…}`→ `makeMedicationDetailViewModel`, a closure over the
//                                               one thing Koin passes as a parameter rather than
//                                               resolving: the medication id.
//   `single { MedicationReminderHandler(…) }` → built inline below and handed straight out; the
//     `bind ReminderHandler::class`             engine's registry is its only consumer.
//
//   `viewModel { MedicationEditorViewModel(…) }` → `makeMedicationEditorViewModel`, a closure over the
//                                               medication being edited, or nil for a new one;
//                                               `factoryOf(::SaveMedicationUseCase)` is built inside
//                                               it — the editor is its only consumer.
//
// `DeleteMedicationUseCase` and `SnoozeDoseUseCase` are built here already —
// Koin declares them as factories, but their only consumers so far are inside this file, so they
// stay local rather than becoming exported closures nothing calls.

import SalusCommon
import SalusDatabase
import SalusNavigation
import SalusReminder
import SalusUI
import SwiftUI

/// Everything this feature's views need, built by the composition root
/// (`MedicationsModule.kt:23-62`).
///
/// `@MainActor` because every ViewModel it makes is: the factories are called from a view's
/// `.task`, which already runs there.
@MainActor
public struct MedicationsModule {
    /// Koin's `single<MedicationRepository>` (`MedicationsModule.kt:23-25`). Exposed so a feature
    /// that needs a medication — Home's dose list, the AI summary — reads the same instance rather
    /// than opening a second one over the same DAO.
    public let repository: any MedicationRepository

    /// Publishes what the Routes and ViewModels ask for; the shell applies it.
    public let navigator: Navigator

    /// Koin's `single { MedicationReminderHandler(…) } bind ReminderHandler::class`
    /// (`MedicationsModule.kt:34-37`). Exposed as the protocol because its one consumer is the
    /// composition root's `ReminderHandlerRegistry`, which names no feature type.
    ///
    /// It is built here rather than by the app so the handler and the repository it reads are the
    /// same object graph: a handler over a second repository would answer the engine from a
    /// different in-memory view of the same table.
    public let reminderHandler: any ReminderHandler

    /// Koin's `factoryOf(::MarkDoseTakenUseCase) bind DoseActions::class`
    /// (`MedicationsModule.kt:30`). The one write path other features reach, and the reason it is
    /// exported: Home marks a dose taken without importing this feature.
    public let makeMarkDoseTakenUseCase: @MainActor () -> MarkDoseTakenUseCase

    /// Koin's `viewModelOf(::MedicationsViewModel)` (`MedicationsModule.kt:39`).
    public let makeMedicationsViewModel: @MainActor () -> MedicationsViewModel

    /// Koin's `viewModel { params -> MedicationDetailViewModel(params.get(), …) }`
    /// (`MedicationsModule.kt:39-49`). The medication id is the one thing Koin takes as a
    /// parameter rather than resolving, so it is the closure's one argument.
    public let makeMedicationDetailViewModel: @MainActor (String) -> MedicationDetailViewModel

    /// Koin's `viewModel { MedicationEditorViewModel(…) }` (`MedicationsModule.kt:47-58`). The
    /// parameter is the medication being edited, or nil for a new one — Koin's
    /// `parametersOf(medicationId)`.
    public let makeMedicationEditorViewModel: @MainActor (String?) -> MedicationEditorViewModel
}

// The seven parameters are the seven things Koin resolves inside `medicationsModule`
// (`MedicationsModule.kt:23-62`) — `get()` reads exactly this list. Bundling them into a
// "dependencies" struct would be a second shape for the composition root's own properties, and
// dropping the ones only the detail and editor factories will need would mean changing this
// signature once per slice. The rule is waived here rather than the signature bent;
// `makeAppointmentsModule` waives it for the same reason.
// swiftlint:disable function_parameter_count

/// Builds the feature's graph — the twin of `val medicationsModule = module { … }`.
///
/// Every dependency is passed in and none is reached for, so a second graph (a test, a preview) is
/// a second call rather than a mutated global.
@MainActor
public func makeMedicationsModule(
    medicationDao: MedicationDao,
    reminderScheduler: any ReminderScheduler,
    clock: any SalusClock,
    idGenerator: any IdGenerator,
    pendingDeletes: PendingDeleteController,
    snackbar: SalusSnackbarController,
    navigator: Navigator
) -> MedicationsModule {
    // `MedicationsModule.kt:23-25` — the profile id is `MedicationsRepositoryImpl`'s documented
    // default, which is the `SalusDatabase.DEFAULT_PROFILE_ID` Koin passes there.
    let repository = MedicationsRepositoryImpl(dao: medicationDao, clock: clock)
    let undoableDelete = UndoableDelete(pendingDeletes: pendingDeletes, snackbar: snackbar)
    // `factoryOf(::MarkDoseTakenUseCase)` (`MedicationsModule.kt:30`), named once so the exported
    // factory and the reminder handler's own use case cannot drift apart. Still a `factory`: every
    // call builds a fresh instance, exactly as Koin does.
    let makeMarkDoseTakenUseCase: @MainActor () -> MarkDoseTakenUseCase = {
        MarkDoseTakenUseCase(repository: repository, clock: clock, idGenerator: idGenerator)
    }
    // `factoryOf(::DeleteMedicationUseCase)` (`MedicationsModule.kt:29`) and
    // `factoryOf(::SnoozeDoseUseCase)` (`:32`). Both are values with no identity, so one instance
    // handed to the two consumers below is what Koin's `factory` amounts to here.
    let deleteMedication = DeleteMedicationUseCase(
        repository: repository,
        reminderScheduler: reminderScheduler
    )
    let snoozeDose = SnoozeDoseUseCase(
        repository: repository,
        clock: clock,
        idGenerator: idGenerator,
        reminderScheduler: reminderScheduler
    )

    return MedicationsModule(
        repository: repository,
        navigator: navigator,
        // `MedicationsModule.kt:34-37`. `LocalizedMedicationNotificationTexts()` reads the feature
        // catalog through `Bundle.module` — the twin of Android handing the handler an
        // `androidContext()` it resolves its strings from.
        reminderHandler: MedicationReminderHandler(
            repository: repository,
            markDoseTaken: makeMarkDoseTakenUseCase(),
            snoozeDose: snoozeDose,
            clock: clock,
            texts: LocalizedMedicationNotificationTexts()
        ),
        makeMarkDoseTakenUseCase: makeMarkDoseTakenUseCase,
        makeMedicationsViewModel: {
            MedicationsViewModel(
                repository: repository,
                pendingDeletes: pendingDeletes,
                deleteMedication: deleteMedication,
                undoableDelete: undoableDelete,
                clock: clock
            )
        },
        makeMedicationDetailViewModel: { medicationId in
            MedicationDetailViewModel(
                medicationId: medicationId,
                repository: repository,
                deleteMedication: deleteMedication,
                navigator: navigator,
                undoableDelete: undoableDelete,
                reminderScheduler: reminderScheduler,
                clock: clock
            )
        },
        // `MedicationsModule.kt:47-58`. `factoryOf(::SaveMedicationUseCase)` (`:28`) is built here
        // rather than exported: the editor is its only consumer, so a second closure nothing else
        // calls would be a name without a reader.
        makeMedicationEditorViewModel: { medicationId in
            MedicationEditorViewModel(
                medicationId: medicationId,
                repository: repository,
                saveMedication: SaveMedicationUseCase(
                    repository: repository,
                    reminderScheduler: reminderScheduler
                ),
                deleteMedication: deleteMedication,
                clock: clock,
                idGenerator: idGenerator,
                navigator: navigator,
                undoableDelete: undoableDelete
            )
        }
    )
}

// swiftlint:enable function_parameter_count

extension EnvironmentValues {
    /// How the module reaches this feature's Routes.
    ///
    /// The Route cannot read `AppCompositionRoot` itself — that type lives in the app target, which
    /// a package cannot import — so the shell injects the finished module instead:
    ///
    /// ```swift
    /// NavigationStack(path: backStacks.binding(for: .medications)) {
    ///     MedicationsRoute()
    ///         .medicationsDestinations()
    /// }
    /// .environment(\.medicationsModule, root.medicationsModule)
    /// ```
    ///
    /// Optional because an `@Entry` needs a default and there is no honest one: a module built from
    /// nothing would be a second, silent object graph. A Route that finds nil draws its spinner,
    /// which is what a dropped injection should look like — nothing pretends to work.
    @Entry public var medicationsModule: MedicationsModule?
}
