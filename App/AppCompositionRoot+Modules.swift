import FeatureAppointments
import FeatureCycle
import FeatureHome
import FeatureMedications
import FeatureOnboarding
import FeatureSettings
import FeatureVitals
import SalusCommon
import SalusDatabase
import SalusNavigation
import SalusProfile
import SalusSettings
import SalusUI

/// The module bundles `AppCompositionRoot`'s builders hand back, and the one module builder that no
/// longer fits beside them.
///
/// Split out of `AppCompositionRoot.swift` for the reason `AppCompositionRoot+Reminder.swift` was:
/// the root file is meant to stay a readable list of `let`s and the builders that fill them, and it
/// sits against the 500-line budget. Nothing here is `public`, so the app's assembly is still
/// invisible outside the app target; the members are `internal` rather than `private` only because
/// `makeFeatureModules` and `makeScheduledModules` live in the other file.
extension AppCompositionRoot {
    /// `homeModule` (`feature/home/.../di/HomeModule.kt:11-23`).
    ///
    /// A builder of its own, called *after* ``makeScheduledModules(infrastructure:reminderScheduler:)``,
    /// because the dashboard is the one module assembled out of another feature's: its "Al" button is
    /// Medications' `MarkDoseTakenUseCase`, taken from the medications module by the
    /// `medications.makeMarkDoseTakenUseCase()` call below — the twin of Koin's
    /// `factoryOf(::MarkDoseTakenUseCase) bind DoseActions::class` (`MedicationsModule.kt:30`), so
    /// every caller gets a fresh use case over the one repository. Reusing that factory is what
    /// keeps the card from opening a second medications graph.
    ///
    /// The four DAOs are opened here exactly as every other module's are — a DAO is a value over the
    /// one `SalusDatabase`, so a second instance is not a second connection — and the profile id is
    /// spelled out rather than left to the default, so the one construction site says which profile
    /// the dashboard reads.
    static func makeHomeGraph(
        infrastructure: Infrastructure,
        medications: MedicationsModule
    ) -> HomeModule {
        let database = infrastructure.database
        return makeHomeModule(
            medicationDao: MedicationDao(database: database),
            appointmentDao: AppointmentDao(database: database),
            cycleDao: CycleDao(database: database),
            vitalsDao: VitalsDao(database: database),
            preferences: infrastructure.preferences,
            aiUsage: infrastructure.aiUsage,
            clock: infrastructure.clock,
            doseActions: medications.makeMarkDoseTakenUseCase(),
            profileId: SalusDatabase.defaultProfileId
        )
    }

    /// `onboardingModule` (`feature/onboarding/.../di/OnboardingModule.kt:10-23`).
    ///
    /// A builder of its own for the reason ``makeHomeGraph(infrastructure:medications:)`` is one:
    /// it is assembled out of another feature's module. The weight step writes through Vitals'
    /// `VitalsQuickEntry` — Koin's `single<VitalsQuickEntry>` (`VitalsModule.kt:26`), which the
    /// root already exposes "for onboarding's current weight step" and which ruling 7 names as
    /// `finish()`'s second write. Taking it from the vitals module rather than building a second
    /// save-weight use case is what keeps the flow writing into the same repository the vitals tab
    /// reads.
    ///
    /// `OnboardingPreferences` is **not** passed: `makeOnboardingModule` builds
    /// `OnboardingPreferencesImpl` over the one `SalusPreferencesDataSource` inside the package,
    /// exactly as `makeSettingsModule` does with `SettingsPreferencesImpl`. That store is the one
    /// `RootView`'s `userSettings` loop watches, which is the whole of the gate's dismissal.
    static func makeOnboardingGraph(
        infrastructure: Infrastructure,
        vitals: VitalsModule
    ) -> OnboardingModule {
        makeOnboardingModule(
            profileRepository: infrastructure.profileRepository,
            vitalsQuickEntry: vitals.makeSaveWeightEntryUseCase(),
            preferencesDataSource: infrastructure.preferences,
            clock: infrastructure.clock
        )
    }

    /// `get<SalusPreferencesDataSource>().userSettings.map { it.appLockEnabled }.distinctUntilChanged()`
    /// (`AppModules.kt:45-52`) — Koin's one-line flow, spelled as the `AsyncStream<Bool>`
    /// `AppLockManager.init` takes.
    ///
    /// Hand-written rather than `AsyncMapSequence` plus a de-duplicating wrapper for two reasons:
    /// the manager's parameter is the concrete `AsyncStream`, not `some AsyncSequence`, and
    /// `distinctUntilChanged` has no Swift-concurrency equivalent to reach for — the two-line fold
    /// below *is* the operator. `previous` starts `nil` so the very first value is always yielded,
    /// which is what makes this a cold flow that replays: the manager's `hasReadSetting` depends on
    /// getting one emission per subscription, not one per change.
    ///
    /// The task is cancelled on termination, so a dropped manager (a second graph in a preview,
    /// say) stops observing rather than leaking a subscription to `UserDefaults`.
    static func appLockEnabledStream(of preferences: SalusPreferencesDataSource) -> AsyncStream<Bool> {
        let settings = preferences.userSettings
        return AsyncStream { continuation in
            let task = Task {
                var previous: Bool?
                for await value in settings {
                    guard value.appLockEnabled != previous else { continue }
                    previous = value.appLockEnabled
                    continuation.yield(value.appLockEnabled)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// The process-lifetime singletons, handed back from `makeInfrastructure` in one piece.
///
/// `internal` rather than `private` because ``AppCompositionRoot/makeHomeGraph(infrastructure:medications:)``
/// and ``AppCompositionRoot/makeOnboardingGraph(infrastructure:vitals:)`` live here and take it.
/// Moved out of `AppCompositionRoot.swift` in iOS-M8 T11, so all three of the graph's bundle types
/// sit together and the root file stays inside its 500-line budget.
struct Infrastructure {
    let clock: any SalusClock
    let idGenerator: any IdGenerator
    let database: SalusDatabase
    let profileDao: ProfileDao
    let appLockFlagStore: any AppLockFlagStore
    let preferences: SalusPreferencesDataSource
    let aiUsage: AiUsageDataSource
    let profileRepository: any ProfileRepository
    let pendingDelete: PendingDeleteController
    let appLockManager: AppLockManager
    let navigator: Navigator
    let snackbar: SalusSnackbarController
}

/// The modules that own a reminder handler, handed back from `makeScheduledModules` in one piece.
/// A milestone that gives a fourth feature a reminder adds one field here.
struct ScheduledModules {
    let appointments: AppointmentsModule
    let medications: MedicationsModule
    let cycle: CycleModule
}

/// The feature modules, handed back from `makeFeatureModules` in one piece with the reminder
/// sub-graph they were wired against. A milestone that adds a feature adds one field here.
struct FeatureModules {
    let reminder: ReminderGraph
    let vitals: VitalsModule
    let appointments: AppointmentsModule
    let medications: MedicationsModule
    let cycle: CycleModule
    let settings: SettingsModule
    let home: HomeModule
    let onboarding: OnboardingModule
}
