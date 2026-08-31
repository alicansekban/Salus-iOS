// Ported 1:1 from Android
// `feature/aihealth/src/main/kotlin/com/alicansekban/salus/feature/aihealth/ui/
// AiSummaryViewModel.kt`.

import Observation
import SalusAI
import SalusCommon
import SalusPremium

/// Drives the AI health summary screen.
///
/// It owns no rule about what a summary costs — every gate (cache, enough data, entitlement,
/// daily quota) lives in `AiSummaryRepository`, and this class only turns the one outcome it
/// gets back into a screen. That is why hitting the premium wall does **not** open the paywall:
/// the wall is a state the user can look at, and only the button on it asks for the sheet.
@MainActor
@Observable
public final class AiSummaryViewModel {
    /// The screen's state, read directly by the view — the twin of Android's `StateFlow`.
    public private(set) var state: AiSummaryUiState

    private let repository: any AiSummaryRepository
    private let paywallController: PaywallController
    private let languageProvider: any AiLanguageProvider
    private let clock: any SalusClock

    /// Held so a period switch cancels the request it replaces and can never overwrite it late.
    ///
    /// A `CancellationBox` rather than a stored `Task`: Swift 6.0 has no isolated `deinit`, so a
    /// `@MainActor` class cannot read its own stored properties from `deinit`. The box is
    /// `@unchecked Sendable` and cancellable from anywhere, which is what lets `deinit` cancel the
    /// observation without touching main-actor state (`SalusCommon`'s `CancellationBox`).
    private let loadBox = CancellationBox()

    /// The entitlement observation, held so `deinit` can cancel it — same reason as `loadBox`.
    private let entitlementBox = CancellationBox()

    public init(
        repository: any AiSummaryRepository,
        premiumRepository: any PremiumRepository,
        paywallController: PaywallController,
        languageProvider: any AiLanguageProvider,
        clock: any SalusClock
    ) {
        self.repository = repository
        self.paywallController = paywallController
        self.languageProvider = languageProvider
        self.clock = clock
        state = AiSummaryUiState()

        load(state.period)
        observeEntitlement(premiumRepository)
    }

    deinit {
        loadBox.cancel()
        entitlementBox.cancel()
    }

    public func onEvent(_ event: AiSummaryEvent) {
        switch event {
        case let .periodSelected(period):
            if period != state.period {
                load(period)
            }

        case .retryClicked:
            load(state.period)

        case .upgradeClicked:
            paywallController.show(.aiSummary)
        }
    }

    /// Re-requests the summary the moment the user becomes entitled while the wall is showing.
    ///
    /// The purchase finishes in the paywall overlay, which leaves this screen underneath still
    /// displaying `AiSummaryResult.premiumRequired` — without this the user would pay and then
    /// have to tap something to see what they bought. Every other state is left alone: an
    /// entitlement arriving while a summary is already on screen changes nothing about it.
    private func observeEntitlement(_ premiumRepository: any PremiumRepository) {
        entitlementBox.replace(with: Task { [weak self] in
            var last: Bool?
            for await status in premiumRepository.status {
                let entitled = status.isEntitled
                // The twin of Kotlin's `map { it.isEntitled }.distinctUntilChanged()`: only a
                // change in the entitlement flips the auto-retry, so a re-emission of the same
                // status does not re-request a summary that is already on screen.
                if entitled != last {
                    last = entitled
                    if entitled, let self, state.result == .premiumRequired {
                        load(state.period)
                    }
                }
            }
        })
    }

    private func load(_ period: SummaryPeriod) {
        // The loading state is set synchronously, exactly as Android sets `_state.value` before
        // launching the job: a period switch shows the spinner immediately, not a frame late.
        state = AiSummaryUiState(period: period, result: .loading)
        loadBox.replace(with: Task { [weak self] in
            guard let self else { return }
            // The clock is the ViewModel's, never the screen's: the day the quota is counted
            // against has to be the one the rest of the app calls today.
            let outcome = await repository.getSummary(
                period: period,
                todayEpochDay: clock.todayEpochDay(),
                language: languageProvider.current()
            )
            guard !Task.isCancelled else { return }
            state = AiSummaryUiState(period: period, result: outcome.toResult())
        })
    }
}

extension SummaryOutcome {
    fileprivate func toResult() -> AiSummaryResult {
        switch self {
        case let .ready(summary, fromCache):
            .content(text: summary.text, fromCache: fromCache)
        case .needsMoreData:
            .insufficientData
        case .needsPremium:
            .premiumRequired
        case .dailyLimitReached:
            .dailyLimit
        case let .failed(reason):
            .error(reason: reason)
        }
    }
}
