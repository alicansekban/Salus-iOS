// Ported from `feature/home/src/main/kotlin/com/alicansekban/salus/feature/home/di/HomeModule.kt`.
//
// Koin's `module { … }` is a description the container resolves at each call site; there is no
// container here (`CLAUDE.md`: "the composition root owns the singletons"), so the module is a value
// the composition root builds once and hands down. The two Koin declarations map exactly:
//
//   `single<TodayRepository> { TodayRepositoryImpl(…) }` → built once by `makeHomeModule` and closed
//                                                          over by the factory below.
//   `viewModelOf(::HomeViewModel)`                       → `makeHomeViewModel`.
//
// **Two of the ViewModel's five dependencies are constructed here rather than resolved**, because
// Android resolves them from modules iOS does not have yet: `AiSummaryRepository` (iOS-M10) and
// `PremiumRepository` (iOS-M9). Their iOS stand-ins are this package's own
// ``AiUsageSummaryAvailability`` — real, over the shipped `AiUsageDataSource` — and
// ``FreeOnlyPremiumStatus``, which answers `false` until the store lands (divergence (d)). Both are
// bound behind the two feature-local protocols, so the milestone that brings the real one changes
// this file and nothing else.
//
// The module exposes **only** the ViewModel factory. `CycleModule` publishes its repository because
// a second feature reads periods through it; nothing reads the dashboard's join but the dashboard,
// so there is nothing else to hand out.

import SalusCommon
import SalusDatabase
import SalusModel
import SalusSettings
import SwiftUI

/// Everything this feature's views need, built by the composition root (`HomeModule.kt:11-23`).
///
/// `@MainActor` because the ViewModel it makes is: the factory is called from a view's `.task`,
/// which already runs there.
@MainActor
public struct HomeModule {
    /// Koin's `viewModelOf(::HomeViewModel)` (`HomeModule.kt:22`).
    public let makeHomeViewModel: @MainActor () -> HomeViewModel
}

// The nine parameters are the eight things Koin resolves inside `homeModule` (`HomeModule.kt:12-21`,
// where `get()` reads the six `TodayRepositoryImpl` takes plus the `DoseActions` and the clock
// `viewModelOf(::HomeViewModel)` resolves) plus the profile id, which Koin passes as a literal.
// Bundling them into a "dependencies" struct would be a second shape for the composition root's own
// properties. The rule is waived here rather than the signature bent, exactly as
// `makeVitalsModule` and `makeAppointmentsModule` waive it.
// swiftlint:disable function_parameter_count

/// Builds the feature's graph — the twin of `val homeModule = module { … }`.
///
/// Every dependency is passed in and none is reached for, so a second graph (a test, a preview) is a
/// second call rather than a mutated global.
@MainActor
public func makeHomeModule(
    medicationDao: MedicationDao,
    appointmentDao: AppointmentDao,
    cycleDao: CycleDao,
    vitalsDao: VitalsDao,
    preferences: SalusPreferencesDataSource,
    aiUsage: AiUsageDataSource,
    clock: any SalusClock,
    doseActions: any DoseActions,
    profileId: String = SalusDatabase.defaultProfileId
) -> HomeModule {
    // `HomeModule.kt:12-21` — the profile id Koin passes, spelled out rather than left to the
    // repository's default so the one construction site says which profile it opened.
    let repository = TodayRepositoryImpl(
        medicationDao: medicationDao,
        appointmentDao: appointmentDao,
        cycleDao: cycleDao,
        vitalsDao: vitalsDao,
        preferences: preferences,
        clock: clock,
        profileId: profileId
    )
    let aiSummaryAvailability = AiUsageSummaryAvailability(aiUsage: aiUsage)
    let premiumStatus = FreeOnlyPremiumStatus()

    return HomeModule(
        makeHomeViewModel: {
            HomeViewModel(
                repository: repository,
                aiSummaryAvailability: aiSummaryAvailability,
                premiumStatus: premiumStatus,
                clock: clock,
                doseActions: doseActions
            )
        }
    )
}

// swiftlint:enable function_parameter_count

extension EnvironmentValues {
    /// How the module reaches this feature's Route.
    ///
    /// The Route cannot read `AppCompositionRoot` itself — that type lives in the app target, which a
    /// package cannot import — so the shell injects the finished module instead. Optional because an
    /// `@Entry` needs a default and there is no honest one: a module built from nothing would be a
    /// second, silent object graph. A Route that finds nil draws its spinner, which is what a dropped
    /// injection should look like — nothing pretends to work. `CycleModule`'s note, in full.
    @Entry public var homeModule: HomeModule?
}
