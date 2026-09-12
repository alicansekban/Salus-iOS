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
    private let periodReader: any HealthPeriodReader
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
        periodReader: any HealthPeriodReader,
        clock: any SalusClock
    ) {
        self.repository = repository
        self.paywallController = paywallController
        self.languageProvider = languageProvider
        self.periodReader = periodReader
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
            let result = outcome.toResult()
            state = await AiSummaryUiState(period: period, result: withMetrics(result, period: period))
        })
    }

    /// The period's headline figures for the tiles above the text.
    ///
    /// Read here rather than taken from the summary, because `AiSummaryRepository` aggregates
    /// privately and answers with prose — the snapshot it built for the prompt never leaves it.
    /// That costs this screen one extra pair of indexed reads per successful load, which is the
    /// price of keeping the repository's contract to the model-facing half of the feature
    /// (`AiSummaryViewModel.kt:110-129`).
    ///
    /// Never fatal: a snapshot that cannot be read costs the user three tiles, and turning a
    /// summary they are already looking at into an error would be the worse trade.
    private func withMetrics(_ result: AiSummaryResult, period: SummaryPeriod) async -> AiSummaryResult {
        guard case let .content(text, fromCache, _) = result else { return result }
        // A `try?` guards the read; a cancellation that lands mid-read simply leaves the tiles
        // off, and the `Task.isCancelled` check the caller runs after this covers a switch that
        // arrived while the aggregate was in flight — the twin of Kotlin rethrowing
        // `CancellationException` out of `runCatching` (`AiSummaryViewModel.kt:125-129`).
        let metrics = try? await periodReader.aggregate(
            period: period,
            todayEpochDay: clock.todayEpochDay(),
            timeZone: clock.timeZone()
        )
        guard !Task.isCancelled else { return result }
        return .content(text: text, fromCache: fromCache, metrics: metrics.flatMap(AiSummaryMetrics.of))
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
