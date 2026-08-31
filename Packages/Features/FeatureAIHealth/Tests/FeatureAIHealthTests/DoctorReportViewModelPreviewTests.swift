// The preview lifecycle of `DoctorReportViewModel` — Task 7 of iOS-M10.
//
// Android's `DoctorReportViewModelTest.kt` has no preview cases: the preview is an iOS-only
// addition (the PDFKit in-app renderer, divergence `D-M10-a`), so this suite is the port's own.
// The four behaviours are the contract the screen's `.fullScreenCover` is driven by:
//
//   1. a finished report on screen + `previewClicked` → the preview opens on that file's URL;
//   2. `previewDismissed` → the preview closes;
//   3. no report on screen + `previewClicked` → nothing happens (the preview stays hidden);
//   4. a report still generating + `previewClicked` → nothing happens.
//
// The ViewModel never creates a `PDFDocument` — it only carries the URL into the preview state,
// and `PDFView` opens the file itself. There is no file-descriptor lifecycle to test.

import Foundation
import SalusAI
import SalusCommon
import SalusPremium
import SalusTesting
import Testing

@testable import FeatureAIHealth

@Suite("DoctorReportViewModel preview")
@MainActor
struct DoctorReportViewModelPreviewTests {
    private let clock = FixedSalusClock(
        now: Date(timeIntervalSince1970: 1_755_000_000),
        timeZone: FixedSalusClock.defaultZone
    )
    private let repository = PreviewFakeDoctorReportRepository()
    private let premium = PreviewFakePremiumRepository()
    private let paywall = PaywallController()
    private let language = PreviewFakeAiLanguageProvider()

    private func viewModel() -> DoctorReportViewModel {
        DoctorReportViewModel(
            repository: repository,
            premiumRepository: premium,
            paywallController: paywall,
            languageProvider: language,
            clock: clock
        )
    }

    /// A finished report on screen, and the preview opens on that file's URL.
    @Test("a finished report opens the preview on its file URL")
    func finishedReportOpensPreviewOnItsFileURL() async {
        let file = URL(fileURLWithPath: "salus-report.pdf")
        repository.enqueue(.ready(pdfFile: file, narrativeIncluded: true))

        let viewModel = viewModel()
        viewModel.onEvent(.generateClicked)
        await waitUntil("the report to finish") {
            viewModel.state.result == .ready(pdfFile: file, narrativeIncluded: true)
        }

        viewModel.onEvent(.previewClicked)

        #expect(viewModel.state.preview == .ready(url: file))
    }

    /// Dismissing the preview closes it.
    @Test("dismissing the preview closes it")
    func dismissingThePreviewClosesIt() async {
        let file = URL(fileURLWithPath: "salus-report.pdf")
        repository.enqueue(.ready(pdfFile: file, narrativeIncluded: true))

        let viewModel = viewModel()
        viewModel.onEvent(.generateClicked)
        await waitUntil("the report to finish") {
            viewModel.state.result == .ready(pdfFile: file, narrativeIncluded: true)
        }
        viewModel.onEvent(.previewClicked)
        #expect(viewModel.state.preview == .ready(url: file))

        viewModel.onEvent(.previewDismissed)

        #expect(viewModel.state.preview == .hidden)
    }

    /// No report on screen, and the preview tap is a no-op.
    @Test("a preview tap with no report on screen is a no-op")
    func previewTapWithNoReportIsANoOp() {
        let viewModel = viewModel()
        #expect(viewModel.state.result == .idle)

        viewModel.onEvent(.previewClicked)

        #expect(viewModel.state.preview == .hidden)
    }

    /// A report still generating, and the preview tap is a no-op.
    @Test("a preview tap while generating is a no-op")
    func previewTapWhileGeneratingIsANoOp() {
        repository.suspend = true

        let viewModel = viewModel()
        viewModel.onEvent(.generateClicked)
        #expect(viewModel.state.result == .generating)

        viewModel.onEvent(.previewClicked)

        #expect(viewModel.state.preview == .hidden)
    }
}

// MARK: - Fakes

/// A `DoctorReportRepository` that answers queued outcomes in order, or suspends forever when
/// `suspend` is set — the two states the preview lifecycle needs to reach `.ready` and `.generating`.
private final class PreviewFakeDoctorReportRepository: DoctorReportRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var outcomes: [ReportOutcome] = []
    var suspend = false

    func enqueue(_ outcome: ReportOutcome) {
        lock.withLock { outcomes.append(outcome) }
    }

    func generate(
        period: SummaryPeriod,
        todayEpochDay: Int,
        language: AiLanguage
    ) async -> ReportOutcome {
        if lock.withLock({ suspend }) {
            // Never answers, so the ViewModel stays on `.generating`.
            try? await Task.sleep(nanoseconds: 3_600_000_000_000)
        }
        return lock.withLock { outcomes.isEmpty ? .failed(message: "unexpected") : outcomes.removeFirst() }
    }
}

/// A `PremiumRepository` that stays free; the preview lifecycle never reads entitlement.
private final class PreviewFakePremiumRepository: PremiumRepository, @unchecked Sendable {
    var status: AsyncStream<PremiumStatus> {
        AsyncStream { $0.finish() }
    }

    func refresh() async {}
}

/// An `AiLanguageProvider` that always answers Turkish.
private struct PreviewFakeAiLanguageProvider: AiLanguageProvider {
    func current() -> AiLanguage {
        .tr
    }
}
