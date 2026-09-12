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
import SalusModel
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
    private let periodReader = SummaryFakeHealthPeriodReader()

    private func viewModel() -> AiSummaryViewModel {
        AiSummaryViewModel(
            repository: repository,
            premiumRepository: premium,
            paywallController: paywall,
            languageProvider: language,
            periodReader: periodReader,
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

    /// `AiSummaryViewModelTest.kt` — the content carries the metrics of the aggregated period.
    @Test("the content carries the metrics of the aggregated period")
    func contentCarriesTheMetrics() async {
        repository.enqueue(.ready(summary: .fixture, fromCache: false))
        periodReader.stats[.weekly] = statsOf(
            systolic: 127.6,
            diastolic: 82.4,
            pulse: 71.5,
            loggedDoses: 12,
            takenDoses: 11
        )

        let viewModel = viewModel()
        await waitUntil("the summary with metrics to load") {
            if case let .content(text, _, metrics) = viewModel.state.result, text == AiSummary.fixtureText {
                return metrics == AiSummaryMetrics(
                    averageBloodPressure: "128/82",
                    recordedDosePercent: 92,
                    averagePulse: 72
                )
            }
            return false
        }
    }

    /// `AiSummaryViewModelTest.kt` — an aggregate with none of the three leaves the metrics off.
    @Test("an aggregate with none of the three leaves the metrics off entirely")
    func aggregateWithNoMetricsIsNil() async {
        repository.enqueue(.ready(summary: .fixture, fromCache: false))
        periodReader.stats[.weekly] = statsOf()

        let viewModel = viewModel()
        await waitUntil("the summary without metrics to load") {
            viewModel.state.result == .content(text: AiSummary.fixtureText, fromCache: false, metrics: nil)
        }
    }

    /// `AiSummaryViewModelTest.kt` — regenerating keeps the period and re-reads its metrics.
    @Test("regenerating keeps the period and re-reads its metrics")
    func regeneratingKeepsThePeriodAndReReadsItsMetrics() async {
        repository.enqueue(.ready(summary: .fixture, fromCache: false))
        repository.enqueue(.ready(summary: .monthlyFixture, fromCache: false))
        repository.enqueue(.ready(summary: .monthlyFixture, fromCache: false))
        periodReader.stats[.monthly] = HealthPeriodStats(
            periodType: .monthly,
            startEpochDay: 20656,
            endEpochDay: 20685,
            distinctRecordDays: 5,
            systolic: nil,
            diastolic: nil,
            pulse: metricStatsOfAverage(68.0),
            glucoseMgDl: nil,
            weightKg: nil,
            loggedDoses: 0,
            takenDoses: 0
        )

        let viewModel = viewModel()
        await waitUntil("the weekly summary to load") {
            if case let .content(text, _, _) = viewModel.state.result {
                return text == AiSummary.fixtureText
            }
            return false
        }

        viewModel.onEvent(.periodSelected(.monthly))
        await waitUntil("the monthly summary to load") {
            if case let .content(text, _, metrics) = viewModel.state.result {
                return text == AiSummary.monthlyFixtureText
                    && metrics == AiSummaryMetrics(averagePulse: 68)
            }
            return false
        }

        viewModel.onEvent(.retryClicked)
        await waitUntil("the monthly summary to load after refresh") {
            if case let .content(text, _, metrics) = viewModel.state.result {
                return text == AiSummary.monthlyFixtureText
                    && metrics == AiSummaryMetrics(averagePulse: 68)
            }
            return false
        }

        #expect(viewModel.state.period == .monthly)
        #expect(repository.requestedPeriods.dropFirst().allSatisfy { $0 == .monthly })
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

/// A `HealthPeriodReader` that answers with whatever snapshot a test put in for the period, and
/// an empty one otherwise — the seam the metrics tiles read through.
///
/// `HealthPeriodReader` mirrors Android's `HealthPeriodReader` interface; the real
/// `HealthStatsAggregator` takes GRDB DAOs, and `SalusDatabase` is deliberately not on this test
/// target's classpath.
final class SummaryFakeHealthPeriodReader: HealthPeriodReader, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [SummaryPeriod: HealthPeriodStats] = [:]

    var stats: [SummaryPeriod: HealthPeriodStats] {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }

    func aggregate(
        period: SummaryPeriod,
        todayEpochDay: Int,
        timeZone: TimeZone
    ) async throws -> HealthPeriodStats {
        lock.withLock { stored[period] ?? statsOfEmpty(period: period, todayEpochDay: todayEpochDay) }
    }

    func periodRows(
        period: SummaryPeriod,
        todayEpochDay: Int,
        timeZone: TimeZone
    ) async throws -> HealthPeriodRows {
        .empty
    }
}

/// A snapshot with only the three figures the screen tiles read (`AiSummaryViewModelTest.kt:149-168`).
private func statsOf(
    systolic: Double? = nil,
    diastolic: Double? = nil,
    pulse: Double? = nil,
    loggedDoses: Int = 0,
    takenDoses: Int = 0
) -> HealthPeriodStats {
    HealthPeriodStats(
        periodType: .weekly,
        startEpochDay: 20679,
        endEpochDay: 20685,
        distinctRecordDays: 5,
        systolic: systolic.map(metricStatsOfAverage),
        diastolic: diastolic.map(metricStatsOfAverage),
        pulse: pulse.map(metricStatsOfAverage),
        glucoseMgDl: nil,
        weightKg: nil,
        loggedDoses: loggedDoses,
        takenDoses: takenDoses
    )
}

private func metricStatsOfAverage(_ average: Double) -> MetricStats {
    MetricStats(count: 4, average: average, min: average, max: average, trend: .stable)
}

private func statsOfEmpty(period: SummaryPeriod, todayEpochDay: Int) -> HealthPeriodStats {
    HealthPeriodStats(
        periodType: period,
        startEpochDay: todayEpochDay,
        endEpochDay: todayEpochDay,
        distinctRecordDays: 0,
        systolic: nil,
        diastolic: nil,
        pulse: nil,
        glucoseMgDl: nil,
        weightKg: nil,
        loggedDoses: 0,
        takenDoses: 0
    )
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
