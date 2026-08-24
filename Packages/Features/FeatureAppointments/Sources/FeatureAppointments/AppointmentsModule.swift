// Ported from `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/appointments/
// di/AppointmentsModule.kt`.
//
// Koin's `module { … }` is a description the container resolves at each call site; there is no
// container here (`CLAUDE.md`: "the composition root owns the singletons"), so the module is a
// value the composition root builds once and hands down. The Koin scopes map exactly:
//
//   `single<AppointmentsRepository> { … }`  → the `repository` property, built once by
//                                             `makeAppointmentsModule`.
//   `factoryOf(::SaveAppointmentUseCase)`   → `makeSaveAppointmentUseCase`, a closure, so every
//                                             call gets a fresh one exactly as `factory` does.
//   `viewModelOf(::AppointmentsViewModel)`  → `makeAppointmentsViewModel`.
//
// TODO: `AppointmentNotificationTexts` + `AppointmentReminderHandler`
// (`AppointmentsModule.kt:32-35`) arrive with the app wiring that registers the handler. No
// placeholder member and no `fatalError` stands in for it meanwhile: a member that cannot be
// called is worse than one that is not there, because only the second is visible to the compiler.

import SalusCommon
import SalusDatabase
import SalusNavigation
import SalusProfile
import SalusReminder
import SalusUI
import SwiftUI

/// Everything this feature's views need, built by the composition root
/// (`AppointmentsModule.kt:22-57`).
///
/// `@MainActor` because every ViewModel it makes is: the factories are called from a view's
/// `.task`, which already runs there.
@MainActor
public struct AppointmentsModule {
    /// Koin's `single<AppointmentsRepository>` (`AppointmentsModule.kt:23-30`). Exposed so a
    /// feature that needs an appointment — the home screen's next-up card, the AI summary — reads
    /// the same instance rather than opening a second one over the same DAO.
    public let repository: any AppointmentsRepository

    /// Publishes what the Routes and ViewModels ask for; the shell applies it.
    public let navigator: Navigator

    /// Koin's `factoryOf(::SaveAppointmentUseCase)` (`AppointmentsModule.kt:31`).
    public let makeSaveAppointmentUseCase: @MainActor () -> SaveAppointmentUseCase

    /// Koin's `viewModelOf(::AppointmentsViewModel)` (`AppointmentsModule.kt:37`).
    public let makeAppointmentsViewModel: @MainActor () -> AppointmentsViewModel

    /// Koin's `viewModel { (appointmentId: String) -> … }` (`AppointmentsModule.kt:38-47`). The
    /// `parametersOf(appointmentId)` Koin threads through becomes the closure's one argument.
    public let makeAppointmentDetailViewModel: @MainActor (String) -> AppointmentDetailViewModel

    /// Koin's `viewModel { (appointmentId: String?) -> … }` (`AppointmentsModule.kt:48-56`). The
    /// argument is optional where the detail's is not: `nil` is a new appointment.
    public let makeAppointmentEditorViewModel: @MainActor (String?) -> AppointmentEditorViewModel

    // The graph pieces the detail and editor ViewModels are built from
    // (`AppointmentsModule.kt:38-56`). They are held rather than reached for so those slices add a
    // factory closure and nothing else — `makeAppointmentsModule`'s parameter list is already the
    // full one Koin resolves, and a signature that changes once per slice is a signature every
    // caller has to be revisited for. Not `public`: nothing outside the package builds a ViewModel,
    // and each is already reachable where it is owned (the composition root passed them in).
    let profileRepository: any ProfileRepository
    let clock: any SalusClock
    let idGenerator: any IdGenerator
    let undoableDelete: UndoableDelete
}

// The eight parameters are the eight things Koin resolves inside `appointmentsModule`
// (`AppointmentsModule.kt:22-57`) — `get()` reads exactly this list. Bundling them into a
// "dependencies" struct would be a second shape for the composition root's own properties, and
// dropping the ones only the detail and editor factories need would mean changing this signature
// once per slice. The rule is waived here rather than the signature bent; `SaveAppointmentUseCase`
// waives it for the same reason.
// swiftlint:disable function_parameter_count

/// Builds the feature's graph — the twin of `val appointmentsModule = module { … }`.
///
/// Every dependency is passed in and none is reached for, so a second graph (a test, a preview) is
/// a second call rather than a mutated global.
@MainActor
public func makeAppointmentsModule(
    appointmentDao: AppointmentDao,
    profileRepository: any ProfileRepository,
    reminderScheduler: any ReminderScheduler,
    clock: any SalusClock,
    idGenerator: any IdGenerator,
    pendingDeletes: PendingDeleteController,
    snackbar: SalusSnackbarController,
    navigator: Navigator
) -> AppointmentsModule {
    // `AppointmentsModule.kt:23-30` — the profile id is `AppointmentsRepositoryImpl`'s documented
    // default, which is the `SalusDatabase.DEFAULT_PROFILE_ID` Koin passes there.
    let repository = AppointmentsRepositoryImpl(
        appointmentDao: appointmentDao,
        reminderScheduler: reminderScheduler,
        clock: clock
    )
    let undoableDelete = UndoableDelete(pendingDeletes: pendingDeletes, snackbar: snackbar)

    return AppointmentsModule(
        repository: repository,
        navigator: navigator,
        makeSaveAppointmentUseCase: {
            SaveAppointmentUseCase(repository: repository, idGenerator: idGenerator, clock: clock)
        },
        makeAppointmentsViewModel: {
            AppointmentsViewModel(repository: repository, pendingDeletes: pendingDeletes, clock: clock)
        },
        makeAppointmentDetailViewModel: { appointmentId in
            AppointmentDetailViewModel(
                appointmentId: appointmentId,
                repository: repository,
                profileRepository: profileRepository,
                navigator: navigator,
                undoableDelete: undoableDelete,
                clock: clock
            )
        },
        makeAppointmentEditorViewModel: { appointmentId in
            AppointmentEditorViewModel(
                appointmentId: appointmentId,
                repository: repository,
                saveAppointment: SaveAppointmentUseCase(
                    repository: repository,
                    idGenerator: idGenerator,
                    clock: clock
                ),
                clock: clock,
                navigator: navigator,
                undoableDelete: undoableDelete
            )
        },
        profileRepository: profileRepository,
        clock: clock,
        idGenerator: idGenerator,
        undoableDelete: undoableDelete
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
    /// NavigationStack(path: backStacks.binding(for: .appointments)) {
    ///     AppointmentsRoute()
    ///         .appointmentsDestinations()
    /// }
    /// .environment(\.appointmentsModule, root.appointmentsModule)
    /// ```
    ///
    /// Optional because an `@Entry` needs a default and there is no honest one: a module built from
    /// nothing would be a second, silent object graph. A Route that finds nil draws its spinner,
    /// which is what a dropped injection should look like — nothing pretends to work.
    @Entry public var appointmentsModule: AppointmentsModule?
}
