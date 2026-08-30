// Ported from `feature/onboarding/src/main/kotlin/com/alicansekban/salus/feature/onboarding/
// di/OnboardingModule.kt`.
//
// Koin's `module { }` is a description a container resolves per call site. There is no container
// (`CLAUDE.md`: "the composition root owns the singletons"), so the module is a value the
// composition root builds once and hands down — the shape `SettingsModule.swift` already has. The
// Kotlin module declares two things and both map:
//
//   `single<OnboardingPreferences> { … }`  → built inside the factory. `OnboardingPreferencesImpl`
//                                            is `public`, but building it here keeps the app target
//                                            from naming a second implementation of a protocol that
//                                            has exactly one, and it is the same shape
//                                            `makeSettingsModule` uses for `SettingsPreferencesImpl`.
//   `viewModel { OnboardingViewModel(…) }` → `makeOnboardingViewModel`, a closure, so each
//                                            `OnboardingRoute` gets a fresh one exactly as
//                                            `viewModel` does.
//
// ONE PARAMETER IS ABSENT, and it is Kotlin's `includeNotificationStep`
// (`OnboardingModule.kt:19-20`): `POST_NOTIFICATIONS` only exists from API 33, so Android decides
// per device whether the step has anything to ask. iOS has no such gate —
// `UNUserNotificationCenter` exists on every supported version — so the ViewModel's parameter keeps
// its `true` default and the composition root never passes it. `OnboardingViewModel.swift:49-53`
// records the same thing from the other side; the parameter survives only so a shortened flow stays
// testable.

import SalusCommon
import SalusModel
import SalusProfile
import SalusSettings
import SwiftUI

/// Everything this feature's views need, built by the composition root.
///
/// `@MainActor` because the ViewModel it makes is: the factory is called from `OnboardingRoute`'s
/// `.task`, which already runs there.
@MainActor
public struct OnboardingModule {
    public let makeOnboardingViewModel: @MainActor () -> OnboardingViewModel
}

/// Builds the feature's graph — the twin of `val onboardingModule = module { … }`.
///
/// Every dependency is passed in and none is reached for, so a second graph (a test, a preview) is a
/// second call rather than a mutated global.
///
/// - Parameter vitalsQuickEntry: the composition root already exposes it "for onboarding's current
///   weight step (M6)"; `OnboardingViewModel.finish()` is the caller that doc names (ruling 7).
/// - Parameter preferencesDataSource: the store `OnboardingPreferencesImpl` writes
///   `onboarding_completed` through — the flag the shell's gate reads.
@MainActor
public func makeOnboardingModule(
    profileRepository: any ProfileRepository,
    vitalsQuickEntry: any VitalsQuickEntry,
    preferencesDataSource: SalusPreferencesDataSource,
    clock: any SalusClock
) -> OnboardingModule {
    let preferences = OnboardingPreferencesImpl(dataSource: preferencesDataSource)
    return OnboardingModule(
        makeOnboardingViewModel: {
            OnboardingViewModel(
                profileRepository: profileRepository,
                vitalsQuickEntry: vitalsQuickEntry,
                preferences: preferences,
                clock: clock
            )
        }
    )
}

extension EnvironmentValues {
    /// How the module reaches `OnboardingRoute`.
    ///
    /// The Route cannot read `AppCompositionRoot` itself — that type lives in the app target, which
    /// a package cannot import — so the shell injects the finished module instead. The onboarding
    /// gate is an overlay above the `TabView` rather than a tab destination (ruling 3), so the
    /// injection goes on whatever the shell wraps that overlay in, not on a `NavigationStack`.
    ///
    /// Optional because an `@Entry` needs a default and there is no honest one: a module built from
    /// nothing would be a second, silent object graph. A Route that finds nil draws its spinner,
    /// which is what a dropped injection should look like — nothing pretends to work.
    @Entry public var onboardingModule: OnboardingModule?
}
