// Ported from `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/
// di/SettingsModule.kt`.
//
// Koin's `module { }` is a description a container resolves per call site. There is no container
// (`CLAUDE.md`: "the composition root owns the singletons"), so the module is a value the
// composition root builds once and hands down. One Koin scope maps so far:
//
//   `viewModelOf(::ReminderHealthViewModel)` → `makeReminderHealthViewModel`, a closure, so each
//                                              Route gets a fresh one exactly as `viewModel` does.
//   `viewModelOf(::ProfileViewModel)`        → `makeProfileViewModel`, the same shape.
//   `viewModelOf(::MoreViewModel)`           → `makeMoreViewModel`, the same shape (iOS-M8 T6).
//
// The `navigator` is exposed alongside the factories because `MoreRoute`'s same-feature pushes
// (`ReminderHealthKey`/`AboutKey`/`ProfileKey`) go through it the way Kotlin's `MoreRoute` reaches
// `koinInject<Navigator>()` (`MoreScreen.kt:139-141`). The shell still owns the stack; the feature
// only asks it to push.

import SalusCommon
import SalusNavigation
import SalusProfile
import SalusReminder
import SalusSettings
import SwiftUI

/// Everything this feature's views need, built by the composition root.
///
/// `@MainActor` because every ViewModel it makes is: the factories are called from a view's
/// `.task`, which already runs there.
@MainActor
public struct SettingsModule {
    public let makeReminderHealthViewModel: @MainActor () -> ReminderHealthViewModel
    public let makeProfileViewModel: @MainActor () -> ProfileViewModel
    /// `viewModelOf(::MoreViewModel)` — the More hub's ViewModel, a closure so each `MoreRoute`
    /// gets a fresh one exactly as `viewModel` does.
    public let makeMoreViewModel: @MainActor () -> MoreViewModel
    /// The shell's `Navigator`, exposed so the More hub's rows can push the three same-feature
    /// destinations (`MoreScreen.kt:139-141`). Read-only; the shell is still the only stack mutator.
    public let navigator: Navigator
}

/// Builds the feature's graph — the twin of `val settingsModule = module { … }`.
///
/// Every dependency is passed in and none is reached for, so a second graph (a test, a preview) is
/// a second call rather than a mutated global.
///
/// - Parameter alarmKitSupported: whether this OS has AlarmKit. The composition root already
///   decides that once, behind the single `#available(iOS 26.0, *)` in the app
///   (`AppCompositionRoot.makeAlarmKitBackend`), and passes the answer on rather than letting a
///   second `#available` appear down here.
///
/// The parameter list is the dependency list — the shape Koin's `module { }` block has — so the
/// `function_parameter_count` warning is answered with a disable rather than by bundling
/// dependencies into a struct that would exist only to satisfy a count. The same targeted-disable
/// precedent `MoreViewModel.onEvent` sets for `cyclomatic_complexity`. T6 grows the list from 7 to
/// 11 (the four More-specific deps); the disable stays.
@MainActor
// swiftlint:disable:next function_parameter_count
public func makeSettingsModule(
    reminderEnvironment: any ReminderEnvironment,
    reminderAuthorization: any ReminderAuthorizationRequesting,
    reminderSyncState: any ReminderSyncStateStore,
    clock: any SalusClock,
    alarmKitSupported: Bool,
    profileRepository: any ProfileRepository,
    navigator: Navigator,
    preferencesDataSource: SalusPreferencesDataSource,
    localeController: any AppLocaleController,
    premiumStatus: any MorePremiumStatus,
    paywallRequester: any PaywallRequester
) -> SettingsModule {
    // The More-specific deps are built inside the factory from the passed data source, because the
    // implementations (`SettingsPreferencesImpl`, `FreeOnlyMorePremiumStatus`) are `internal` to this
    // package — the app target cannot construct them. The composition root passes the
    // `SalusPreferencesDataSource` it already owns; the `UserDefaultsAppLocaleController` is built
    // here from `.standard` because it is the same `internal` access story, and the
    // `FreeOnlyMorePremiumStatus` is built here for the same reason (ruling 5 — M8 has no store).
    let morePreferences = SettingsPreferencesImpl(dataSource: preferencesDataSource)
    let moreLocaleController = localeController
    let morePremiumStatus = premiumStatus
    let morePaywallRequester = paywallRequester
    return SettingsModule(
        makeReminderHealthViewModel: {
            ReminderHealthViewModel(
                environment: reminderEnvironment,
                authorization: reminderAuthorization,
                syncState: reminderSyncState,
                clock: clock,
                alarmKitSupported: alarmKitSupported
            )
        },
        makeProfileViewModel: {
            ProfileViewModel(profileRepository: profileRepository, navigator: navigator)
        },
        makeMoreViewModel: {
            MoreViewModel(
                profileRepository: profileRepository,
                premiumStatus: morePremiumStatus,
                preferences: morePreferences,
                localeController: moreLocaleController,
                paywallRequester: morePaywallRequester
            )
        },
        navigator: navigator
    )
}

extension EnvironmentValues {
    /// How the module reaches this feature's Routes.
    ///
    /// The Route cannot read `AppCompositionRoot` itself — that type lives in the app target, which
    /// a package cannot import — so the shell injects the finished module instead, on the tab's
    /// `NavigationStack` rather than inside its root view (or a pushed destination would not see
    /// it).
    ///
    /// Optional because an `@Entry` needs a default and there is no honest one: a module built from
    /// nothing would be a second, silent object graph. A Route that finds nil draws its spinner,
    /// which is what a dropped injection should look like — nothing pretends to work.
    @Entry public var settingsModule: SettingsModule?
}
