// Ported 1:1 from Android
// `feature/aihealth/src/test/kotlin/com/alicansekban/salus/feature/aihealth/ui/
// AiSummaryViewModelTest.kt` — the five cases, in the Kotlin order, with the Kotlin inputs and
// expectations.
//
// `advanceUntilIdle()` becomes `waitUntil`, for the reason `WeightEditorViewModelTests` records:
// the ViewModel's work is on the main actor's cooperative queue rather than on a virtual
// scheduler, and no test here waits on wall-clock time.

import Foundation
import SalusAI
import SalusCommon
import SalusPremium
import SalusTesting
import Testing

@testable import FeatureAIHealth

@Suite("AiSummaryViewModel")
@MainActor
struct AiSummaryViewModelTests {
    private let clock = FixedSalusClock(
        now: Date(timeIntervalSince1970: 1_755_000_000),
        timeZone: FixedSalusClock.defaultZone
    )
    private let repository = FakeAiSummaryRepository()
    private let premium = FakePremiumRepository()
    private let paywall = PaywallController()
    private let language = FakeAiLanguageProvider()

    private func viewModel() -> AiSummaryViewModel {
        AiSummaryViewModel(
            repository: repository,
            premiumRepository: premium,
            paywallController: paywall,
            languageProvider: language,
            clock: clock
        )
    }

    /// `AiSummaryViewModelTest.kt` — opening loads the weekly summary.
    @Test("opening loads the weekly summary")
    func openingLoadsTheWeeklySummary() async {
        repository.enqueue(.ready(summary: .fixture, fromCache: false))

        let viewModel = viewModel()
        await waitUntil("the weekly summary to load") {
            viewModel.state.result == .content(text: AiSummary.fixtureText, fromCache: false)
        }

        #expect(viewModel.state.period == .weekly)
        #expect(repository.requestedPeriods == [.weekly])
        #expect(repository.requestedLanguages == [.tr])
    }

    /// `AiSummaryViewModelTest.kt` — a premium wall is a state, and only the button opens the
    /// paywall.
    @Test("a premium wall shows the state and opens the paywall only on the button")
    func premiumWallOpensPaywallOnlyOnTheButton() async {
        repository.enqueue(.needsPremium)

        let viewModel = viewModel()
        await waitUntil("the premium wall to show") {
            viewModel.state.result == .premiumRequired
        }

        #expect(paywall.request == nil)

        viewModel.onEvent(.upgradeClicked)
        #expect(paywall.request?.source == .aiSummary)
    }

    /// `AiSummaryViewModelTest.kt` — becoming entitled while the wall is showing re-requests.
    @Test("becoming entitled while the wall is showing auto-retries")
    func becomingEntitledAutoRetries() async {
        repository.enqueue(.needsPremium)
        repository.enqueue(.ready(summary: .fixture, fromCache: false))

        let viewModel = viewModel()
        await waitUntil("the premium wall to show") {
            viewModel.state.result == .premiumRequired
        }

        premium.set(.premium)
        await waitUntil("the summary to load after entitlement") {
            viewModel.state.result == .content(text: AiSummary.fixtureText, fromCache: false)
        }

        #expect(repository.requestedPeriods == [.weekly, .weekly])
    }

    /// `AiSummaryViewModelTest.kt` — switching the segment issues a new query, loading then result.
    @Test("switching the segment issues a new query")
    func switchingTheSegmentIssuesANewQuery() async {
        repository.enqueue(.ready(summary: .fixture, fromCache: false))
        repository.enqueue(.ready(summary: .monthlyFixture, fromCache: false))

        let viewModel = viewModel()
        await waitUntil("the weekly summary to load") {
            viewModel.state.result == .content(text: AiSummary.fixtureText, fromCache: false)
        }

        viewModel.onEvent(.periodSelected(.monthly))
        #expect(viewModel.state.result == .loading)
        #expect(viewModel.state.period == .monthly)

        await waitUntil("the monthly summary to load") {
            viewModel.state.result == .content(text: AiSummary.monthlyFixtureText, fromCache: false)
        }

        #expect(repository.requestedPeriods == [.weekly, .monthly])
    }

    /// `AiSummaryViewModelTest.kt` — a retryable failure shows the error state, and retry re-calls.
    @Test("a retryable failure shows the error state and retry re-calls")
    func retryableFailureShowsErrorAndRetryReCalls() async {
        repository.enqueue(.failed(reason: .error))
        repository.enqueue(.ready(summary: .fixture, fromCache: false))

        let viewModel = viewModel()
        await waitUntil("the error state to show") {
            viewModel.state.result == .error(reason: .error)
        }

        viewModel.onEvent(.retryClicked)
        await waitUntil("the summary to load after retry") {
            viewModel.state.result == .content(text: AiSummary.fixtureText, fromCache: false)
        }

        #expect(repository.requestedPeriods == [.weekly, .weekly])
    }
}

// MARK: - Fakes

/// A `AiSummaryRepository` that answers queued outcomes in order, and records the requests.
final class FakeAiSummaryRepository: AiSummaryRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var outcomes: [SummaryOutcome] = []
    private var recordedPeriods: [SummaryPeriod] = []
    private var recordedLanguages: [AiLanguage] = []

    /// The periods each `getSummary` was asked for, in order.
    var requestedPeriods: [SummaryPeriod] {
        lock.withLock { recordedPeriods }
    }

    /// The languages each `getSummary` was asked for, in order.
    var requestedLanguages: [AiLanguage] {
        lock.withLock { recordedLanguages }
    }

    var freeSummaryAvailable: AsyncStream<Bool> {
        AsyncStream { $0.finish() }
    }

    func enqueue(_ outcome: SummaryOutcome) {
        lock.withLock {
            outcomes.append(outcome)
        }
    }

    func getSummary(
        period: SummaryPeriod,
        todayEpochDay: Int,
        language: AiLanguage
    ) async -> SummaryOutcome {
        lock.withLock {
            recordedPeriods.append(period)
            recordedLanguages.append(language)
            return outcomes.isEmpty ? .failed(reason: .error) : outcomes.removeFirst()
        }
    }
}

/// A `PremiumRepository` whose status a test sets by hand.
final class FakePremiumRepository: PremiumRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var current: PremiumStatus
    private var continuations: [UUID: AsyncStream<PremiumStatus>.Continuation] = [:]

    init(status: PremiumStatus = .free) {
        current = status
    }

    var status: AsyncStream<PremiumStatus> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            lock.lock()
            continuations[id] = continuation
            let value = current
            lock.unlock()
            continuation.yield(value)
            continuation.onTermination = { [weak self] _ in
                self?.remove(id)
            }
        }
    }

    func set(_ newStatus: PremiumStatus) {
        lock.lock()
        current = newStatus
        let continuations = Array(continuations.values)
        lock.unlock()
        for continuation in continuations {
            continuation.yield(newStatus)
        }
    }

    func refresh() async {}

    private func remove(_ id: UUID) {
        lock.lock()
        continuations[id] = nil
        lock.unlock()
    }
}

/// An `AiLanguageProvider` that always answers Turkish.
struct FakeAiLanguageProvider: AiLanguageProvider {
    func current() -> AiLanguage {
        .tr
    }
}

// MARK: - Fixtures

extension AiSummary {
    static let fixture = AiSummary(
        periodType: .weekly,
        startEpochDay: 20679,
        endEpochDay: 20685,
        language: .tr,
        text: fixtureText,
        createdAtEpochMs: 1_755_000_000_000
    )

    static let monthlyFixture = AiSummary(
        periodType: .monthly,
        startEpochDay: 20656,
        endEpochDay: 20685,
        language: .tr,
        text: monthlyFixtureText,
        createdAtEpochMs: 1_755_000_000_000
    )

    static let fixtureText = "Your blood pressure stayed in range this week."
    static let monthlyFixtureText = "Your blood pressure stayed in range this month."
}
