// Ported from `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/
// di/TrendsModule.kt`.
//
// Koin's `module { … }` is a description the container resolves at each call site; there is no
// container here (`CLAUDE.md`: "the composition root owns the singletons"), so the module is a
// value the composition root builds once and hands down. The Koin declarations map exactly:
//
//   `single<TrendsReader> { TrendsDataReader(get(), get(), DEFAULT_PROFILE_ID) }` → built by the
//       composition root and passed into `makeTrendsModule` as `reader`.
//   `single<TrendsRepository> { TrendsRepositoryImpl(get(), get(), get()) }` → built by the
//       composition root and passed in as `repository`.
//   `single<TrendsPreferences> { TrendsPreferencesImpl(get()) }` → built here from the
//       `SalusPreferencesDataSource` the composition root passes in, exactly as `makeVitalsModule`
//       builds `VitalsPreferencesImpl` from the same store.
//   `viewModelOf(::TrendsViewModel)` → `makeTrendsViewModel`.

import SalusCommon
import SalusPremium
import SalusSettings
import SwiftUI

/// Everything this feature's views need, built by the composition root (`TrendsModule.kt:22-37`).
///
/// `@MainActor` because the ViewModel it makes is: the factory is called from a view's `.task`,
/// which already runs there.
@MainActor
public struct TrendsModule {
    /// Koin's `single<TrendsRepository>` (`TrendsModule.kt:27-32`), exposed so the composition root
    /// builds it once. The module does not rebuild it; it hands the same instance to every
    /// ViewModel it makes.
    public let repository: any TrendsRepository

    /// Koin's `viewModelOf(::TrendsViewModel)` (`TrendsModule.kt:37`).
    public let makeTrendsViewModel: @MainActor () -> TrendsViewModel
}

/// Builds the feature's graph — the twin of `val trendsModule = module { … }`.
///
/// Every dependency is passed in and none is reached for, so a second graph (a test, a preview) is
/// a second call rather than a mutated global.
@MainActor
public func makeTrendsModule(
    repository: any TrendsRepository,
    paywallController: PaywallController,
    premiumRepository: any PremiumRepository,
    preferences: SalusPreferencesDataSource
) -> TrendsModule {
    let trendsPreferences = TrendsPreferencesImpl(dataSource: preferences)
    return TrendsModule(
        repository: repository,
        makeTrendsViewModel: {
            TrendsViewModel(
                repository: repository,
                paywallController: paywallController,
                premiumRepository: premiumRepository,
                preferences: trendsPreferences
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
    /// NavigationStack(path: backStacks.binding(for: tab)) {
    ///     VitalsRoute(onOpenTrends: { … })
    ///         .vitalsDestinations()
    ///         .trendsDestinations()
    /// }
    /// .environment(\.trendsModule, root.trendsModule)
    /// ```
    ///
    /// Optional because an `@Entry` needs a default and there is no honest one: a module built from
    /// nothing would be a second, silent object graph. A Route that finds nil draws its spinner,
    /// which is what a dropped injection should look like — nothing pretends to work.
    @Entry public var trendsModule: TrendsModule?
}
