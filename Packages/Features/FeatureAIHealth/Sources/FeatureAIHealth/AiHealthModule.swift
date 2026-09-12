// Ported from `feature/aihealth/src/main/kotlin/com/alicansekban/salus/feature/aihealth/
// di/AiHealthModule.kt`.
//
// Koin's `module { … }` is a description the container resolves at each call site; there is no
// container here (`CLAUDE.md`: "the composition root owns the singletons"), so the module is a
// value the composition root builds once and hands down. The two Koin declarations this task's
// screen needs map exactly:
//
//   `single<AiLanguageProvider> { ResourceAiLanguageProvider(androidContext()) }` → the
//   `languageProvider` property, built by the composition root and passed in — the iOS production
//   implementation reads `Bundle.main.preferredLocalizations` and lives in the app target.
//   `viewModelOf(::AiSummaryViewModel)` → `makeAiSummaryViewModel`.
//   `viewModelOf(::DoctorReportViewModel)` → `makeDoctorReportViewModel` (Task 6 of iOS-M10).
//
// The `navigator` is exposed alongside the factories for the same reason `SettingsModule` exposes
// its own: `AiSummaryRoute`'s same-feature push of `DoctorReportKey` goes through it the way
// Kotlin's `AiSummaryRoute` reaches `koinInject<Navigator>()` (`AiSummaryScreen.kt:44,53`). The
// shell still owns the stack; the feature only asks it to push.

import SalusAI
import SalusCommon
import SalusNavigation
import SalusPremium
import SwiftUI

/// Everything this feature's views need, built by the composition root (`AiHealthModule.kt:22-33`).
///
/// `@MainActor` because the ViewModels it makes are: the factories are called from a view's `.task`,
/// which already runs there.
@MainActor
public struct AiHealthModule {
    /// Koin's `viewModelOf(::AiSummaryViewModel)` (`AiHealthModule.kt:32`).
    public let makeAiSummaryViewModel: @MainActor () -> AiSummaryViewModel

    /// Koin's `viewModelOf(::DoctorReportViewModel)` (`AiHealthModule.kt:41`).
    public let makeDoctorReportViewModel: @MainActor () -> DoctorReportViewModel

    /// The shell's `Navigator`, exposed so the summary's "PDF olarak paylaş" button and the toolbar
    /// share icon can push this feature's `DoctorReportKey` (`AiSummaryScreen.kt:44,53`). Read-only;
    /// the shell is still the only stack mutator.
    public let navigator: Navigator
}

// The factory builds the whole feature's graph; seven dependencies is the shape of that graph,
// not a function that does too much (`AppointmentsModule.swift` counts the same).
// swiftlint:disable function_parameter_count

/// Builds the feature's graph — the twin of `val aiHealthModule = module { … }`.
///
/// Every dependency is passed in and none is reached for, so a second graph (a test, a preview) is
/// a second call rather than a mutated global.
@MainActor
public func makeAiHealthModule(
    summaryRepository: any AiSummaryRepository,
    doctorReportRepository: any DoctorReportRepository,
    premiumRepository: any PremiumRepository,
    paywallController: PaywallController,
    languageProvider: any AiLanguageProvider,
    periodReader: any HealthPeriodReader,
    clock: any SalusClock,
    navigator: Navigator
) -> AiHealthModule {
    AiHealthModule(
        makeAiSummaryViewModel: {
            AiSummaryViewModel(
                repository: summaryRepository,
                premiumRepository: premiumRepository,
                paywallController: paywallController,
                languageProvider: languageProvider,
                periodReader: periodReader,
                clock: clock
            )
        },
        makeDoctorReportViewModel: {
            DoctorReportViewModel(
                repository: doctorReportRepository,
                premiumRepository: premiumRepository,
                paywallController: paywallController,
                languageProvider: languageProvider,
                periodReader: periodReader,
                clock: clock
            )
        },
        navigator: navigator
    )
}
// swiftlint:enable function_parameter_count
extension EnvironmentValues {
    /// How the module reaches this feature's Routes.
    ///
    /// The Route cannot read `AppCompositionRoot` itself — that type lives in the app target, which
    /// a package cannot import — so the shell injects the finished module instead.
    ///
    /// Optional because an `@Entry` needs a default and there is no honest one: a module built from
    /// nothing would be a second, silent object graph. A Route that finds nil draws its spinner,
    /// which is what a dropped injection should look like — nothing pretends to work.
    @Entry public var aiHealthModule: AiHealthModule?
}
