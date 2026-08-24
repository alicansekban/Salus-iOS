// Ported from `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/
// di/SettingsModule.kt`.
//
// Koin's `module { }` is a description a container resolves per call site. There is no container
// (`CLAUDE.md`: "the composition root owns the singletons"), so the module is a value the
// composition root builds once and hands down. One Koin scope maps so far:
//
//   `viewModelOf(::ReminderHealthViewModel)` → `makeReminderHealthViewModel`, a closure, so each
//                                              Route gets a fresh one exactly as `viewModel` does.
//
// TODO(M8): the settings hub's own ViewModel and the preferences it reads.

import SalusCommon
import SalusReminder
import SwiftUI

/// Everything this feature's views need, built by the composition root.
///
/// `@MainActor` because every ViewModel it makes is: the factories are called from a view's
/// `.task`, which already runs there.
@MainActor
public struct SettingsModule {
    public let makeReminderHealthViewModel: @MainActor () -> ReminderHealthViewModel
}

/// Builds the feature's graph — the twin of `val settingsModule = module { … }`.
///
/// Every dependency is passed in and none is reached for, so a second graph (a test, a preview) is
/// a second call rather than a mutated global.
///
/// - Parameter alarmKitSupported: whether this OS has AlarmKit. The composition root already
///   decides that once, behind the single `#available(iOS 26.1, *)` in the app
///   (`AppCompositionRoot.makeAlarmKitBackend`), and passes the answer on rather than letting a
///   second `#available` appear down here.
@MainActor
public func makeSettingsModule(
    reminderEnvironment: any ReminderEnvironment,
    reminderAuthorization: any ReminderAuthorizationRequesting,
    reminderSyncState: any ReminderSyncStateStore,
    clock: any SalusClock,
    alarmKitSupported: Bool
) -> SettingsModule {
    SettingsModule(
        makeReminderHealthViewModel: {
            ReminderHealthViewModel(
                environment: reminderEnvironment,
                authorization: reminderAuthorization,
                syncState: reminderSyncState,
                clock: clock,
                alarmKitSupported: alarmKitSupported
            )
        }
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
