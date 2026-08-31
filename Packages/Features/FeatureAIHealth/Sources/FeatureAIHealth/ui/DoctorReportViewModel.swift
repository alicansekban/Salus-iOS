// Ported 1:1 from Android
// `feature/aihealth/src/main/kotlin/com/alicansekban/salus/feature/aihealth/ui/
// DoctorReportViewModel.kt`.

import Observation
import SalusAI
import SalusCommon
import SalusPremium

/// Drives the doctor report screen.
///
/// It owns no rule about what a report costs — the entitlement gate, the daily AI quota and the
/// decision to skip the narrative all live in `DoctorReportRepository`, and this class only turns
/// the one outcome it gets back into a screen. That is why hitting the premium wall does **not**
/// open the paywall: the wall is a state the user can look at, and only the button on it asks for
/// the sheet.
///
/// Nothing is generated on open. A report may cost one of the day's AI calls, so it takes a tap.
@MainActor
@Observable
public final class DoctorReportViewModel {
    /// The screen's state, read directly by the view — the twin of Android's `StateFlow`.
    public private(set) var state: DoctorReportUiState

    private let repository: any DoctorReportRepository
    private let paywallController: PaywallController
    private let languageProvider: any AiLanguageProvider
    private let clock: any SalusClock

    /// Held so a period switch cancels the request it replaces and can never overwrite it late.
    ///
    /// A `CancellationBox` rather than a stored `Task`: Swift 6.0 has no isolated `deinit`, so a
    /// `@MainActor` class cannot read its own stored properties from `deinit`. The box is
    /// `@unchecked Sendable` and cancellable from anywhere, which is what lets `deinit` cancel the
    /// generation without touching main-actor state (`SalusCommon`'s `CancellationBox`).
    private let generateBox = CancellationBox()

    /// The entitlement observation, held so `deinit` can cancel it — same reason as `generateBox`.
    private let entitlementBox = CancellationBox()

    public init(
        repository: any DoctorReportRepository,
        premiumRepository: any PremiumRepository,
        paywallController: PaywallController,
        languageProvider: any AiLanguageProvider,
        clock: any SalusClock
    ) {
        self.repository = repository
        self.paywallController = paywallController
        self.languageProvider = languageProvider
        self.clock = clock
        state = DoctorReportUiState()

        observeEntitlement(premiumRepository)
    }

    deinit {
        generateBox.cancel()
        entitlementBox.cancel()
    }

    public func onEvent(_ event: DoctorReportEvent) {
        switch event {
        case let .periodSelected(period):
            selectPeriod(period)
        case .generateClicked:
            generate(state.period)
        case .upgradeClicked:
            paywallController.show(.doctorReport)
        case .previewClicked:
            openPreview()
        case .previewDismissed:
            closePreview()
        }
    }

    /// Switching period abandons the report on screen rather than regenerating it.
    ///
    /// The file that is showing covers the *other* period, so leaving it there next to a changed
    /// selector would offer the user a Share button for a document that is not what the screen
    /// says it is. Regenerating automatically would be worse still — it would spend an AI call for
    /// a tap on a segmented control.
    private func selectPeriod(_ period: SummaryPeriod) {
        if period == state.period {
            return
        }
        generateBox.cancel()
        state = DoctorReportUiState(period: period, result: .idle, preview: .hidden)
    }

    /// Opens the report that is on screen, and only that one.
    ///
    /// The guard is the point: a preview of a file the screen is not currently offering would be a
    /// document from another period, or none at all. The file descriptor lifecycle is Task 7's —
    /// PDFKit manages the open document — so this task only moves the URL into the preview state.
    private func openPreview() {
        guard case let .ready(pdfFile, _) = state.result else { return }
        state.preview = .ready(url: pdfFile)
    }

    private func closePreview() {
        state.preview = .hidden
    }

    /// Re-arms the screen the moment the user becomes entitled while the wall is showing.
    ///
    /// The purchase finishes in the paywall overlay, which leaves this screen underneath still
    /// displaying `DoctorReportResult.premiumRequired`. It returns to `DoctorReportResult.idle`
    /// rather than generating: the user has just paid, and the first thing that happens must not
    /// be an AI call they did not ask for. Every other state is left alone.
    private func observeEntitlement(_ premiumRepository: any PremiumRepository) {
        entitlementBox.replace(with: Task { [weak self] in
            var last: Bool?
            for await status in premiumRepository.status {
                let entitled = status.isEntitled
                // The twin of Kotlin's `map { it.isEntitled }.distinctUntilChanged()`: only a
                // change in the entitlement flips the re-arm, so a re-emission of the same status
                // does not touch a report that is already on screen.
                if entitled != last {
                    last = entitled
                    if entitled, let self, state.result == .premiumRequired {
                        state.result = .idle
                    }
                }
            }
        })
    }

    private func generate(_ period: SummaryPeriod) {
        generateBox.cancel()
        state = DoctorReportUiState(period: period, result: .generating, preview: .hidden)
        generateBox.replace(with: Task { [weak self] in
            guard let self else { return }
            // The clock is the ViewModel's, never the screen's: the day the AI quota is counted
            // against has to be the one the rest of the app calls today.
            let outcome = await repository.generate(
                period: period,
                todayEpochDay: clock.todayEpochDay(),
                language: languageProvider.current()
            )
            guard !Task.isCancelled else { return }
            state = DoctorReportUiState(period: period, result: outcome.toResult(), preview: .hidden)
        })
    }
}

extension ReportOutcome {
    fileprivate func toResult() -> DoctorReportResult {
        switch self {
        case let .ready(pdfFile, narrativeIncluded):
            .ready(pdfFile: pdfFile, narrativeIncluded: narrativeIncluded)
        case .needsPremium:
            .premiumRequired
        case .needsMoreData:
            .insufficientData
        // The message stays in the outcome and dies there: it is platform failure text, kept for
        // the log, and every line this screen shows is ours and localized.
        case .failed:
            .failed
        }
    }
}
