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
//
// The doctor-report registrations (`PdfReportGenerator`, `DoctorReportRepository`,
// `viewModelOf(::DoctorReportViewModel)`) are absent, and that is the milestone split: they belong
// to Task 6 of iOS-M10, which ships the report screen.

import SalusAI
import SalusCommon
import SalusPremium
import SwiftUI

/// Everything this feature's views need, built by the composition root (`AiHealthModule.kt:22-33`).
///
/// `@MainActor` because the ViewModel it makes is: the factory is called from a view's `.task`,
/// which already runs there.
@MainActor
public struct AiHealthModule {
    /// Koin's `viewModelOf(::AiSummaryViewModel)` (`AiHealthModule.kt:32`).
    public let makeAiSummaryViewModel: @MainActor () -> AiSummaryViewModel
}

/// Builds the feature's graph — the twin of `val aiHealthModule = module { … }`.
///
/// Every dependency is passed in and none is reached for, so a second graph (a test, a preview) is
/// a second call rather than a mutated global.
@MainActor
public func makeAiHealthModule(
    summaryRepository: any AiSummaryRepository,
    premiumRepository: any PremiumRepository,
    paywallController: PaywallController,
    languageProvider: any AiLanguageProvider,
    clock: any SalusClock
) -> AiHealthModule {
    AiHealthModule(
        makeAiSummaryViewModel: {
            AiSummaryViewModel(
                repository: summaryRepository,
                premiumRepository: premiumRepository,
                paywallController: paywallController,
                languageProvider: languageProvider,
                clock: clock
            )
        }
    )
}

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
